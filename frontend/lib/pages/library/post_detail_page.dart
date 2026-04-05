import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/services/api_config.dart';
import '../../core/services/user_sesion.dart';

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late ApiClient _apiClient;
  bool _isLoadingComments = true;
  List<dynamic> _comentarios = [];
  
  // State local para likes (optimistic UI)
  late int _likesCount;
  bool _isLiked = false;
  bool _initialLikedState = false; // Para detectar cambios al volver atrás

  final TextEditingController _commentCtrl = TextEditingController();
  bool _isPostingComment = false;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(getBaseUrl());
    if (UserSession.token != null) {
      _apiClient.setToken(UserSession.token!);
    }
    _likesCount = widget.post['likes'] ?? 0;
    _isLiked = widget.post['isLiked'] ?? false;
    _initialLikedState = _isLiked;
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

  Future<void> _darLike() async {
    setState(() {
      if (_isLiked) {
        _likesCount--;
        _isLiked = false;
      } else {
        _likesCount++;
        _isLiked = true;
      }
    });

    try {
      if (_isLiked) {
        await _apiClient.likePublicacion(widget.post['id']);
      } else {
        await _apiClient.unlikePublicacion(widget.post['id']);
      }
    } catch (e) {
      // Revertir si falla
       if(mounted) {
         setState(() {
           if (_isLiked) {
             _likesCount--;
             _isLiked = false;
           } else {
             _likesCount++;
             _isLiked = true;
           }
        });
       }
    }
  }

  Future<void> _publicarComentario() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    if (UserSession.token == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Inicia sesión para comentar")));
        return;
    }

    setState(() => _isPostingComment = true);
    
    try {
      await _apiClient.createComentario(widget.post['id'], _commentCtrl.text.trim());
      _commentCtrl.clear();
      await _cargarComentarios(); // Recargar lista
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al publicar comentario")));
    } finally {
      if(mounted) setState(() => _isPostingComment = false);
    }
  }

  Future<void> _borrarPublicacion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar publicación"),
        content: const Text("¿Estás seguro de que quieres eliminar esta publicación?"),
        actions: [
          TextButton(child: const Text("Cancelar"), onPressed: () => Navigator.pop(ctx, false)),
          TextButton(child: const Text("Eliminar", style: TextStyle(color: Colors.red)), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );

    if (confirm != true) return;

    // Mostrar indicador de carga o bloquear UI
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Eliminando...")));
    }

    try {
      await _apiClient.deletePublicacion(widget.post['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Publicación eliminada")));
        Navigator.pop(context, true); // Retornar true para indicar que se eliminó
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al eliminar: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(
          color: Colors.black,
          onPressed: () {
            // Retornar true si ha cambiado el estado de like para refrescar el feed
            Navigator.pop(context, _isLiked != _initialLikedState);
          },
        ),
        title: const Text("Hilo", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          if (widget.post['isMine'] == true)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.black),
              onPressed: _borrarPublicacion,
            ),
        ],
      ),
      body: Column( // Cambiado a Column para dejar campo de texto abajo
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. CABECERA DEL AUTOR
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: widget.post['avatar'] != null
                              ? NetworkImage(widget.post['avatar'])
                              : null,
                          child: widget.post['avatar'] == null
                              ? const Icon(Icons.person, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.post['user'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(widget.post['time'], style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          ],
                        )
                      ],
                    ),
                  ),

                  // 2. CONTENIDO DEL POST
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.post['titulo'] != '')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(widget.post['titulo'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                          ),
                        Text(widget.post['text'], style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. IMAGEN (Si existe)
                  if (widget.post['image'] != null)
                    Container(
                      width: double.infinity,
                      color: Colors.grey.shade100,
                      child: Image.network(
                        widget.post['image'],
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const SizedBox.shrink(),
                      ),
                    ),
                  
                  // 4. BARRA DE INTERACCION
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // BOTÓN DE LIKE FUNCIONAL
                        IconButton(
                          icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : Colors.grey),
                          onPressed: _darLike,
                        ),
                        Text("$_likesCount", style: const TextStyle(fontWeight: FontWeight.bold)),
                        
                        const SizedBox(width: 20),
                        
                        const Icon(Icons.chat_bubble_outline, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text("${_comentarios.length}", style: const TextStyle(fontWeight: FontWeight.bold)), // Usamos el count real de los cargados o del feed
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // 5. SECCIÓN DE COMENTARIOS
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: const Text("Comentarios", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),

                  if (_isLoadingComments)
                    const Center(child: CircularProgressIndicator())
                  else if (_comentarios.isEmpty)
                     const Padding(
                       padding: EdgeInsets.all(20.0),
                       child: Center(child: Text("Sé el primero en comentar.", style: TextStyle(color: Colors.grey))),
                     )
                  else
                    ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                      itemCount: _comentarios.length,
                      separatorBuilder: (c,i) => const Divider(),
                      itemBuilder: (ctx, index) {
                        final c = _comentarios[index];
                        final String texto = c['texto'] ?? "";
                        final autor = c['usuario'] != null ? (c['usuario']['nombre'] ?? "Usuario") : c['autor']?['nombre'] ?? "Anónimo";

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16, 
                                backgroundColor: Colors.grey.shade100,
                                child: Text(autor.isNotEmpty ? autor[0].toUpperCase() : "?", style: const TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(autor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text(texto, style: const TextStyle(fontSize: 14)),
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
          
          // INPUT PARA COMENTAR (FIJO ABAJO)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), // Extra padding bottom for safe area
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.shade100
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isPostingComment 
                     ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
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
