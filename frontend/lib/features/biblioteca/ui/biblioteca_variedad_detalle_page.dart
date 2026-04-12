import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinas_mobile/core/api_client.dart';
import 'package:vinas_mobile/core/api_config.dart';
import 'package:vinas_mobile/features/auth/services/auth_session_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/providers.dart';

class BibliotecaVariedadDetallePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> variedad;
  final VoidCallback? onBack; // Nuevo callback para navegación interna
  final bool isFavoritoInicial; // Para saber si ya es favorito al entrar

  const BibliotecaVariedadDetallePage({
    super.key,
    required this.variedad,
    this.onBack,
    this.isFavoritoInicial = false,
  });

  @override
  ConsumerState<BibliotecaVariedadDetallePage> createState() => _BibliotecaVariedadDetallePageState();
}

class _BibliotecaVariedadDetallePageState extends ConsumerState<BibliotecaVariedadDetallePage> {
  late bool _isFavorito;

  @override
  void initState() {
    super.initState();
    _isFavorito = widget.isFavoritoInicial;
  }

  Future<void> _toggleFavorito() async {
    setState(() {
      _isFavorito = !_isFavorito;
    });

    try {
      final id = widget.variedad['id'];
      if (id != null) {
        await ref.read(apiProvider).toggleFavorite(id);
      }
    } catch (e) {
      // Revertir si falla
      setState(() {
        _isFavorito = !_isFavorito;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar favoritos')),
      );
    }
  }

  // Función ROBUSTA para abrir URLs
  Future<void> _launchURL(String urlString) async {
    print("--- INTENTANDO ABRIR LINK ---");
    String urlLimpia = urlString.trim();
    // Si no empieza por http ni https, lo forzamos
    if (!urlLimpia.startsWith(RegExp(r'^https?://', caseSensitive: false))) {
      urlLimpia = 'https://$urlLimpia';
    }

    final Uri url = Uri.parse(urlLimpia);

    try {
      bool lanzado = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!lanzado) {
        // Intento de respaldo
        await launchUrl(url);
      }
    } catch (e) {
      debugPrint('Error al intentar abrir URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBlanca = widget.variedad['tipo'] == 'Blanca';
    final colorTema = isBlanca ? Colors.lime.shade700 : Colors.purple.shade900;

    final dynamic morfologia = widget.variedad['morfologia'];
    final dynamic infoExtra = widget.variedad['info_extra'];

    // --- ESTILOS DE TEXTO ---
    const TextStyle textoGeneralStyle = TextStyle(
      fontSize: 16,
      height: 1.5,
      color: Colors.black87,
    );

    const TextStyle labelExtraStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 16,
      color: Colors.black87,
    );

    const TextStyle contentListStyle = TextStyle(
        color: Colors.black87,
        fontSize: 16, // A little bigger
        height: 1.4);

    return Scaffold(
      backgroundColor: Colors.white, // Fondo base
      body: Stack(
        children: [
          // 1. IMAGEN DE FONDO (Con Blur) + IMAGEN PRINCIPAL (Contain)
          Positioned.fill(
            child: Container(
              color: Colors.black, // Fondo base
              child: _buildImagen(widget.variedad),
            ),
          ),

          // Botón de atrás flotante (para poder salir)
          Positioned(
            top: 40,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),

          // 2. SHEET DESLIZABLE
          DraggableScrollableSheet(
            initialChildSize:
                0.4, // Bajamos para que se vea más imagen al principio (Feedback usuario)
            minChildSize: 0.25, // Se puede bajar hasta ver casi toda la imagen
            maxChildSize: 0.95, // Casi pantalla completa al subir
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26, blurRadius: 20, spreadRadius: 5)
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Barra de "agarrar"
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      // Título y Badges + FAVORITOS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.variedad['nombre'] ?? 'Detalle',
                              style: GoogleFonts.lora(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _toggleFavorito,
                            icon: Icon(
                              _isFavorito
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color:
                                  _isFavorito ? Colors.redAccent : Colors.grey,
                              size: 30,
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorTema.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: colorTema),
                            ),
                            child: Text(
                              (widget.variedad['tipo'] ?? 'Desconocido')
                                  .toUpperCase(),
                              style: TextStyle(
                                  color: colorTema,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                          const Spacer(),
                          // Location removed
                        ],
                      ),
                      const SizedBox(height: 25),

                      // Descripción General
                      _buildSectionTitle("Descripción"),
                      Text(
                        widget.variedad['descripcion'] ??
                            "Sin descripción detallada.",
                        style: textoGeneralStyle,
                      ),
                      const SizedBox(height: 30),

                      // -----------------------------------------------------------
                      // SECCIÓN: MORFOLOGÍA
                      // -----------------------------------------------------------
                      if (morfologia != null)
                        _buildMorfologiaSectionNuevo(
                            morfologia, isBlanca, contentListStyle),

                      // -----------------------------------------------------------
                      // SECCIÓN: DATOS ADICIONALES
                      // -----------------------------------------------------------
                      if (infoExtra != null) ...[
                        Builder(builder: (context) {
                          List<MapEntry<String, String>> datosParaMostrar = [];

                          if (infoExtra is Map) {
                            infoExtra.forEach((k, v) {
                              if (v != null && v.toString().isNotEmpty) {
                                datosParaMostrar
                                    .add(MapEntry(k.toString(), v.toString()));
                              }
                            });
                          } else if (infoExtra is List) {
                            for (var item in infoExtra) {
                              if (item is Map) {
                                item.forEach((k, v) {
                                  String keyLower = k.toString().toLowerCase();
                                  String valLower = v.toString().toLowerCase();
                                  // Filtro Web y Ficha
                                  if (keyLower.contains('ficha') ||
                                      keyLower.contains('web') ||
                                      valLower.contains('ficha') ||
                                      valLower.contains('web') ||
                                      (keyLower == 'titulo' &&
                                          valLower.contains('ficha'))) {
                                    return;
                                  }
                                  if (v != null && v.toString().isNotEmpty) {
                                    datosParaMostrar.add(
                                        MapEntry(k.toString(), v.toString()));
                                  }
                                });
                              } else if (item is String) {
                                if (!item.toLowerCase().contains('ficha')) {
                                  datosParaMostrar.add(MapEntry("Info", item));
                                }
                              }
                            }
                          }

                          if (datosParaMostrar.isEmpty)
                            return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 30),
                              _buildSectionTitle("Datos Adicionales"),
                              ...datosParaMostrar.map((e) {
                                final String rawValue = e.value;
                                final List<String> items = rawValue.split(',');
                                final bool isUrl =
                                    e.key.toLowerCase().contains('url') ||
                                        e.key.toLowerCase() == 'web';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // SOLO mostramos el label si NO es URL
                                      if (!isUrl)
                                        Row(
                                          children: [
                                            Icon(Icons.label_important_outline,
                                                size: 20, color: colorTema),
                                            const SizedBox(width: 8),
                                            Text("${e.key}:",
                                                style: labelExtraStyle),
                                          ],
                                        ),

                                      if (!isUrl) const SizedBox(height: 8),

                                      ..._buildCleanList(
                                          items, contentListStyle),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          );
                        }),
                      ],

                      const SizedBox(height: 100), // Espacio extra al final
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.trim().isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: GoogleFonts.lora(
            fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  // Lista limpia: Capitalizada y CON punto final
  List<Widget> _buildCleanList(List<String> items, TextStyle style) {
    return items.map((item) {
      String texto = item.trim();
      if (texto.isEmpty) return const SizedBox.shrink();

      // Capitalizar y añadir punto final si no lo tiene
      texto = _capitalize(texto);
      if (!texto.endsWith('.')) {
        texto += '.';
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: Linkify(
          onOpen: (link) => _launchURL(link.url),
          text: texto,
          style: style,
          linkStyle: const TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.bold),
          options: const LinkifyOptions(humanize: false),
        ),
      );
    }).toList();
  }

  Widget _buildMorfologiaSectionNuevo(
      dynamic morfologia, bool isBlanca, TextStyle textStyle) {
    final int iconProp = isBlanca ? 3 : 1;

    // Si es null, no mostramos nada
    if (morfologia == null) return const SizedBox.shrink();

    // Si resulta que es una Lista (el nuevo formato posible), por ahora no sabemos su estructura exacta.
    Map<String, dynamic> dataMap = {};
    if (morfologia is Map) {
      dataMap = Map<String, dynamic>.from(morfologia);
    } else if (morfologia is List) {
      // TODO: Adaptar a la estructura de lista cuando la veamos en los logs.
      // Por ahora intentamos convertirlo a Map si es posible o lo dejamos vacío
      // Ejemplo: si fuera [{'key': 'hoja', 'value': ...}]
      print(
          "Warning: Morfologia is a List, not a Map. UI update pending data inspection.");
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("Formato de morfología desconocido (Lista)"),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Morfología"),
        const SizedBox(height: 8),
        if (dataMap.containsKey('hoja') &&
            dataMap['hoja'] != null &&
            dataMap['hoja'].toString().isNotEmpty)
          _buildMorfologiaCard(
            titulo: "Hoja",
            descripcion: dataMap['hoja'],
            iconPath: 'assets/icons/Propiedad$iconProp=hoja.png',
            textStyle: textStyle,
          ),
        if (dataMap.containsKey('racimo') &&
            dataMap['racimo'] != null &&
            dataMap['racimo'].toString().isNotEmpty)
          _buildMorfologiaCard(
            titulo: "Racimo",
            descripcion: dataMap['racimo'],
            iconPath: 'assets/icons/Propiedad$iconProp=racimo.png',
            textStyle: textStyle,
          ),
        if (dataMap.containsKey('uva') &&
            dataMap['uva'] != null &&
            dataMap['uva'].toString().isNotEmpty)
          _buildMorfologiaCard(
            titulo: "Uva",
            descripcion: dataMap['uva'],
            iconPath: 'assets/icons/Propiedad$iconProp=uva.png',
            textStyle: textStyle,
          ),
      ],
    );
  }

  // Reuse logic but remove bullets calling _buildCleanList
  Widget _buildMorfologiaCard({
    required String titulo,
    required dynamic descripcion,
    required String iconPath,
    required TextStyle textStyle,
  }) {
    List<String> items = [];

    if (descripcion is String) {
      items = descripcion.split(',');
    } else if (descripcion is List) {
      items = descripcion.map((e) => e.toString()).toList();
    } else if (descripcion is Map) {
      items = descripcion.values.map((e) => e.toString()).toList();
    } else {
      items = [descripcion.toString()];
    }

    // Filter empty items
    items = items.where((i) => i.trim().isNotEmpty).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade900, width: 1),
      ),
      child: Row(
        // Alineación vertical centrada para que el icono quede centrado respecto al bloque de texto
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ICONO REESCALADO (Más grande y centrado)
          Container(
            width: 76, // Aumentado (antes 64)
            height: 76, // Aumentado (antes 64)
            decoration: BoxDecoration(
              color: Colors.transparent, // Fondo transparente
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(
                6), // Padding reducido para icon más grande
            child: Center(
              child: Image.asset(
                iconPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.image_not_supported,
                      color: Colors.grey);
                },
              ),
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.lora(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 8),

                // Nueva lista limpia
                ..._buildCleanList(items, textStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagen(Map<String, dynamic> variedad) {
    final String? path = variedad['imagen'];
    if (path == null)
      return const Center(
          child:
              Icon(Icons.image_not_supported, color: Colors.white, size: 50));

    ImageProvider imgProvider;
    if (variedad['es_local'] == true) {
      imgProvider = FileImage(File(path));
    } else if (path.startsWith('assets/')) {
      imgProvider = AssetImage(path);
    } else {
      imgProvider = NetworkImage(path);
    }

    // STACK: Fondo Blurreer + Imagen Contain
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Fondo blurreado (ocupa todo y da ambiente)
        Image(
          image: imgProvider,
          fit: BoxFit.cover,
        ),
        // Máscara de blur
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.black.withOpacity(0.3), // Un poco de oscurecimiento
          ),
        ),

        // 2. La imagen real nítida encima, top center
        Align(
          alignment: Alignment.topCenter,
          child: Image(
            image: imgProvider,
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
          ),
        ),
      ],
    );
  }
}
