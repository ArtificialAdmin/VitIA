import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/core/api_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinas_mobile/shared/styles/app_theme.dart';

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
    
    String getBaseName(String url) {
      try {
        final uri = Uri.parse(url);
        String name = uri.pathSegments.last;
        if (name.contains('_') && name.contains('.')) {
          return name.substring(0, name.lastIndexOf('_'));
        }
        return name;
      } catch (e) {
        return url;
      }
    }

    final List<dynamic> fotosAEvaluar = [];
    final String? mainPhoto = coleccion['path_foto_usuario'];
    if (mainPhoto != null && mainPhoto.isNotEmpty) {
      fotosAEvaluar.add(mainPhoto);
    }

    final fotosPremium = coleccion['fotos_premium'] as List<dynamic>? ?? [];
    final mainBaseName = mainPhoto != null ? getBaseName(mainPhoto) : null;

    for (var foto in fotosPremium) {
      final fotoUrl = foto.toString();
      final fotoBaseName = getBaseName(fotoUrl);
      bool isDuplicate = fotosAEvaluar.contains(fotoUrl) || (mainBaseName != null && fotoBaseName == mainBaseName);
      if (!isDuplicate) {
        fotosAEvaluar.add(fotoUrl);
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
        setState(() => _variedades = vars);
      }
    } catch (e) { /* silent */ }
  }

  Future<void> _submit() async {
    if (_esCorrecta == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, indica si la variedad es correcta.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiProvider);
      List<Map<String, dynamic>> evalList = [];
      _evaluacionImagenes.forEach((url, valida) {
        if (valida != null) evalList.add({'url': url, 'valida': valida});
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evaluación completada'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coleccion = widget.isModoDataset ? widget.validacion : widget.validacion['coleccion'];
    final variedadInfo = coleccion['variedad'] != null ? coleccion['variedad']['nombre'] : 'Desconocida';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.negroVitIA),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Evaluar Captura",
          style: GoogleFonts.lora(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.negroVitIA,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            
            // --- SECCIÓN 1: INFO IA ---
            _buildSectionTitle("Detección de la IA"),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.grisClaro1VitIA,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    variedadInfo,
                    style: GoogleFonts.lora(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.negroVitIA,
                    ),
                  ),
                  if (coleccion['analisis_ia'] != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      coleccion['analisis_ia'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.grisVitIA,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- SECCIÓN 2: EVALUACIÓN ---
            _buildSectionTitle("¿Es correcta la variedad?"),
            Row(
              children: [
                _buildChoiceChip("SÍ, ES CORRECTA", true, Icons.check_circle_outline),
                const SizedBox(width: 12),
                _buildChoiceChip("NO, ES ERRÓNEA", false, Icons.error_outline),
              ],
            ),

            if (_esCorrecta == false) ...[
              const SizedBox(height: 20),
              _buildSectionTitle("Indica la variedad real"),
              _buildVarietySelector(),
            ],

            const SizedBox(height: 32),

            // --- SECCIÓN 3: IMÁGENES ---
            _buildSectionTitle("Anotación de imágenes"),
            const Text(
              "Marca las fotos que tengan buena calidad para el dataset.",
              style: TextStyle(fontSize: 13, color: AppColors.grisVitIA),
            ),
            const SizedBox(height: 16),
            _buildImagesGrid(),

            const SizedBox(height: 32),

            // --- SECCIÓN 4: FEEDBACK ---
            _buildSectionTitle("Notas del experto"),
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Añade cualquier observación relevante...",
                filled: true,
                fillColor: AppColors.grisClaro1VitIA,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // --- BOTÓN FINAL ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text("GUARDAR EVALUACIÓN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: AppColors.grisVitIA,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, bool value, IconData icon) {
    final bool isSelected = _esCorrecta == value;
    final Color activeColor = value ? Colors.green.shade700 : Colors.red.shade700;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _esCorrecta = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.1) : AppColors.grisClaro1VitIA,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? activeColor : AppColors.grisVitIA),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? activeColor : AppColors.grisVitIA,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVarietySelector() {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) return const Iterable.empty();
        return _variedades
            .where((v) => v['nombre'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase()))
            .map((v) => Map<String, dynamic>.from(v));
      },
      displayStringForOption: (option) => option['nombre'].toString(),
      onSelected: (option) => setState(() {
        _idVariedadCorrecta = option['id_variedad'];
        _variedadController.text = option['nombre'];
      }),
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        controller.addListener(() {
          _variedadController.text = controller.text;
          if (_idVariedadCorrecta != null) {
            final sel = _variedades.firstWhere((v) => v['id_variedad'] == _idVariedadCorrecta, orElse: () => null);
            if (sel == null || sel['nombre'] != controller.text) _idVariedadCorrecta = null;
          }
        });
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: "Escribe para buscar variedad...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: AppColors.grisClaro1VitIA,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        );
      },
    );
  }

  Widget _buildImagesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _evaluacionImagenes.length,
      itemBuilder: (context, index) {
        final url = _evaluacionImagenes.keys.elementAt(index);
        final bool? val = _evaluacionImagenes[url];
        String dUrl = url;
        if (!dUrl.startsWith('http')) {
          final b = getBaseUrl();
          dUrl = dUrl.startsWith('/') ? "$b$dUrl" : "$b/$dUrl";
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.grisClaro2VitIA),
          ),
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: EdgeInsets.zero,
                        child: Stack(
                          children: [
                            InteractiveViewer(
                              panEnabled: true,
                              minScale: 0.5,
                              maxScale: 4.0,
                              child: Center(
                                child: Image.network(dUrl, fit: BoxFit.contain),
                              ),
                            ),
                            Positioned(
                              top: 40,
                              right: 20,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: Image.network(dUrl, fit: BoxFit.cover, width: double.infinity),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: IconButton(
                        icon: Icon(Icons.check_circle, color: val == true ? Colors.green : Colors.grey.shade300, size: 24),
                        onPressed: () => setState(() => _evaluacionImagenes[url] = true),
                      ),
                    ),
                    Expanded(
                      child: IconButton(
                        icon: Icon(Icons.cancel, color: val == false ? Colors.red : Colors.grey.shade300, size: 24),
                        onPressed: () => setState(() => _evaluacionImagenes[url] = false),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

