import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/shared/components/loading_indicator.dart';
import 'package:vinas_mobile/shared/styles/app_theme.dart';
import 'package:vinas_mobile/features/experto/ui/validacion_detalle_page.dart';

import 'package:cached_network_image/cached_network_image.dart';

class ExpertoMapaPage extends ConsumerStatefulWidget {
  const ExpertoMapaPage({super.key});

  @override
  ConsumerState<ExpertoMapaPage> createState() => _ExpertoMapaPageState();
}

class _ExpertoMapaPageState extends ConsumerState<ExpertoMapaPage> {
  final MapController _mapController = MapController();
  List<dynamic> _colecciones = [];
  bool _isLoading = true;
  final LatLng _mapCenter = const LatLng(39.4699, -0.3763); // Valencia por defecto

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiProvider);
      final data = await api.coleccionDataSource.getExpertoMapa();
      if (mounted) {
        setState(() {
          _colecciones = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al cargar mapa de experto: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
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

                  // Determinar color según estado de validación
                  Color markerColor = Colors.grey;
                  final validacion = col['validacion'];
                  if (validacion != null) {
                    if (validacion['estado'] == 'validada') {
                      markerColor = validacion['es_correcta'] == true ? Colors.green : Colors.red;
                    } else if (validacion['estado'] == 'pendiente') {
                      markerColor = Colors.orange;
                    }
                  }

                  return Marker(
                    point: LatLng(lat, lon),
                    width: 55,
                    height: 55,
                    child: GestureDetector(
                      onTap: () => _showDetails(col),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: markerColor, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
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
          if (_isLoading)
            const Center(child: LoadingIndicator(label: "Cargando mapa global...")),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.admin_panel_settings_rounded, color: AppColors.vinoVitIA, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Mapa de Experto",
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.negroVitIA),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.close_rounded, color: AppColors.negroVitIA, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Leyenda
          Positioned(
            bottom: 110,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("ESTADOS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.grey)),
                  const SizedBox(height: 8),
                  _buildLegendItem(Colors.orange, "Pendiente"),
                  _buildLegendItem(Colors.green, "Validada (OK)"),
                  _buildLegendItem(Colors.red, "Validada (Error)"),
                  _buildLegendItem(Colors.grey, "Sin solicitud"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showDetails(Map<String, dynamic> col) {
    final variedad = col['variedad']?['nombre'] ?? "Desconocida";
    final prop = col['propietario'];
    final autor = prop != null ? "${prop['nombre']} ${prop['apellidos'] ?? ''}" : "Anónimo";
    final isPublic = col['es_publica'] ?? true;
    final imageUrl = col['path_foto_usuario'];
    final fechaStr = col['fecha_captura'] != null 
        ? DateTime.parse(col['fecha_captura']).toLocal().toString().substring(0, 10) 
        : "Fecha desconocida";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
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
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
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
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(variedad, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: AppColors.negroVitIA)),
                  ),
                  if (!isPublic) const Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text("Subida por: $autor", style: const TextStyle(color: Colors.grey, fontSize: 14)),
              Text("Fecha: $fechaStr", style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 24),
              if (col['validacion'] != null && col['validacion']['estado'] == 'validada')
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: col['validacion']['es_correcta'] == true ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: col['validacion']['es_correcta'] == true ? Colors.green.shade200 : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            col['validacion']['es_correcta'] == true ? Icons.check_circle : Icons.cancel,
                            color: col['validacion']['es_correcta'] == true ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              col['validacion']['es_correcta'] == true
                                  ? "El análisis de esta captura fue validado como CORRECTO por un experto."
                                  : "El análisis de esta captura fue validado como INCORRECTO por un experto.",
                              style: TextStyle(
                                color: col['validacion']['es_correcta'] == true ? Colors.green.shade900 : Colors.red.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text("Editar Validación"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.negroVitIA,
                          side: const BorderSide(color: AppColors.negroVitIA),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ValidacionDetallePage(validacion: col, isModoDataset: true)),
                          );
                        },
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text("Ver Detalles / Gestionar Validación"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.negroVitIA,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      if (col['validacion'] != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ValidacionDetallePage(validacion: col['validacion'])),
                        );
                      } else {
                        // Navigate in dataset mode since there is no specific validation request
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ValidacionDetallePage(validacion: col, isModoDataset: true)),
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
