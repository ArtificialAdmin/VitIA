import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:vinas_mobile/features/coleccion/ui/coleccion_detalle_page.dart';

class MapaPrincipalPage extends ConsumerStatefulWidget {
  final String? initialModo;
  const MapaPrincipalPage({super.key, this.initialModo});

  @override
  ConsumerState<MapaPrincipalPage> createState() => _MapaPrincipalPageState();
}

class _MapaPrincipalPageState extends ConsumerState<MapaPrincipalPage> {
  bool _isLoading = true;
  List<dynamic> _colecciones = [];
  String _modo = 'publico'; // 'publico' o 'privado'
  final MapController _mapController = MapController();

  // default center (can be tuned or user's location)
  LatLng _mapCenter = const LatLng(40.4168, -3.7038); // Madrid center default

  @override
  void initState() {
    super.initState();
    _modo = widget.initialModo ?? 'publico';
    _fetchMapData();
  }

  Future<void> _fetchMapData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiProvider);
      final data = await apiClient.getColeccionesMapa(modo: _modo);
      debugPrint("Received ${data.length} collections for map.");

      setState(() {
        _colecciones = data;
        _isLoading = false;
        if (_colecciones.isNotEmpty) {
          final firstPubLat = _colecciones.first['latitud'] as num?;
          final firstPubLon = _colecciones.first['longitud'] as num?;
          if (firstPubLat != null && firstPubLon != null) {
            _mapCenter = LatLng(firstPubLat.toDouble(), firstPubLon.toDouble());

            // FIX: Use addPostFrameCallback to ensure Map is ready
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                try {
                  _mapController.move(_mapCenter, 13.0);
                } catch (e) {
                  debugPrint(
                      "MapController move failed (expected if not yet ready): $e");
                }
              }
            });
          }
        }
      });
    } catch (e) {
      debugPrint("Error loading map data: $e");
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al cargar mapa: $e")),
        );
      }
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
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 200,
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
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: Color(0xFF2D3436)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        fechaStr,
                        style: const TextStyle(
                            color: Color(0xFF1976D2),
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      autor,
                      style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
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
                const SizedBox(height: 10),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fondo oscuro para carga
      body: Stack(
        children: [
          // 1. MAPA (FONDO COMPLETO)
          _isLoading && _colecciones.isEmpty
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _mapCenter,
                    initialZoom: 7.0,
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
                          width: 55,
                          height: 55,
                          child: GestureDetector(
                            onTap: () => _showPostPreview(col),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2))
                                ],
                                color: const Color(0xFF142018),
                              ),
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: col['path_foto_usuario'] ?? '',
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.image, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).whereType<Marker>().toList(),
                    ),
                  ],
                ),

          // 2. CARGANDO (OVERLAY)
          if (_isLoading && _colecciones.isNotEmpty)
             const Positioned(
               top: 100,
               left: 0,
               right: 0,
               child: Center(child: CircularProgressIndicator(color: Color(0xFF142018))),
             ),

          // 3. CONTROLES FLOTANTES
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                   // Botón Atrás
                   GestureDetector(
                     onTap: () => Navigator.pop(context),
                     child: Container(
                       padding: const EdgeInsets.all(12),
                       decoration: BoxDecoration(
                         color: Colors.white,
                         shape: BoxShape.circle,
                         boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                       ),
                       child: const Icon(Icons.arrow_back, color: Color(0xFF142018), size: 24),
                     ),
                   ),
                   const SizedBox(width: 15),
                   // Selector de modo
                   Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildFullTab("Global", 'publico'),
                          _buildFullTab("Mis fotos", 'privado'),
                        ],
                      ),
                   ),
                ],
              ),
            ),
          ),

          // 4. AVISO VACÍO
          if (!_isLoading && _colecciones.isEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text("Sin capturas con ubicación", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullTab(String label, String mode) {
    bool isSelected = _modo == mode;
    return GestureDetector(
      onTap: () {
        if (_modo != mode) {
          setState(() => _modo = mode);
          _fetchMapData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF142018) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
