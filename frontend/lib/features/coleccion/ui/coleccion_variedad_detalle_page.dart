import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'coleccion_detalle_page.dart';
import 'package:vinas_mobile/core/api_client.dart';
import 'package:vinas_mobile/core/api_config.dart';
import 'package:vinas_mobile/features/auth/services/auth_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/providers.dart';

class ColeccionVariedadDetallePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> varietyInfo;
  final List<Map<String, dynamic>> captures;
  final VoidCallback? onBack; // Callback para volver atrás
  final bool isFavoritoInicial; 

  const ColeccionVariedadDetallePage({
    super.key,
    required this.varietyInfo,
    required this.captures,
    this.onBack,
    this.isFavoritoInicial = false,
  });

  @override
  ConsumerState<ColeccionVariedadDetallePage> createState() => _ColeccionVariedadDetallePageState();
}

class _ColeccionVariedadDetallePageState extends ConsumerState<ColeccionVariedadDetallePage> {
  // NAV: Selección interna
  Map<String, dynamic>? _selectedCapture;

  // VIEW MODE: true = Individual (Horizontal), false = Multiple (Vertical)
  bool _isHorizontalView = true;

  // STATE: Local captures list to allow refreshing
  late List<Map<String, dynamic>> _captures;
  bool _isLoading = false;

  // Custom Cover
  String? _customCoverPath;

  late bool _isFavorito; // Local state

  @override
  void initState() {
    super.initState();
    _isFavorito = widget.isFavoritoInicial;
    _captures = List.from(widget.captures);
    _loadCustomCover(); // Cargar portada guardada
  }

  Future<void> _loadCustomCover() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = AuthSessionService.userId ?? 0; // Fallback safe ID
    final key = "cover_$userId" + "_" + widget.varietyInfo['nombre'];
    setState(() {
      _customCoverPath = prefs.getString(key);
    });
  }

  Future<void> _setAsCover(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = AuthSessionService.userId ?? 0;
    final key = "cover_$userId" + "_" + widget.varietyInfo['nombre'];
    await prefs.setString(key, path);
    setState(() {
      _customCoverPath = path;
    });
  }

  Future<void> _toggleFavorito() async {
    setState(() {
      _isFavorito = !_isFavorito;
    });

    try {
      final idData = widget.varietyInfo['variedad_original'];
      if (idData != null && idData['id_variedad'] != null) {
        final id = idData['id_variedad'];
        await ref.read(apiProvider).toggleFavorite(id);
      } else {
        debugPrint("No se encontró id_variedad para dar favorito");
      }
    } catch (e) {
      setState(() {
        _isFavorito = !_isFavorito;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar favoritos')),
      );
    }
  }

  Future<void> _reloadCaptures() async {
    setState(() => _isLoading = true);
    try {
      final allItems = await ref.read(apiProvider).getUserCollection();
      final varietyName = widget.varietyInfo['nombre'];

      final updatedList = allItems
          .where((item) {
            final vData = item['variedad'] ?? {};
            return vData['nombre'] == varietyName;
          })
          .map((item) {
            final vData = item['variedad'] ?? {};
            return {
              'id': item['id_coleccion'],
              'nombre': vData['nombre'] ?? 'Sin nombre',
              'descripcion': item['notas'] ?? vData['descripcion'],
              'region': 'Mi Bodega',
              'tipo': vData['color'] ?? 'Personal',
              'imagen': item['path_foto_usuario'],
              'morfologia': vData['morfologia'],
              'fecha_captura': item['fecha_captura'],
              'latitud': item['latitud'],
              'longitud': item['longitud'],
              'es_local': false,
              'variedad_original': vData,
            };
          })
          .toList()
          .cast<Map<String, dynamic>>();

      if (mounted) {
        setState(() {
          _captures = updatedList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error reloading captures: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCapture != null) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          setState(() => _selectedCapture = null);
        },
        child: ColeccionDetallePage(
          coleccionItem: _selectedCapture!,
          onClose: (refresh) {
            setState(() => _selectedCapture = null);
            if (refresh) {
              _reloadCaptures();
              if (widget.onBack != null) widget.onBack!();
            }
          },
        ),
      );
    }

    final String mainImage = _customCoverPath ??
        widget.varietyInfo['imagen'] ??
        (_captures.isNotEmpty ? _captures[0]['imagen'] : null) ??
        'assets/images/placeholder.png';

    final bool isBlanca = (widget.varietyInfo['tipo'] == 'Blanca');
    final colorTema = isBlanca ? Colors.lime.shade700 : Colors.purple.shade900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: _buildMainImage(mainImage),
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26, blurRadius: 20, spreadRadius: 5)
                  ],
                ),
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 5,
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.varietyInfo['nombre'] ?? 'Sin Nombre',
                                    style: GoogleFonts.lora(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _toggleFavorito,
                                  icon: Icon(
                                    _isFavorito ? Icons.favorite : Icons.favorite_border,
                                    color: _isFavorito ? Colors.redAccent : Colors.grey,
                                    size: 30,
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: colorTema.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: colorTema)),
                              child: Text(
                                (widget.varietyInfo['tipo'] ?? 'Personal').toUpperCase(),
                                style: GoogleFonts.lora(
                                    color: colorTema,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Mis identificaciones (${_captures.length})",
                              style: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            if (_isLoading)
                              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            else
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.view_carousel, color: _isHorizontalView ? Colors.black : Colors.grey),
                                    onPressed: () => setState(() => _isHorizontalView = true),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.grid_view, color: !_isHorizontalView ? Colors.black : Colors.grey),
                                    onPressed: () => setState(() => _isHorizontalView = false),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    _isHorizontalView
                        ? SliverToBoxAdapter(
                            child: SizedBox(
                              height: 450,
                              child: PageView.builder(
                                controller: PageController(viewportFraction: 0.85),
                                itemCount: _captures.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: _buildCardItem(_captures[index], isHorizontal: true),
                                  );
                                },
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.8,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildCardItem(_captures[index], isHorizontal: false),
                                childCount: _captures.length,
                              ),
                            ),
                          ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(Map<String, dynamic> item, {required bool isHorizontal}) {
    String fecha = "Fecha desc.";
    if (item['fecha_captura'] != null) {
      try {
        final d = DateTime.parse(item['fecha_captura'].toString());
        fecha = "${d.day}/${d.month}/${d.year}";
      } catch (_) {}
    }
    final bool isBlanca = (widget.varietyInfo['tipo'] == 'Blanca');
    final colorTema = isBlanca ? Colors.lime.shade700 : Colors.purple.shade900;

    return GestureDetector(
      onTap: () => setState(() => _selectedCapture = item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: isHorizontal ? const BorderRadius.vertical(top: Radius.circular(15)) : BorderRadius.circular(15),
                    child: _buildImage(item['imagen'] ?? item['path_foto_usuario']),
                  ),
                  Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        children: [
                          if (item['es_premium'] == true)
                            Container(
                              padding: const EdgeInsets.all(4),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                              child: const Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
                            ),
                          GestureDetector(
                            onTap: () => _setAsCover(item['imagen'] ?? item['path_foto_usuario']),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                              child: Icon(_customCoverPath == (item['imagen'] ?? item['path_foto_usuario']) ? Icons.star : Icons.star_border, size: 20, color: Colors.orange),
                            ),
                          ),
                        ],
                      ))
                ],
              ),
            ),
            if (isHorizontal)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: colorTema)),
                      child: Text((widget.varietyInfo['tipo'] ?? 'PERSONAL').toUpperCase(), style: TextStyle(color: colorTema, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                    Text(fecha, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String? path) {
    if (path == null) return Container(color: Colors.grey.shade300, child: const Icon(Icons.image_not_supported));
    ImageProvider img;
    if (path.startsWith('http')) img = NetworkImage(path);
    else if (path.startsWith('assets/')) img = AssetImage(path);
    else img = FileImage(File(path));
    return Image(image: img, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey.shade200));
  }

  Widget _buildMainImage(String path) {
    ImageProvider img;
    if (path.startsWith('http')) img = NetworkImage(path);
    else if (path.startsWith('assets/')) img = AssetImage(path);
    else img = FileImage(File(path));
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(image: img, fit: BoxFit.cover),
        BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: Container(color: Colors.black.withOpacity(0.3))),
        Align(alignment: Alignment.topCenter, child: Image(image: img, fit: BoxFit.contain, alignment: Alignment.topCenter)),
      ],
    );
  }
}
