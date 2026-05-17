import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vinas_mobile/core/providers.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:vinas_mobile/core/models/prediction_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class PremiumResultPage extends ConsumerStatefulWidget {
  final List<PredictionModel> allPredictions;
  final List<XFile> photos;
  final String analysisText;
  final String? informeDescargable;
  final bool hasMissingPhases;
  final double? lat;
  final double? lon;

  const PremiumResultPage({
    super.key,
    required this.allPredictions,
    required this.photos,
    required this.analysisText,
    this.informeDescargable,
    this.hasMissingPhases = false,
    this.lat,
    this.lon,
  });

  @override
  ConsumerState<PremiumResultPage> createState() => _PremiumResultPageState();
}

class _PremiumResultPageState extends ConsumerState<PremiumResultPage> {
  late PredictionModel _selectedPrediction;
  int _coverIndex = 0;
  bool _isSaving = false;
  bool _solicitaValidacionExperto = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedPrediction = widget.allPredictions.first;
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiProvider);
      
      // Separar la foto de portada de las fotos premium adicionales para evitar duplicados
      final List<XFile> otherPhotos = List.from(widget.photos);
      if (_coverIndex < otherPhotos.length) {
        otherPhotos.removeAt(_coverIndex);
      }

      await api.saveToCollection(
        imageFile: widget.photos[_coverIndex], // Foto principal
        premiumFiles: otherPhotos, // Solo las fotos adicionales
        nombreVariedad: _selectedPrediction.variedad,
        analisisIA: widget.analysisText,
        notas: _notesController.text,
        lat: widget.lat,
        lon: widget.lon,
        solicitaValidacionExperto: _solicitaValidacionExperto,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Identificación guardada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Retornar true indicando que se guardó
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

  Future<pw.Document> _buildPdfDocument() async {
    final pdf = pw.Document();
    final String text = widget.informeDescargable ?? "";
    
    if (text.isEmpty) {
      pdf.addPage(pw.Page(build: (context) => pw.Text("Informe no disponible")));
      return pdf;
    }

    // Use the user's SELECTED prediction, not necessarily the first one
    final variety = _selectedPrediction.variedad;
    final confidence = "${_selectedPrediction.confianza.toStringAsFixed(1)}%";

    final paramMatch = RegExp(r'Parámetros cruzados:\s*(.+)').firstMatch(text);
    final params = paramMatch?.group(1) ?? "N/A";

    final oivRegex = RegExp(r'OIV\s+(\d+)\s+-\s+([^:]+):\s*\n\s*-\s*IA\s*\(Detectado\)\s*:\s*([^\n]+)\s*\n\s*-\s*BD\s*\(Catálogo\)\s*:\s*([^\n]+)');
    final matches = oivRegex.allMatches(text);

    // Cargar y comprimir imágenes para reducir peso del PDF
    final List<pw.MemoryImage> pdfImages = [];
    for (var photo in widget.photos) {
      try {
        // Compresión al 60% de calidad, reduciendo dimensiones si es enorme
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          photo.path,
          minWidth: 800,
          minHeight: 800,
          quality: 60,
        );
        
        if (compressedBytes != null && compressedBytes.isNotEmpty) {
          pdfImages.add(pw.MemoryImage(compressedBytes));
        } else {
          // Fallback a la original si la compresión devuelve null
          final bytes = await photo.readAsBytes();
          pdfImages.add(pw.MemoryImage(bytes));
        }
      } catch (e) {
        // Fallback a la original si la compresión falla
        try {
          final bytes = await photo.readAsBytes();
          pdfImages.add(pw.MemoryImage(bytes));
        } catch (innerE) {
          // Ignorar si realmente no se puede leer la imagen
        }
      }
    }

    // Dynamic Colors based on grape color of the SELECTED variety
    final String? grapeColor = _selectedPrediction.color?.toLowerCase();
    PdfColor primaryColor = PdfColors.deepPurple900;
    PdfColor secondaryColor = PdfColors.deepPurple800;
    PdfColor highlightColor = PdfColors.green800;
    
    if (grapeColor == 'blanca') {
      primaryColor = const PdfColor.fromInt(0xFF8B8000);
      secondaryColor = const PdfColor.fromInt(0xFF6B6300);
      highlightColor = const PdfColor.fromInt(0xFF556B2F);
    } else if (grapeColor == 'tinta' || grapeColor == 'negra' || grapeColor == 'roja') {
      primaryColor = const PdfColor.fromInt(0xFF800020);
      secondaryColor = const PdfColor.fromInt(0xFF600018);
      highlightColor = const PdfColor.fromInt(0xFF800020);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          if (matches.isEmpty && variety == "Desconocida") {
            return [
              pw.Text('Informe de Análisis Premium', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 20),
              pw.Text(text, style: const pw.TextStyle(fontSize: 12)),
            ];
          }

          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('VitIA - Informe Premium', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                ]
              )
            ),
            pw.SizedBox(height: 20),
            
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                border: pw.Border.all(color: PdfColors.grey400)
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("RESULTADO PRINCIPAL", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      pw.Text("Variedad Seleccionada: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.Text(variety, style: pw.TextStyle(fontSize: 16, color: highlightColor, fontWeight: pw.FontWeight.bold)),
                    ]
                  ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    children: [
                      pw.Text("Fiabilidad: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(confidence, style: pw.TextStyle(color: primaryColor)),
                    ]
                  ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    children: [
                      pw.Text("Parámetros analizados: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(params),
                    ]
                  ),
                ]
              )
            ),
            pw.SizedBox(height: 30),
            
            pw.Text("DESGLOSE DE DESCRIPTORES OIV", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            
            if (matches.isNotEmpty)
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: pw.BoxDecoration(color: secondaryColor),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                data: <List<String>>[
                  <String>['Cód.', 'Descriptor OIV', 'Valor Detectado (IA)', 'Valor Catálogo'],
                  ...matches.map((m) => [
                    m.group(1)?.trim() ?? "",
                    m.group(2)?.trim() ?? "",
                    m.group(3)?.trim() ?? "",
                    m.group(4)?.trim() ?? "",
                  ]),
                ],
              ),
              
            pw.SizedBox(height: 30),
            
            pw.Text("RANKING DE VARIEDADES SUGERIDAS", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: widget.allPredictions.asMap().entries.map((entry) {
                final int index = entry.key;
                final pred = entry.value;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    children: [
                      pw.Text("${index + 1}.", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(width: 8),
                      pw.Text(pred.variedad, style: pw.TextStyle(fontWeight: index == 0 ? pw.FontWeight.bold : pw.FontWeight.normal)),
                      pw.SizedBox(width: 10),
                      pw.Text("(${pred.confianza.toStringAsFixed(1)}%)", style: const pw.TextStyle(color: PdfColors.grey700)),
                    ]
                  )
                );
              }).toList(),
            ),
            pw.SizedBox(height: 40),
            pw.Center(
              child: pw.Text("Informe generado automáticamente por el motor VitIA.", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            )
          ];
        },
      ),
    );

    if (pdfImages.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text("CAPTURAS ANALIZADAS", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.SizedBox(height: 20),
                  pw.Wrap(
                    alignment: pw.WrapAlignment.center,
                    spacing: 15,
                    runSpacing: 15,
                    children: pdfImages.map((img) {
                      return pw.Container(
                        width: 245,
                        height: 245,
                        decoration: pw.BoxDecoration(
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                          border: pw.Border.all(color: PdfColors.grey300),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 8,
                          verticalRadius: 8,
                          child: pw.Image(img, fit: pw.BoxFit.cover)
                        )
                      );
                    }).toList(),
                  ),
                  if (widget.lat != null && widget.lon != null) ...[
                    pw.SizedBox(height: 30),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text("Ubicación de captura: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                        pw.Text("${widget.lat!.toStringAsFixed(6)}, ${widget.lon!.toStringAsFixed(6)}", style: const pw.TextStyle(color: PdfColors.grey700)),
                      ]
                    )
                  ],
                ]
              )
            );
          }
        )
      );
    }
    
    return pdf;
  }

  Future<void> _sharePdf() async {
    if (widget.informeDescargable == null || widget.informeDescargable!.isEmpty) return;
    final pdf = await _buildPdfDocument();
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'informe_vitia.pdf');
  }

  Future<void> _downloadPdf() async {
    if (widget.informeDescargable == null || widget.informeDescargable!.isEmpty) return;
    final pdf = await _buildPdfDocument();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'informe_vitia.pdf'
    );
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
                    _selectedPrediction.variedad,
                    style: GoogleFonts.lora(
                      color: Colors.black87,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final bool isBlanca = _selectedPrediction.color?.toLowerCase() == 'blanca';
                    final Color badgeColor = isBlanca
                        ? const Color(0xFF8B8000)
                        : const Color(0xFF800020);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Confianza: ${_selectedPrediction.confianza.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // 1.5 Opciones alternativas (Lógica de umbral del 66%)
            Builder(builder: (context) {
              final bool lowConfidence = widget.allPredictions.first.confianza <= 66.0;
              
              if (widget.allPredictions.length <= 1) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (lowConfidence) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "La confianza es baja (${widget.allPredictions.first.confianza.toStringAsFixed(1)}%). Por favor, selecciona la variedad que consideres correcta:",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange[900],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      const Text(
                        "Otras posibles variedades:",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.allPredictions.length,
                        itemBuilder: (context, idx) {
                          final p = widget.allPredictions[idx];
                          final bool isSelected = _selectedPrediction == p;
                          final bool isBlanca = p.color?.toLowerCase() == 'blanca';
                          final Color varietyColor = isBlanca
                              ? const Color(0xFF8B8000)
                              : const Color(0xFF800020);

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(p.variedad),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedPrediction = p);
                                }
                              },
                              selectedColor: varietyColor.withValues(alpha: 0.2),
                              labelStyle: TextStyle(
                                color: isSelected ? varietyColor : Colors.black54,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected ? varietyColor : Colors.grey.shade300,
                                  ),
                                ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            }),

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
                          color: Colors.black.withValues(alpha: 0.05),
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
                   const Row(
                    children: [
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
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
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
                    if (widget.hasMissingPhases) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "La falta de imágenes en alguna fase puede afectar al análisis correcto de la variedad.",
                                style: TextStyle(color: Colors.deepOrange, fontSize: 13, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            if (widget.informeDescargable != null && widget.informeDescargable!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sharePdf,
                        icon: const Icon(Icons.share, color: Color(0xFFD4AF37), size: 18),
                        label: const Text(
                          'Compartir PDF',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _downloadPdf,
                        icon: const Icon(Icons.download, color: Color(0xFFD4AF37), size: 18),
                        label: const Text(
                          'Guardar PDF',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
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

            // 6. Validación Experto Switch
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: SwitchListTile(
                title: const Text(
                  'Solicitar validación de experto',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text(
                  'Un enólogo experto revisará las imágenes y confirmará si la variedad detectada es correcta.',
                  style: TextStyle(fontSize: 13),
                ),
                value: _solicitaValidacionExperto,
                activeThumbColor: const Color(0xFFD4AF37),
                onChanged: (bool value) async {
                  if (value) {
                    final confirmar = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Confirmar solicitud"),
                        content: const Text("El tiempo de respuesta puede ser variable dependiendo de la disponibilidad de nuestros expertos en este momento.\n\n¿Deseas continuar y solicitar la validación?"),
                        actions: [
                          TextButton(
                            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                            onPressed: () => Navigator.pop(ctx, false),
                          ),
                          TextButton(
                            child: const Text("Confirmar", style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () => Navigator.pop(ctx, true),
                          ),
                        ],
                      ),
                    );

                    if (confirmar != true) return;
                  }

                  setState(() {
                    _solicitaValidacionExperto = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
            ),

            // 7. Action Buttons (Save or Discard)
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
