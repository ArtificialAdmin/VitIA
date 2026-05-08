import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/core/api_config.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anotar Dataset'),
        backgroundColor: const Color(0xFF1E2623), // Un color distinto al de validaciones
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _colecciones.isEmpty
              ? const Center(child: Text('El dataset está completamente anotado. ¡Buen trabajo!'))
              : ListView.builder(
                  itemCount: _colecciones.length,
                  itemBuilder: (context, index) {
                    final coleccion = _colecciones[index];
                    final variedadInfo = coleccion['variedad'] != null ? coleccion['variedad']['nombre'] : 'Desconocida';
                    
                    String? path = coleccion['path_foto_usuario']?.toString();
                    String imageUrl = '';
                    if (path != null && path.isNotEmpty) {
                      if (path.startsWith('http')) {
                        imageUrl = path;
                      } else {
                        final baseUrl = getBaseUrl();
                        imageUrl = path.startsWith('/') ? "$baseUrl$path" : "$baseUrl/$path";
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: imageUrl.isNotEmpty
                            ? CircleAvatar(backgroundImage: NetworkImage(imageUrl))
                            : const CircleAvatar(child: Icon(Icons.image)),
                        title: Text('Variedad IA: $variedadInfo'),
                        subtitle: Text('ID Colección: ${coleccion['id_coleccion']} | Tipo: ${coleccion['es_premium'] ? "Premium" : "Básica"}'),
                        trailing: const Icon(Icons.arrow_forward_ios),
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
                      ),
                    );
                  },
                ),
    );
  }
}
