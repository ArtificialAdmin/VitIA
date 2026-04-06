import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/services/api_config.dart';
import '../../core/services/user_sesion.dart';
import '../../core/forum_provider.dart';

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
          widget.post['id'], _commentCtrl.text.trim());
      _commentCtrl.clear();
      await _cargarComentarios(); // Recargar lista
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
                        Text("${_comentarios.length}",
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: const Text("Comentarios",
                        style: TextStyle(
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
                    ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                      itemCount: _comentarios.length,
                      separatorBuilder: (c, i) => const Divider(),
                      itemBuilder: (ctx, index) {
                        final c = _comentarios[index];
                        final String texto = c['texto'] ?? "";
                        final autor = c['usuario'] != null
                            ? (c['usuario']['nombre'] ?? "Usuario")
                            : c['autor']?['nombre'] ?? "Anónimo";

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey.shade100,
                                child: Text(
                                    autor.isNotEmpty ? autor[0].toUpperCase() : "?",
                                    style: const TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(autor,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text(texto,
                                        style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                ],
              ),
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
}
