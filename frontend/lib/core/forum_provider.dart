import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/user_sesion.dart';
import '../core/providers.dart';

class ForumNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    // Al observar apiProvider, este notifier se reconstruirá automáticamente
    // cuando el token cambie (ej: Login/Logout)
    ref.watch(apiProvider);
    return _fetchPosts();
  }

  Future<List<Map<String, dynamic>>> _fetchPosts() async {
    final apiClient = ref.read(apiProvider);
    final rawList = await apiClient.getPublicaciones();
    return _mapearPublicaciones(rawList);
  }

  List<Map<String, dynamic>> _mapearPublicaciones(List<dynamic> rawList) {
    return rawList
        .map((item) {
          String? imagenUrl;
          if (item['links_fotos'] != null &&
              (item['links_fotos'] as List).isNotEmpty) {
            imagenUrl = item['links_fotos'][0];
          }

          String nombreUsuario = "Anónimo";
          int? authorId;

          if (item['autor'] != null) {
            final autor = item['autor'];
            nombreUsuario =
                "${autor['nombre'] ?? 'Usuario'} ${autor['apellidos'] ?? ''}"
                    .trim();
            authorId = autor['id_usuario'];
          } else if (item['id_usuario'] != null) {
            nombreUsuario = "Usuario #${item['id_usuario']}";
            authorId = item['id_usuario'];
          }

          final rawDate = item['fecha_publicacion'] ?? item['fecha_creacion'];

          return {
            'id': item['id_publicacion'],
            'titulo': item['titulo'] ?? '',
            'text': item['texto'] ?? '',
            'user': nombreUsuario,
            'time': _formatearFechaRelativa(rawDate),
            'fullDate': _formatearFechaDetallada(rawDate),
            'image': imagenUrl,
            'likes': item['likes'] ?? 0,
            'comments': (item['comentarios'] as List?)?.length ?? 0,
            'isMine': authorId != null && authorId == UserSession.userId,
            'isLiked': item['is_liked'] ?? false,
            'avatar': item['autor'] != null ? (item['autor']['path_foto_perfil'] ?? item['autor']['foto_perfil'] ?? item['autor']['link_foto']) : null,
          };
        })
        .toList();
  }

  String _formatearFechaRelativa(String? fechaIso) {
    if (fechaIso == null) return "Reciente";
    try {
      final fecha = DateTime.parse(fechaIso);
      final ahora = DateTime.now();
      final diferencia = ahora.difference(fecha);

      if (diferencia.inSeconds < 60) return "ahora";
      if (diferencia.inMinutes < 60) return "hace ${diferencia.inMinutes}m";
      if (diferencia.inHours < 24) return "hace ${diferencia.inHours}h";
      if (diferencia.inDays < 7) return "hace ${diferencia.inDays}d";
      if (diferencia.inDays < 30) return "hace ${(diferencia.inDays / 7).floor()} sem";
      if (diferencia.inDays < 365) return "hace ${(diferencia.inDays / 30).floor()} mes(es)";
      return "hace ${(diferencia.inDays / 365).floor()} año(s)";
    } catch (e) {
      return "Reciente";
    }
  }

  String _formatearFechaDetallada(String? fechaIso) {
    if (fechaIso == null) return "Reciente";
    try {
      final fecha = DateTime.parse(fechaIso);
      final dia = fecha.day.toString().padLeft(2, '0');
      final mes = fecha.month.toString().padLeft(2, '0');
      final hora = fecha.hour.toString().padLeft(2, '0');
      final min = fecha.minute.toString().padLeft(2, '0');
      return "$dia/$mes/${fecha.year} - $hora:$min";
    } catch (e) {
      return "Reciente";
    }
  }

  Future<void> toggleLike(int postId) async {
    final posts = state.valueOrNull;
    if (posts == null) return;

    // Actualización optimista
    final index = posts.indexWhere((p) => p['id'] == postId);
    if (index == -1) return;

    final post = posts[index];
    final bool currentlyLiked = post['isLiked'] ?? false;
    final int currentLikes = post['likes'] ?? 0;

    final updatedPost = Map<String, dynamic>.from(post);
    updatedPost['isLiked'] = !currentlyLiked;
    updatedPost['likes'] = currentlyLiked ? currentLikes - 1 : currentLikes + 1;

    final newList = List<Map<String, dynamic>>.from(posts);
    newList[index] = updatedPost;
    state = AsyncData(newList);

    try {
      final apiClient = ref.read(apiProvider);
      if (!currentlyLiked) {
        await apiClient.likePublicacion(postId);
      } else {
        await apiClient.unlikePublicacion(postId);
      }
    } catch (e) {
      // Revertir en caso de error
      state = AsyncData(posts);
      rethrow;
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPosts());
  }

  Future<void> deletePost(int postId) async {
    final posts = state.valueOrNull;
    if (posts == null) return;

    try {
      final apiClient = ref.read(apiProvider);
      await apiClient.deletePublicacion(postId);
      
      state = AsyncData(posts.where((p) => p['id'] != postId).toList());
    } catch (e) {
      rethrow;
    }
  }
}

final forumProvider =
    AsyncNotifierProvider<ForumNotifier, List<Map<String, dynamic>>>(
        ForumNotifier.new);

final myPostsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final posts = ref.watch(forumProvider).valueOrNull ?? [];
  return posts.where((p) => p['isMine'] == true).toList();
});

final popularPostsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final posts = ref.watch(forumProvider).valueOrNull ?? [];
  final sorted = List<Map<String, dynamic>>.from(posts);
  sorted.sort((a, b) {
    final likesA = (a['likes'] as num?)?.toInt() ?? 0;
    final likesB = (b['likes'] as num?)?.toInt() ?? 0;
    final compareLikes = likesB.compareTo(likesA);
    if (compareLikes != 0) return compareLikes;
    final commentsA = (a['comments'] as num?)?.toInt() ?? 0;
    final commentsB = (b['comments'] as num?)?.toInt() ?? 0;
    return commentsB.compareTo(commentsA);
  });
  return sorted;
});
