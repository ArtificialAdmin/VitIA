import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'validacion_detalle_page.dart';

class ValidacionesPage extends ConsumerStatefulWidget {
  const ValidacionesPage({Key? key}) : super(key: key);

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validaciones Pendientes'),
        backgroundColor: const Color(0xFFD4AF37),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _validaciones.isEmpty
              ? const Center(child: Text('No hay validaciones pendientes'))
              : ListView.builder(
                  itemCount: _validaciones.length,
                  itemBuilder: (context, index) {
                    final item = _validaciones[index];
                    final coleccion = item['coleccion'];
                    final variedadInfo = coleccion['variedad'] != null ? coleccion['variedad']['nombre'] : 'Desconocida';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: coleccion['path_foto_usuario'] != null
                            ? CircleAvatar(backgroundImage: NetworkImage(coleccion['path_foto_usuario']))
                            : const CircleAvatar(child: Icon(Icons.image)),
                        title: Text('Variedad IA: $variedadInfo'),
                        subtitle: Text('Solicitada: ${item['solicitada_en'].toString().substring(0,10)}'),
                        trailing: const Icon(Icons.arrow_forward_ios),
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
                      ),
                    );
                  },
                ),
    );
  }
}
