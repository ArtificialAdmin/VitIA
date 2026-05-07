import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/providers.dart';

class ValidacionDetallePage extends ConsumerStatefulWidget {
  final dynamic validacion;
  const ValidacionDetallePage({Key? key, required this.validacion}) : super(key: key);

  @override
  ConsumerState<ValidacionDetallePage> createState() => _ValidacionDetallePageState();
}

class _ValidacionDetallePageState extends ConsumerState<ValidacionDetallePage> {
  bool? _esCorrecta;
  final _feedbackController = TextEditingController();
  bool _isSaving = false;
  
  // Para autoanotación: mapa de url -> bool (true = buena, false = mala, null = no evaluada)
  Map<String, bool?> _evaluacionImagenes = {};

  @override
  void initState() {
    super.initState();
    final coleccion = widget.validacion['coleccion'];
    final fotosPremium = coleccion['fotos_premium'] as List<dynamic>? ?? [];
    for (var foto in fotosPremium) {
      _evaluacionImagenes[foto.toString()] = null;
    }
  }

  Future<void> _submit() async {
    if (_esCorrecta == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, indica si la variedad es correcta.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiProvider);
      
      // Convertir mapa a lista de dicts
      List<Map<String, dynamic>> evalList = [];
      _evaluacionImagenes.forEach((url, valida) {
        if (valida != null) {
          evalList.add({'url': url, 'valida': valida});
        }
      });

      await api.expertoDataSource.validateItem(
        widget.validacion['id_validacion'],
        esCorrecta: _esCorrecta!,
        feedbackExperto: _feedbackController.text,
        evaluacionImagenes: evalList.isNotEmpty ? evalList : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Validación guardada con éxito'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coleccion = widget.validacion['coleccion'];
    final variedadInfo = coleccion['variedad'] != null ? coleccion['variedad']['nombre'] : 'Desconocida';
    final fotosPremium = coleccion['fotos_premium'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Evaluar Captura')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Variedad Detectada por IA: $variedadInfo', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (coleccion['analisis_ia'] != null)
              Text('Análisis IA: ${coleccion['analisis_ia']}', style: const TextStyle(fontStyle: FontStyle.italic)),
            const Divider(height: 30),
            
            const Text('¿La variedad detectada es correcta?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Sí'),
                    value: true,
                    groupValue: _esCorrecta,
                    onChanged: (val) => setState(() => _esCorrecta = val),
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('No'),
                    value: false,
                    groupValue: _esCorrecta,
                    onChanged: (val) => setState(() => _esCorrecta = val),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            const Text('Anotación de Imágenes (Opcional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Text('Marca las imágenes que sirvan para entrenar el modelo.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: fotosPremium.length,
              itemBuilder: (context, index) {
                final url = fotosPremium[index].toString();
                final bool? val = _evaluacionImagenes[url];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Image.network(url, height: 150, width: double.infinity, fit: BoxFit.cover),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check, color: Colors.white),
                              label: const Text('Buena'),
                              style: ElevatedButton.styleFrom(backgroundColor: val == true ? Colors.green : Colors.grey),
                              onPressed: () => setState(() => _evaluacionImagenes[url] = true),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.close, color: Colors.white),
                              label: const Text('Mala'),
                              style: ElevatedButton.styleFrom(backgroundColor: val == false ? Colors.red : Colors.grey),
                              onPressed: () => setState(() => _evaluacionImagenes[url] = false),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
            TextField(
              controller: _feedbackController,
              decoration: const InputDecoration(labelText: 'Feedback Adicional (Opcional)', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirmar Evaluación', style: TextStyle(fontSize: 18, color: Colors.black)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
