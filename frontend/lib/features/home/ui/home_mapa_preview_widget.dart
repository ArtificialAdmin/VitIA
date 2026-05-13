import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/features/mapa/ui/mapa_principal_page.dart';
import 'package:vinas_mobile/features/coleccion/ui/coleccion_detalle_page.dart';
import 'package:vinas_mobile/features/chat/ui/chat_room_page.dart';

class HomeMapaPreviewWidget extends ConsumerStatefulWidget {
  const HomeMapaPreviewWidget({super.key});

  @override
  ConsumerState<HomeMapaPreviewWidget> createState() => _HomeMapPreviewState();
}

class _HomeMapPreviewState extends ConsumerState<HomeMapaPreviewWidget> {
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
      final data = await ref.read(apiProvider).getColeccionesMapa(modo: _modo);
      
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

  Future<String> _getDishplayAddress(double lat, double lon) async {
    try {
      final dio = Dio();
      // Nominatim requires a User-Agent
      final response = await dio
          .get(
            'https://nominatim.openstreetmap.org/reverse',
            queryParameters: {
              'format': 'json',
              'lat': lat,
              'lon': lon,
              'zoom': 18,
              'addressdetails': 1,
            },
            options: Options(headers: {'User-Agent': 'VitIA-App'}),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200 && response.data != null) {
        return response.data['display_name'] ?? "$lat, $lon";
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
    }
    return "$lat, $lon";
  }

  void _showPostPreview(Map<String, dynamic> col) {
    String? imageUrl = col['path_foto_usuario'];
    String titulo =
        col['variedad'] != null ? col['variedad']['nombre'] : 'Colección';

    // Propietario (Author)
    final prop = col['propietario'];
    String autor = "Desconocido";
    if (prop != null) {
      autor = "${prop['nombre']} ${prop['apellidos']}";
    }
    // Fecha
    String fechaStr = "Fecha desconocida";
    if (col['fecha_captura'] != null) {
      try {
        DateTime dt = DateTime.parse(col['fecha_captura']);
        // Formato simple: DD/MM/YYYY
        fechaStr = "${dt.day}/${dt.month}/${dt.year}";
      } catch (_) {}
    }

    final double? lat = (col['latitud'] as num?)?.toDouble();
    final double? lon = (col['longitud'] as num?)?.toDouble();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (imageUrl != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                            child:
                                const Center(child: CircularProgressIndicator())),
                        errorWidget: (context, url, err) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported)),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Text(
                          fechaStr,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                          letterSpacing: -0.5,
                          color: Color(0xFF111D13)),
                    ),
                  ),
                  if (prop != null && prop['id_usuario'] != null && prop['id_usuario'] != ref.read(userIdProvider))
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFA01B4C).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFFA01B4C)),
                        tooltip: 'Enviar mensaje privado',
                        onPressed: () {
                          _abrirChat(prop['id_usuario'], autor, prop['path_foto_perfil'] ?? prop['foto_perfil']);
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: (prop != null && (prop['path_foto_perfil'] != null || prop['foto_perfil'] != null))
                          ? NetworkImage(prop['path_foto_perfil'] ?? prop['foto_perfil'])
                          : null,
                      child: (prop == null || (prop['path_foto_perfil'] == null && prop['foto_perfil'] == null))
                          ? const Icon(Icons.person, size: 24, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Capturado por",
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          Text(
                            autor,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 12),
              if (col['notas'] != null &&
                  col['notas'].toString().isNotEmpty) ...[
                const Text(
                  "Descripción",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF2D3436)),
                ),
                const SizedBox(height: 8),
                Text(
                  col['notas'],
                  style: TextStyle(
                      color: Colors.grey.shade700, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on,
                      size: 20, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FutureBuilder<String>(
                        future: (lat != null && lon != null)
                            ? _getDishplayAddress(lat, lon)
                            : Future.value("Sin ubicación"),
                        builder: (context, snapshot) {
                          String address =
                              snapshot.data ?? "Cargando dirección...";
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            address = "Cargando dirección...";
                          }
                          return Text(
                            address,
                            style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 13,
                                fontStyle: FontStyle.italic),
                          );
                        }),
                  ),
                ],
              ),
              if (_modo == 'privado') ...[
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Cerrar bottom sheet
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ColeccionDetallePage(
                            coleccionItem: {
                              'id': col['id_coleccion'],
                              'nombre': col['variedad']?['nombre'] ?? 'Colección',
                              'descripcion': col['notas'] ?? '',
                              'latitud': lat,
                              'longitud': lon,
                              'es_publica': col['es_publica'],
                              'imagen': col['path_foto_usuario'],
                              'tipo': col['variedad']?['color'] ?? 'Tinta',
                              'fecha_captura': col['fecha_captura'],
                              'validacion': col['validacion'],
                              'es_premium': col['es_premium'],
                              'fotos_premium': col['fotos_premium'],
                              'analisis_ia': col['analisis_ia'],
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.collections_outlined, color: Colors.white),
                    label: const Text("Ver en mi colección"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF142018),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFBF6),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.black87),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
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
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
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
                           MaterialPageRoute(builder: (context) => MapaPrincipalPage(initialModo: _modo)),
                         );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
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
