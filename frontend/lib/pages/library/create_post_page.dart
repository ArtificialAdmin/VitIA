import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'custom_camera_page.dart'; // Import custom camera
import '../../core/api_client.dart';
import '../../core/services/api_config.dart';
import '../../core/services/user_sesion.dart';


class CreatePostPage extends StatefulWidget {
  final VoidCallback? onPostCreated;
  final VoidCallback? onCancel;

  const CreatePostPage({super.key, this.onPostCreated, this.onCancel});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textController = TextEditingController();

  late ApiClient _apiClient;
  bool _isPublishing = false;
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  


  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(getBaseUrl());
    if (UserSession.token != null) {
      _apiClient.setToken(UserSession.token!);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      XFile? image;

      if (source == ImageSource.camera) {
        // Use custom camera
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CustomCameraPage()),
        );
        if (result is XFile) {
          image = result;
        }
      } else {
        // Use system gallery
        image = await _picker.pickImage(source: source);
      }

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _handlePublish() async {
    if (_titleController.text.trim().isEmpty ||
        _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, escribe un título y un mensaje.')),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      // Enviamos el texto y la imagen (si existe)
      await _apiClient.createPublicacion(
          _titleController.text, _textController.text,
          imageFile: _selectedImage);

      if (mounted) {
        if (widget.onPostCreated != null) {
          widget.onPostCreated!();
        } else {
          Navigator.pop(context, true); // Retorna true para refrescar la lista
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al publicar: $e')),
        );
        setState(() => _isPublishing = false);
      }
    }
  }

  void _handleCancel() {
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // BARRA SUPERIOR PERSONALIZADA
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _handleCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                      textStyle: const TextStyle(fontSize: 16),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: _isPublishing ? null : _handlePublish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    child: _isPublishing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Publicar',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ÁREA DE USUARIO Y TEXTO
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.grey.shade300,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              TextField(
                                controller: _titleController,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  hintText: 'Título de tu publicación...',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _textController,
                                maxLines: null,
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black87),
                                decoration: const InputDecoration(
                                  hintText: '¿Qué te gustaría compartir hoy?',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // PREVISUALIZACIÓN DE IMAGEN / PICKER
                    if (_imageBytes != null)
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: EdgeInsets.zero,
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  InteractiveViewer(
                                    minScale: 0.5,
                                    maxScale: 4.0,
                                    child: Image.memory(
                                      _imageBytes!,
                                      fit: BoxFit.contain,
                                      height: double.infinity,
                                      width: double.infinity,
                                    ),
                                  ),
                                  SafeArea(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: IconButton(
                                        icon: const Icon(Icons.close,
                                            color: Colors.white, size: 30),
                                        onPressed: () => Navigator.pop(ctx),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          height: 300,
                          margin: const EdgeInsets.only(top: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.memory(
                                    _imageBytes!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Text(
                                            'Error visualizando imagen: $error',
                                            style: const TextStyle(
                                                color: Colors.red)),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _selectedImage = null;
                                    _imageBytes = null;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.close,
                                        size: 20, color: Colors.white),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () => _pickImage(ImageSource.gallery),
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.grey.shade300,
                                style: BorderStyle.solid),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text("Añadir imagen",
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // BARRA DE ACCIONES INFERIOR (Iconos)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined, size: 28)),
                  IconButton(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_outlined, size: 28)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.alternate_email,
                        size: 20, color: Colors.black54),
                    label: const Text("Etiquetar",
                        style: TextStyle(color: Colors.black54)),
                  ),

                ],
              ),
            ),

            // BOTÓN PUBLICAR GRANDE ELIMINADO
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
