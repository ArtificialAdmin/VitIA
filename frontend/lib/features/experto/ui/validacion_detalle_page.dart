import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/core/api_config.dart';

class ValidacionDetallePage extends ConsumerStatefulWidget {
  final dynamic validacion; // Puede ser ValidacionExperto o Coleccion
  final bool isModoDataset;
  
  const ValidacionDetallePage({
    super.key, 
    required this.validacion,
    this.isModoDataset = false,
  });

  @override
  ConsumerState<ValidacionDetallePage> createState() => _ValidacionDetallePageState();
}

class _ValidacionDetallePageState extends ConsumerState<ValidacionDetallePage> {
  bool? _esCorrecta;
  final _feedbackController = TextEditingController();
  final _variedadController = TextEditingController();
  bool _isSaving = false;
  List<dynamic> _variedades = [];
  int? _idVariedadCorrecta;
  
  // Para autoanotación: mapa de url -> bool (true = buena, false = mala, null = no evaluada)
  final Map<String, bool?> _evaluacionImagenes = {};

  @override
  void initState() {
    super.initState();
    final coleccion = widget.isModoDataset ? widget.validacion : widget.validacion['coleccion'];
    final List<dynamic> fotosAEvaluar = [];
    
    // Añadimos la foto principal
    if (coleccion['path_foto_usuario'] != null && coleccion['path_foto_usuario'].toString().isNotEmpty) {
      fotosAEvaluar.add(coleccion['path_foto_usuario']);
    }

    // Añadimos las fotos premium sin duplicar la principal
    final fotosPremium = coleccion['fotos_premium'] as List<dynamic>? ?? [];
    for (var foto in fotosPremium) {
      if (!fotosAEvaluar.contains(foto)) {
        fotosAEvaluar.add(foto);
      }
    }

    for (var foto in fotosAEvaluar) {
      _evaluacionImagenes[foto.toString()] = null;
    }

    _loadVariedades();
  }

  Future<void> _loadVariedades() async {
    try {
      final api = ref.read(apiProvider);
      final vars = await api.getVariedades();
      if (mounted) {
        setState(() {
          _variedades = vars;
        });
      }
    } catch (e) {
      // Ignorar error silenciado
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

      if (widget.isModoDataset) {
        await api.expertoDataSource.anotarColeccionDataset(
          widget.validacion['id_coleccion'],
          esCorrecta: _esCorrecta!,
          feedbackExperto: _feedbackController.text,
          evaluacionImagenes: evalList.isNotEmpty ? evalList : null,
          idVariedadCorrecta: _esCorrecta == false ? _idVariedadCorrecta : null,
          variedadSugerida: _esCorrecta == false && _idVariedadCorrecta == null && _variedadController.text.isNotEmpty 
              ? _variedadController.text 
              : null,
        );
      } else {
        await api.expertoDataSource.validateItem(
          widget.validacion['id_validacion'],
          esCorrecta: _esCorrecta!,
          feedbackExperto: _feedbackController.text,
          evaluacionImagenes: evalList.isNotEmpty ? evalList : null,
          idVariedadCorrecta: _esCorrecta == false ? _idVariedadCorrecta : null,
          variedadSugerida: _esCorrecta == false && _idVariedadCorrecta == null && _variedadController.text.isNotEmpty 
              ? _variedadController.text 
              : null,
        );
      }

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
    final coleccion = widget.isModoDataset ? widget.validacion : widget.validacion['coleccion'];
    final variedadInfo = coleccion['variedad'] != null ? coleccion['variedad']['nombre'] : 'Desconocida';

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
            
            if (_esCorrecta == false) ...[
              const SizedBox(height: 15),
              const Text('¿Cuál es la variedad correcta?', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<Map<String, dynamic>>.empty();
                  }
                  return _variedades.map((e) => Map<String, dynamic>.from(e)).where((v) {
                    final nombre = v['nombre'].toString().toLowerCase();
                    return nombre.contains(textEditingValue.text.toLowerCase());
                  });
                },
                displayStringForOption: (option) => option['nombre'].toString(),
                onSelected: (option) {
                  setState(() {
                    _idVariedadCorrecta = option['id_variedad'];
                    _variedadController.text = option['nombre'];
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                  // Sincronizar controlador interno con el nuestro para poder leer texto libre
                  controller.addListener(() {
                    _variedadController.text = controller.text;
                    // Si el usuario escribe algo que no es la opción seleccionada, borramos el ID
                    if (_idVariedadCorrecta != null) {
                      final selectedVar = _variedades.firstWhere(
                        (v) => v['id_variedad'] == _idVariedadCorrecta, 
                        orElse: () => null
                      );
                      if (selectedVar == null || selectedVar['nombre'] != controller.text) {
                        _idVariedadCorrecta = null;
                      }
                    }
                  });
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Buscar variedad o escribir sugerencia',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
            ],
            
            const SizedBox(height: 20),
            const Text('Anotación de Imágenes (Opcional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Text('Marca las imágenes que sirvan para entrenar el modelo.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _evaluacionImagenes.length,
              itemBuilder: (context, index) {
                final url = _evaluacionImagenes.keys.elementAt(index);
                final bool? val = _evaluacionImagenes[url];
                
                String displayUrl = url;
                if (!displayUrl.startsWith('http')) {
                  final baseUrl = getBaseUrl();
                  displayUrl = displayUrl.startsWith('/') ? "$baseUrl$displayUrl" : "$baseUrl/$displayUrl";
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Image.network(displayUrl, height: 150, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(height: 150, color: Colors.grey[200], child: const Icon(Icons.broken_image, size: 50, color: Colors.grey))),
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
