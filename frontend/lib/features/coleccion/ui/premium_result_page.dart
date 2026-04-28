import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/core/constants.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumResultPage extends ConsumerStatefulWidget {
  final String variety;
  final double confidence;
  final List<XFile> photos;
  final String analysisText;
  final double? lat;
  final double? lon;

  const PremiumResultPage({
    super.key,
    required this.variety,
    required this.confidence,
    required this.photos,
    required this.analysisText,
    this.lat,
    this.lon,
  });

  @override
  ConsumerState<PremiumResultPage> createState() => _PremiumResultPageState();
}

class _PremiumResultPageState extends ConsumerState<PremiumResultPage> {
  int _coverIndex = 0;
  bool _isSaving = false;
  final TextEditingController _notesController = TextEditingController();

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiProvider);
      
      await api.saveToCollection(
        imageFile: widget.photos[_coverIndex], // Selected cover
        premiumFiles: widget.photos, // All 4 photos
        nombreVariedad: widget.variety,
        analisisIA: widget.analysisText,
        notas: _notesController.text,
        lat: widget.lat,
        lon: widget.lon,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Identificación guardada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Go back to capture or home
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Fondo claro general de la app
      appBar: AppBar(
        title: const Text(
          'Análisis Premium',
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    widget.variety,
                    style: GoogleFonts.lora(
                      color: Colors.black87,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                    ),
                    child: Text(
                      'Confianza: ${widget.confidence.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Main Photo Carousel
            SizedBox(
              height: 300,
              child: PageView.builder(
                itemCount: widget.photos.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      image: DecorationImage(
                        image: FileImage(File(widget.photos[index].path)),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  'Desliza para revisar las 4 capturas',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            ),

            // 3. Cover Selector (MORE PROMINENT)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: const [
                      Icon(Icons.photo_camera, color: Color(0xFFD4AF37), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Elegir foto de portada',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.photos.length,
                      itemBuilder: (context, index) {
                        bool isSelected = _coverIndex == index;
                        return GestureDetector(
                          onTap: () => setState(() => _coverIndex = index),
                          child: Container(
                            width: 80,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFD4AF37)
                                    : Colors.grey[300]!,
                                width: isSelected ? 3 : 1,
                              ),
                              image: DecorationImage(
                                image:
                                    FileImage(File(widget.photos[index].path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: isSelected
                                ? const Center(
                                    child: Icon(Icons.check_circle,
                                        color: Color(0xFFD4AF37)),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 4. AI Analysis Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Análisis de la IA',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.analysisText,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),


            // 5. Notes
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: _notesController,
                maxLines: 3,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Añadir notas personales...',
                  hintStyle: const TextStyle(color: Colors.black38),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                  ),
                ),
              ),
            ),

            // 6. Action Buttons (Save or Discard)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                children: [
                   SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text(
                              'Confirmar y Guardar',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () {
                        // Simple pop acts as discard
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Descartar Identificación', 
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
