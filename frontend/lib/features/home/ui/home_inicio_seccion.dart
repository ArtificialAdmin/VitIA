import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinas_mobile/features/home/services/home_weather_service.dart';
import 'package:vinas_mobile/features/home/ui/home_clima_seccion.dart';
import 'package:vinas_mobile/shared/widgets/vitia_header.dart';
import 'package:vinas_mobile/features/tutorial/ui/tutorial_principal_page.dart';
import 'package:vinas_mobile/features/home/ui/home_mapa_preview_widget.dart';

class HomeInicioSeccion extends ConsumerStatefulWidget {
  // Convert to Stateful
  final String userName;
  final String location;
  final double? lat;
  final double? lon;
  final String? userPhotoUrl;
  final VoidCallback? onProfileTap;

  const HomeInicioSeccion({
    super.key,
    required this.userName,
    required this.location,
    this.lat,
    this.lon,
    this.userPhotoUrl,
    this.onProfileTap,
  });

  @override
  ConsumerState<HomeInicioSeccion> createState() => _InicioScreenState();
}

class _InicioScreenState extends ConsumerState<HomeInicioSeccion> {
  final HomeWeatherService _weatherService = HomeWeatherService();
  Map<String, dynamic>? _weatherData;
  String? _weatherError;
  String? _displayLocation;
  bool _isLoadingWeather = true;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  @override
  void didUpdateWidget(HomeInicioSeccion oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la ubicación o coordenadas han cambiado, recargar el tiempo
    if (oldWidget.location != widget.location ||
        oldWidget.lat != widget.lat ||
        oldWidget.lon != widget.lon) {
      _fetchWeather();
    }
  }

  Future<void> _fetchWeather() async {
    // Si no hay coordenadas ni ubicación, no podemos hacer mucho
    if ((widget.lat == null || widget.lon == null) && widget.location.isEmpty) {
      if (mounted) {
        setState(() => _isLoadingWeather = false);
      }
      return;
    }

    // Limpiar ubicación para la API (quitar ", España" si molesta, o dejarlo)
    try {
      final data = await _weatherService.getWeather(
        location: widget.location,
        lat: widget.lat,
        lon: widget.lon,
      );
      if (mounted) {
        setState(() {
          _weatherData = data;
          _isLoadingWeather = false;

          // Actualizar la ubicación mostrada con el nombre de la ciudad de la API
          if (data != null && data['location'] != null) {
            final name = data['location']['name'];
            final region = data['location']['region'];
            _displayLocation = "$name, $region";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weatherError = "No se pudo cargar el tiempo";
          _isLoadingWeather = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: Column(
          children: [
            // 2. HEADER UNIFICADO (FIJO)
            VitiaHeader(
              title: '', // Título vaciado para moverlo al body
              leading: IconButton(
                icon: const Icon(Icons.menu_book_outlined, color: Colors.black),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TutorialPage(
                        isCompulsory: false,
                        onFinished: () => Navigator.pop(context),
                      ),
                    ),
                  );
                },
                tooltip: "Tutorial",
              ),
              userPhotoUrl: widget.userPhotoUrl, // Pasamos la URL
              onProfileTap: widget.onProfileTap,
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),

                    // TEXTO HOLA (Movido aquí)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        '¡Hola, ${widget.userName.split(' ')[0]}!',
                        style: GoogleFonts.lora(
                          fontSize: 32,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF1E2623),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 3. ILUSTRACIÓN VIÑEDO
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        child: Image.asset(
                          'assets/home/ilustracion_home.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 4. UBICACIÓN (Movido aquí, debajo de la ilustración)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      color: Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: Colors.black87),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              (_displayLocation ??
                                      (widget.location.isNotEmpty
                                          ? widget.location
                                          : "Sin ubicación definida")) +
                                  ".",
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // TÍTULO MAPA (Estilo similar al tiempo)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        "Mapa",
                        style: GoogleFonts.lora(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF142018),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 3b. VISTA PREVIA DEL MAPA (Prueba Visual)
                    const HomeMapaPreviewWidget(),

                    const SizedBox(height: 10),

                    // 5. SECCIÓN TIEMPO
                    if (_weatherData != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: HomeClimaSeccion(weatherData: _weatherData),
                      )
                    else if (_weatherError != null)
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(_weatherError!,
                            style: const TextStyle(color: Colors.red)),
                      )
                    else if (!_isLoadingWeather && widget.location.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text("Información del tiempo no disponible."),
                      ),

                    const SizedBox(height: 30),

                    const SizedBox(
                        height:
                            140), // Espacio aumentado para el navbar flotante
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
