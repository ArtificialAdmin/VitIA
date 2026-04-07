import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/api_client.dart';
import '../pages/map/mapa_colecciones_page.dart';

class HomeMapPreview extends StatefulWidget {
  final ApiClient apiClient;
  const HomeMapPreview({super.key, required this.apiClient});

  @override
  State<HomeMapPreview> createState() => _HomeMapPreviewState();
}

class _HomeMapPreviewState extends State<HomeMapPreview> {
  bool _isLoading = true;
  List<dynamic> _colecciones = [];
  String _modo = 'publico'; // 'publico' o 'privado'
  final MapController _mapController = MapController();
  LatLng _mapCenter = const LatLng(40.4168, -3.7038); // Madrid default

  @override
  void initState() {
    super.initState();
    _fetchMapData();
  }

  Future<void> _fetchMapData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await widget.apiClient.getColeccionesMapa(modo: _modo);
      
      if (mounted) {
        setState(() {
          _colecciones = data;
          _isLoading = false;
          if (_colecciones.isNotEmpty) {
             // Buscar un punto centrado o usar el primero
             final lat = (_colecciones.first['latitud'] as num?)?.toDouble();
             final lon = (_colecciones.first['longitud'] as num?)?.toDouble();
             if (lat != null && lon != null) {
               _mapCenter = LatLng(lat, lon);
             }
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading home map preview: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPostPreview(Map<String, dynamic> col) {
    String? imageUrl = col['path_foto_usuario'];
    String titulo = col['variedad'] != null ? col['variedad']['nombre'] : 'Colección';
    final prop = col['propietario'];
    String autor = prop != null ? "${prop['nombre']} ${prop['apellidos']}" : "Desconocido";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
             if (imageUrl != null)
               ClipRRect(
                 borderRadius: BorderRadius.circular(20),
                 child: CachedNetworkImage(imageUrl: imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover),
               ),
             const SizedBox(height: 20),
             Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
             Text("Por $autor", style: TextStyle(color: Colors.grey.shade600)),
             const SizedBox(height: 10),
             if (col['notas'] != null) Text(col['notas']),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF142018)))
            : Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _mapCenter,
                      initialZoom: 6.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.vinas.app',
                      ),
                      MarkerLayer(
                        markers: _colecciones.map((col) {
                          final lat = (col['latitud'] as num?)?.toDouble();
                          final lon = (col['longitud'] as num?)?.toDouble();
                          if (lat == null || lon == null) return null;
                          return Marker(
                            point: LatLng(lat, lon),
                            width: 45,
                            height: 45,
                            child: GestureDetector(
                              onTap: () => _showPostPreview(col),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  color: const Color(0xFF142018),
                                ),
                                child: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: col['path_foto_usuario'] ?? '',
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) => const Icon(Icons.location_on, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).whereType<Marker>().toList(),
                      ),
                    ],
                  ),
                  // Overlay Controls
                  Positioned(
                    top: 15,
                    left: 15,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMiniTab("Global", 'publico'),
                          _buildMiniTab("Mis fotos", 'privado'),
                        ],
                      ),
                    ),
                  ),

                  // Expand Button (Top Right)
                  Positioned(
                    top: 15,
                    right: 15,
                    child: GestureDetector(
                      onTap: () {
                         Navigator.push(
                           context,
                           MaterialPageRoute(builder: (context) => MapaColeccionesPage(initialModo: _modo)),
                         );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: const Icon(Icons.fullscreen, color: Color(0xFF142018), size: 20),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMiniTab(String label, String mode) {
    bool isSelected = _modo == mode;
    return GestureDetector(
      onTap: () {
        if (_modo != mode) {
          setState(() => _modo = mode);
          _fetchMapData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF142018) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
