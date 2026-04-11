import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/services/api_config.dart';
import '../../core/services/user_sesion.dart';
import '../../core/forum_provider.dart';
import '../../core/providers.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailPage({super.key, required this.post});

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  late ApiClient _apiClient;
  bool _isLoadingComments = true;
  List<dynamic> _comentarios = [];

  final TextEditingController _commentCtrl = TextEditingController();
  bool _isPostingComment = false;
  int? _replyToId;
  String? _replyToName;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(getBaseUrl());
    if (UserSession.token != null) {
      _apiClient.setToken(UserSession.token!);
    }
    _cargarComentarios();
  }

  Future<void> _cargarComentarios() async {
    try {
      final id = widget.post['id'];
      final results = await _apiClient.getComentariosPublicacion(id);
      if (mounted) {
        setState(() {
          _comentarios = results;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _publicarComentario() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    if (UserSession.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Inicia sesión para comentar")));
      return;
    }

    setState(() => _isPostingComment = true);

    try {
      await _apiClient.createComentario(
          widget.post['id'], _commentCtrl.text.trim(),
          idPadre: _replyToId);
      _commentCtrl.clear();
      setState(() {
        _replyToId = null;
        _replyToName = null;
      });
      await _cargarComentarios(); // Recargar lista local
      ref.invalidate(forumProvider); // Forzar actualización del Feed global
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error al publicar comentario")));
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  Future<void> _borrarPublicacion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar publicación"),
        content: const Text(
            "¿Estás seguro de que quieres eliminar esta publicación?"),
        actions: [
          TextButton(
              child: const Text("Cancelar"),
              onPressed: () => Navigator.pop(ctx, false)),
          TextButton(
              child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(forumProvider.notifier).deletePost(widget.post['id']);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error al eliminar: $e")));
      }
    }
  }

  Future<void> _toggleLikeComentario(int commentId) async {
    if (UserSession.token == null) return;

    // Actualización optimista recursiva
    bool updateRecursive(List<dynamic> list) {
      for (int i = 0; i < list.length; i++) {
        var c = list[i];
        if (c['id_comentario'] == commentId) {
          final bool currentlyLiked = c['is_liked'] ?? false;
          final int currentLikes = c['likes'] ?? 0;
          
          list[i] = {
            ...c,
            'is_liked': !currentlyLiked,
            'likes': currentlyLiked ? currentLikes - 1 : currentLikes + 1,
          };
          return true;
        }
        if (c['hijos'] != null && updateRecursive(c['hijos'])) {
          return true;
        }
      }
      return false;
    }

    final originalComentarios = List<dynamic>.from(_comentarios);
    setState(() {
      updateRecursive(_comentarios);
    });

    try {
      final c = _findCommentById(_comentarios, commentId);
      if (c == null) return;
      
      if (c['is_liked'] == true) {
        await _apiClient.likeComentario(commentId);
      } else {
        await _apiClient.unlikeComentario(commentId);
      }
    } catch (e) {
      // Revertir en caso de error
      setState(() {
        _comentarios = originalComentarios;
      });
    }
  }

  dynamic _findCommentById(List<dynamic> list, int id) {
    for (var c in list) {
      if (c['id_comentario'] == id) return c;
      if (c['hijos'] != null) {
        final nested = _findCommentById(c['hijos'], id);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  int _getTotalCommentsCount() {
    int count = 0;
    void countRecursive(List<dynamic> list) {
      for (var c in list) {
        if (c['borrado'] != true) {
          count++;
        }
        final hijos = c['hijos'] as List?;
        if (hijos != null && hijos.isNotEmpty) {
          countRecursive(hijos);
        }
      }
    }
    countRecursive(_comentarios);
    return count;
  }

  Future<void> _borrarComentario(int commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar comentario"),
        content: const Text("¿Estás seguro de que quieres eliminar este comentario?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiClient.deleteComentario(commentId);
      await _cargarComentarios(); // Recargamos localmente
      ref.invalidate(forumProvider); // Forzar actualización del Feed
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Comentario eliminado")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al eliminar comentario")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos el estado global del foro para obtener la versión más reciente de este post
    final forumState = ref.watch(forumProvider);

    // Buscamos el post actual en la lista del provider para tener reactividad (likes, etc.)
    final Map<String, dynamic>? currentPost = forumState.value?.firstWhere(
        (p) => p['id'] == widget.post['id'],
        orElse: () => widget.post // Fallback al original si no está en la lista (raro)
        );

    if (currentPost == null) {
      return Scaffold(
        body: Center(child: Text("Publicación no encontrada")),
      );
    }

    final int likesCount = currentPost['likes'] ?? 0;
    final bool isLiked = currentPost['isLiked'] ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text("Hilo",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          if (currentPost['isMine'] == true)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.black),
              onPressed: _borrarPublicacion,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: currentPost['avatar'] != null
                              ? NetworkImage(currentPost['avatar'])
                              : null,
                          child: currentPost['avatar'] == null
                              ? const Icon(Icons.person, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentPost['user'] ?? "Usuario",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(currentPost['fullDate'] ?? currentPost['time'] ?? "",
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 13)),
                          ],
                        )
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (currentPost['titulo'] != null &&
                            currentPost['titulo'] != '')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(currentPost['titulo'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 20)),
                          ),
                        Text(currentPost['text'] ?? "",
                            style: const TextStyle(
                                fontSize: 16, height: 1.5, color: Colors.black87)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (currentPost['image'] != null)
                    Container(
                      width: double.infinity,
                      color: Colors.grey.shade100,
                      child: Image.network(
                        currentPost['image'],
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const SizedBox.shrink(),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : Colors.grey),
                          onPressed: () => ref
                              .read(forumProvider.notifier)
                              .toggleLike(currentPost['id']),
                        ),
                        Text("$likesCount",
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 20),
                        const Icon(Icons.chat_bubble_outline, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text("${_getTotalCommentsCount()}",
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text("Comentarios (${_getTotalCommentsCount()})",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  if (_isLoadingComments)
                    const Center(child: CircularProgressIndicator())
                  else if (_comentarios.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(
                          child: Text("Sé el primero en comentar.",
                              style: TextStyle(color: Colors.grey))),
                    )
                  else
                    Column(
                      children: _comentarios
                          .map((c) => _buildComentario(c))
                          .toList(),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_replyToId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Respondiendo a $_replyToName",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() {
                      _replyToId = null;
                      _replyToName = null;
                    }),
                  )
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: InputDecoration(
                        hintText: "Escribe un comentario...",
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey.shade100),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isPostingComment
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.blue),
                  onPressed: _isPostingComment ? null : _publicarComentario,
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildComentario(dynamic c, {int level = 0, String? parentName}) {
    final bool esBorrado = c['borrado'] ?? false;
    final String texto = esBorrado ? "Este comentario ha sido eliminado" : (c['texto'] ?? "");
    final autorObj = esBorrado ? null : (c['autor'] ?? c['usuario']);
    
    final String autor = autorObj != null
        ? "${autorObj['nombre'] ?? 'Usuario'} ${autorObj['apellidos'] ?? ''}"
            .trim()
        : (esBorrado ? "Usuario eliminado" : "Anónimo");
        
    final int? authorId = autorObj?['id_usuario'];
    final currentUserId = ref.read(userIdProvider);
    final String? fechaIso = c['fecha_comentario'];
    final String fecha = _formatearFechaRelativa(fechaIso);

    final List<dynamic> hijos = c['hijos'] ?? [];

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20.0 + (level * 20.0), 8, 20, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey.shade100,
                backgroundImage: autorObj != null && autorObj['path_foto_perfil'] != null
                    ? NetworkImage(autorObj['path_foto_perfil'])
                    : null,
                child: autorObj == null || autorObj['path_foto_perfil'] == null
                    ? Icon(esBorrado ? Icons.remove_circle_outline : Icons.person, size: 14, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (parentName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Text(
                          "respondiendo a @${parentName.replaceAll(" ", "").toLowerCase()}",
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade300,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    Row(
                      children: [
                        Text(autor,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 13,
                                color: esBorrado ? Colors.grey : Colors.black)),
                        const SizedBox(width: 8),
                        Text(fecha,
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(texto, 
                      style: TextStyle(
                        fontSize: 14, 
                        color: esBorrado ? Colors.grey.shade600 : Colors.black87,
                        fontStyle: esBorrado ? FontStyle.italic : FontStyle.normal
                      )),
                    const SizedBox(height: 4),
                    if (!esBorrado)
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _replyToId = c['id_comentario'];
                                _replyToName = autor;
                              });
                            },
                            child: Text("Responder",
                                style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                          if (authorId != null && authorId == currentUserId) ...[
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => _borrarComentario(c['id_comentario']),
                              child: Text("Eliminar",
                                  style: TextStyle(
                                      color: Colors.red.shade400,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ]
                        ],
                      ),
                  ],
                ),
              ),
              if (!esBorrado)
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleLikeComentario(c['id_comentario']),
                      child: Icon(
                        (c['is_liked'] ?? false) ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: (c['is_liked'] ?? false) ? Colors.red : Colors.grey,
                      ),
                    ),
                    Text("${c['likes'] ?? 0}",
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ),
            ],
          ),
        ),
        if (hijos.isNotEmpty)
          ...hijos
              .map((hijo) => _buildComentario(hijo, level: level + 1, parentName: autor))
              .toList(),
      ],
    );
  }

  String _formatearFechaRelativa(String? fechaIso) {
    if (fechaIso == null) return "ahora";
    try {
      final fecha = DateTime.parse(fechaIso);
      final ahora = DateTime.now();
      final diferencia = ahora.difference(fecha);

      if (diferencia.inSeconds < 60) return "ahora";
      if (diferencia.inMinutes < 60) return "hace ${diferencia.inMinutes}m";
      if (diferencia.inHours < 24) return "hace ${diferencia.inHours}h";
      if (diferencia.inDays < 7) return "hace ${diferencia.inDays}d";
      if (diferencia.inDays < 30)
        return "hace ${(diferencia.inDays / 7).floor()} sem";
      return "${fecha.day}/${fecha.month}/${fecha.year}";
    } catch (e) {
      return "";
    }
  }
}
