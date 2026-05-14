import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/core/api_config.dart';
import 'package:vinas_mobile/shared/styles/app_theme.dart';
import 'validacion_detalle_page.dart';

class AnotacionDatasetPage extends ConsumerStatefulWidget {
  const AnotacionDatasetPage({super.key});

  @override
  ConsumerState<AnotacionDatasetPage> createState() => _AnotacionDatasetPageState();
}

class _AnotacionDatasetPageState extends ConsumerState<AnotacionDatasetPage> {
  bool _isLoading = true;
  List<dynamic> _colecciones = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiProvider);
      final colecciones = await api.expertoDataSource.getColeccionesDataset();
      if (mounted) {
        setState(() {
          _colecciones = colecciones;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.vinoVitIA));
    }

    if (_colecciones.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'El dataset está completamente anotado. ¡Buen trabajo!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grisVitIA, fontSize: 16),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.vinoVitIA,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: _colecciones.length,
        itemBuilder: (context, index) {
          final coleccion = _colecciones[index];
          final variedadInfo = coleccion['variedad'] != null ? coleccion['variedad']['nombre'] : 'Desconocida';
          final isPremium = coleccion['es_premium'] == true;
          final idCol = coleccion['id_coleccion'];
          
          String imageUrl = coleccion['path_foto_usuario']?.toString() ?? '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: AppColors.grisClaro2VitIA.withOpacity(0.5)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ValidacionDetallePage(
                        validacion: coleccion,
                        isModoDataset: true,
                      ),
                    ),
                  );
                  if (result == true) {
                    _loadData();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Imagen con estilo miniatura premium
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: Colors.grey.shade100,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: imageUrl.isNotEmpty
                              ? Image.network(imageUrl, fit: BoxFit.cover)
                              : const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Información
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ID: #$idCol',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.grisVitIA,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (isPremium)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4AF37).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.bolt, size: 10, color: Color(0xFFD4AF37)),
                                        SizedBox(width: 2),
                                        Text(
                                          'PREMIUM',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFFD4AF37),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              variedadInfo,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.negroVitIA,
                                fontFamily: 'Lora', // Usando Lora si está disponible en el tema
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  coleccion['latitud'] != null ? Icons.location_on : Icons.location_off,
                                  size: 14,
                                  color: AppColors.grisVitIA,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  coleccion['latitud'] != null ? 'Geolocalizado' : 'Sin GPS',
                                  style: const TextStyle(fontSize: 12, color: AppColors.grisVitIA),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.grisVitIA),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
