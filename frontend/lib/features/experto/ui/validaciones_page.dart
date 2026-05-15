import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/shared/styles/app_theme.dart';
import 'validacion_detalle_page.dart';

class ValidacionesPage extends ConsumerStatefulWidget {
  const ValidacionesPage({super.key});

  @override
  ConsumerState<ValidacionesPage> createState() => _ValidacionesPageState();
}

class _ValidacionesPageState extends ConsumerState<ValidacionesPage> {
  bool _isLoading = true;
  List<dynamic> _validaciones = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiProvider);
      final validaciones = await api.expertoDataSource.getValidacionesPendientes();
      if (mounted) {
        setState(() {
          _validaciones = validaciones;
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
    
    if (_validaciones.isEmpty) {
      return const Center(child: Text('No hay validaciones pendientes', style: TextStyle(color: AppColors.grisVitIA)));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.vinoVitIA,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: _validaciones.length,
        itemBuilder: (context, index) {
          final item = _validaciones[index];
          final coleccion = item['coleccion'];
          final variedadInfo = coleccion['variedad'] != null ? coleccion['variedad']['nombre'] : 'Desconocida';
          final fechaStr = item['solicitada_en']?.toString().split('T')[0] ?? 'Fecha desconocida';
          final imageUrl = coleccion['path_foto_usuario']?.toString() ?? '';

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
                      builder: (context) => ValidacionDetallePage(validacion: item),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'SOLICITUD: $fechaStr',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.vinoVitIA,
                                      letterSpacing: 1.0,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.vinoVitIA.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'PENDIENTE',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.vinoVitIA),
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
                                fontFamily: 'Lora',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            const Row(
                              children: [
                                Icon(Icons.person_outline, size: 14, color: AppColors.grisVitIA),
                                SizedBox(width: 4),
                                Text(
                                  'Petición de usuario',
                                  style: TextStyle(fontSize: 12, color: AppColors.grisVitIA),
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
