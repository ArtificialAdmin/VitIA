import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import 'dart:ui';
import '../../core/api_client.dart';
import '../../core/services/api_config.dart';
import '../../core/services/user_sesion.dart';

class DetalleColeccionPage extends StatefulWidget {
  final Map<String, dynamic> coleccionItem;
  final Function(bool changesMade)?
      onClose; // Callback para cerrar (y notificar cambios)

  const DetalleColeccionPage(
      {super.key, required this.coleccionItem, this.onClose});

  @override
  State<DetalleColeccionPage> createState() => _DetalleColeccionPageState();
}

class _DetalleColeccionPageState extends State<DetalleColeccionPage> {
  late Map<String, dynamic> _itemActual;
  late ApiClient _apiClient;

  bool _isUpdating = false;
  late TextEditingController _notasController;
  bool _esPublica = true; // <--- NUEVO ESTADO
  LatLng? _ubicacionActual;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _itemActual = Map.from(widget.coleccionItem);
    _notasController = TextEditingController(text: _itemActual['descripcion']);

    if (_itemActual['latitud'] != null && _itemActual['longitud'] != null) {
      _ubicacionActual = LatLng(
        (_itemActual['latitud'] as num).toDouble(),
        (_itemActual['longitud'] as num).toDouble(),
      );
    }
    // Robust boolean interpretation for private/public (Defaulting to TRUE if null)
    final val = _itemActual['es_publica'];
    if (val == null) {
      _esPublica = true;
    } else {
      _esPublica = (val == true || val == 1 || val == "true");
    }

    _notasController.addListener(_onNotasChanged);

    _apiClient = ApiClient(getBaseUrl());
    if (UserSession.token != null) {
      _apiClient.setToken(UserSession.token!);
    }
  }

  @override
  void dispose() {
    _notasController.removeListener(_onNotasChanged);
    _notasController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onNotasChanged() {
    setState(() {}); // Forzar rebuild para actualizar estado del botón
  }

  // --- LÓGICA DE DETECCIÓN DE CAMBIOS ---
  bool get _hasChanges {
    // 1. Notas
    final originalNotas = _itemActual['descripcion'] ?? "";
    bool notasChanged = _notasController.text != originalNotas;

    // 2. Privacidad
    final val = _itemActual['es_publica'];
    final bool originalPublica = (val == null) ? true : (val == true || val == 1 || val == "true");
    bool publicaChanged = _esPublica != originalPublica;

    // 3. Ubicación
    double? origLat = (_itemActual['latitud'] as num?)?.toDouble();
    double? origLon = (_itemActual['longitud'] as num?)?.toDouble();

    bool locationChanged = false;
    if (origLat != null && origLon != null) {
      if (_ubicacionActual == null) {
        locationChanged = true;
      } else {
        // Tolerancia pequeña para errores de precisión de punto flotante
        locationChanged =
            ((_ubicacionActual!.latitude - origLat).abs() > 0.000001 ||
                (_ubicacionActual!.longitude - origLon).abs() > 0.000001);
      }
    } else if (_ubicacionActual != null) {
      locationChanged = true;
    }

    return notasChanged || publicaChanged || locationChanged;
  }

  // --- GUARDAR CAMBIOS ---
  Future<void> _guardarCambios() async {
    // 1. Mostrar diálogo de confirmación
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Guardar cambios"),
        content:
            const Text("¿Deseas guardar los cambios realizados en esta ficha?"),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            child: const Text("Guardar"),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    // Si cancela o cierra el diálogo, no hacemos nada
    if (confirmar != true) return;

    // 2. Proceder con el guardado
    setState(() => _isUpdating = true);
    try {
      final updates = <String, dynamic>{
        'notas': _notasController.text,
        'es_publica': _esPublica, // <--- INCLUIR EN ACTUALIZACIÓN
      };
      if (_ubicacionActual != null) {
        updates['latitud'] = _ubicacionActual!.latitude;
        updates['longitud'] = _ubicacionActual!.longitude;
      }

      await _apiClient.updateCollectionItem(_itemActual['id'], updates);

      setState(() {
        _itemActual['descripcion'] = _notasController.text;
        _itemActual['es_publica'] = _esPublica; // <--- ACTUALIZAR LOCALMENTE
        _isUpdating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Cambios guardados"),
              backgroundColor: Colors.green),
        );

        if (widget.onClose != null) {
          widget.onClose!(true);
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // --- ELIMINAR ITEM ---
  Future<void> _confirmarEliminacion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar captura"),
        content: const Text(
            "¿Estás seguro de que quieres borrar esta variedad de tu colección? Esta acción no se puede deshacer."),
        actions: [
          TextButton(
              child: const Text("Cancelar"),
              onPressed: () => Navigator.pop(ctx, false)),
          TextButton(
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _apiClient.deleteCollectionItem(_itemActual['id']);
        if (mounted) {
          if (widget.onClose != null) {
            widget.onClose!(true);
          } else {
            Navigator.pop(context, true);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Eliminado correctamente")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Error al eliminar: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check type to determine theme color (default purple)
    final bool isBlanca = (_itemActual['tipo'] == 'Blanca');
    final colorTema = isBlanca ? Colors.lime.shade700 : Colors.purple.shade900;

    // Preparar Fecha
    String fechaTexto = "Fecha desconocida";
    if (_itemActual['fecha_captura'] != null) {
      try {
        final fecha = DateTime.parse(_itemActual['fecha_captura'].toString());
        fechaTexto = "${fecha.day}/${fecha.month}/${fecha.year}";
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. IMAGEN DE FONDO FULL SCREEN (Con Blur y Stack logic)
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: _buildImagen(_itemActual),
            ),
          ),

          // 2. BOTONES FLOTANTES SUPERIORES (Atrás, Guardar, Eliminar)
          // Botón Atrás (Izquierda)
          Positioned(
            top: 40,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  if (widget.onClose != null) {
                    widget.onClose!(false);
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),

          // Botones de Acción (Derecha)
          Positioned(
            top: 40,
            right: 20,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                    tooltip: "Eliminar",
                    onPressed: _isUpdating ? null : _confirmarEliminacion,
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor:
                      colorTema.withOpacity(0.8), // Destacar guardar
                  child: IconButton(
                    icon: _isUpdating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Icon(Icons.save,
                            color: _hasChanges ? Colors.white : Colors.white54),
                    onPressed: (_hasChanges && !_isUpdating)
                        ? _guardarCambios
                        : null,
                    tooltip: _hasChanges
                        ? "Guardar cambios"
                        : "No hay cambios para guardar",
                  ),
                ),
              ],
            ),
          ),

          // 3. SHEET DESLIZABLE (Contenido)
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.25,
            maxChildSize: 0.85, // Limitado para no tapar botones superiores
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

                      // Cabecera: Nombre y Badge
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _itemActual['nombre'] ?? 'Sin Nombre',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                                  (_itemActual['tipo'] ?? 'Personal')
                                      .toUpperCase(),
                                  style: TextStyle(
                                      color: colorTema,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.calendar_today,
                                  size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 6),
                              Text("Capturado: $fechaTexto",
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // SECCIÓN NOTAS / DESCRIPCIÓN
                      _buildSectionTitle("Mis Notas"),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notasController,
                        maxLines: null, // Multiline
                        minLines: 3,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "Escribe tus observaciones aquí...",
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // --- SELECTOR DE PRIVACIDAD EN EDICIÓN ---
                      _buildSectionTitle("Privacidad"),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    _esPublica
                                        ? Icons.public
                                        : Icons.lock_outline,
                                    color: _esPublica
                                        ? colorTema
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _esPublica ? "Pública" : "Privada",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        Text(
                                          _esPublica
                                              ? "Visible para todos en el mapa global"
                                              : "Solo visible para ti",
                                          style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _esPublica,
                              activeColor: colorTema,
                              onChanged: (val) {
                                setState(() => _esPublica = val);
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // SECCIÓN MAPA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle("Ubicación"),
                          if (_ubicacionActual != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                  "${_ubicacionActual!.latitude.toStringAsFixed(4)}, ${_ubicacionActual!.longitude.toStringAsFixed(4)}",
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            children: [
                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _ubicacionActual ??
                                      const LatLng(40.4168, -3.7038),
                                  initialZoom: 13.0,
                                  onTap: (_, point) =>
                                      setState(() => _ubicacionActual = point),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.vinas.app',
                                  ),
                                  if (_ubicacionActual != null)
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: _ubicacionActual!,
                                          width: 40,
                                          height: 40,
                                          child: const Icon(Icons.location_on,
                                              color: Colors.red, size: 40),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              // Tip overlay
                              Positioned(
                                bottom: 10,
                                left: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: const Text(
                                      "Toca el mapa para corregir la posición",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12)),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 100), // Padding inferior extra
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildImagen(Map<String, dynamic> item) {
    final String? path = item['imagen'];
    if (path == null)
      return const Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey, size: 50));

    ImageProvider imgProvider;
    bool isLocal = true;

    // Check if it's a URL or local path
    if (path.startsWith('http')) {
      imgProvider = NetworkImage(path);
      isLocal = false;
    } else if (path.startsWith('assets/')) {
      imgProvider = AssetImage(path);
      isLocal = false;
    } else {
      imgProvider = FileImage(File(path));
    }

    // STACK: Fondo Blurreer + Imagen Contain (Igual que en DetalleVariedadPage)
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Fondo blurreado
        Image(
          image: imgProvider,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(color: Colors.black),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.black.withOpacity(0.3),
          ),
        ),

        // 2. Imagen nítida
        Align(
          alignment: Alignment.topCenter,
          child: Image(
            image: imgProvider,
            fit: BoxFit.contain, // ADJUSTED: Fit contain to see full image
            alignment: Alignment.topCenter,
            errorBuilder: (c, e, s) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
