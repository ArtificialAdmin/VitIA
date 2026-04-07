// lib/pages/main_layout/home_page.dart

import 'package:flutter/material.dart';


import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart';

// Importaciones de páginas y servicios
import '../gallery/catalogo_page.dart';
import '../capture/foto_page.dart';
import '../library/foro_page.dart';
import 'inicio_screen.dart';
import 'perfil_page.dart';
import '../../core/api_client.dart';
import '../../core/services/api_config.dart';
import '../../core/services/user_sesion.dart';
import '../tutorial/tutorial_page.dart';
import '../auth/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomepageState();
}

class _HomepageState extends State<HomePage> {
  int currentIndex = 0;

  bool _isAuthenticated = false;
  bool _tutorialSuperado = true;
  bool _isLoadingStatus = true;
  bool _hasShownTutorialSession = false; // Flag para mostrar solo una vez
  String _userName = "Usuario";
  String _userLocation = "";
  double? _lat;
  double? _lon;
  String? _userPhotoUrl; // Nueva variable para la foto
  late ApiClient _apiClient;

  // CAMBIO: Convertimos _screens en un método get para poder acceder a setState y lógica de instancia
  List<Widget> get _screens => [
        InicioScreen(
          userName: _userName,
          location: _userLocation,
          lat: _lat,
          lon: _lon,
          userPhotoUrl: _userPhotoUrl, // Pasamos la foto
          apiClient: _apiClient,
          onProfileTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PerfilPage(apiClient: _apiClient)),
            );
            if (result == true) {
              _checkTutorialStatus();
            }
          },
        ),
        const FotoPage(),
        // CAMBIO: Ahora pasamos el callback al catálogo
        CatalogoPage(
          initialTab: 0,
          onCameraTap: () {
            setState(() {
              currentIndex = 1; // Cambia al tab de cámara (FotoPage)
            });
          },
        ),
        const ForoPage(),
      ];

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(getBaseUrl());
    // Conectamos el manejador de expiración
    _apiClient.onTokenExpired = _handleTokenExpired;
    _checkAuthAndTutorial();
  }

  bool _checkIsAuthenticated() {
    return UserSession.token != null && UserSession.token!.isNotEmpty;
  }

  void _checkAuthAndTutorial() {
    _isAuthenticated = _checkIsAuthenticated();

    if (!_isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      });
    } else {
      _apiClient.setToken(UserSession.token!);
      _checkTutorialStatus();
    }
  }

  Future<void> _checkTutorialStatus() async {
    if (!mounted) return;
    setState(() => _isLoadingStatus = true);

    try {
      // Optimizamos: Una sola llamada para Tutorial y Perfil
      final userData = await _apiClient.getMe();
      final bool tutorialSuperado = userData['tutorial_superado'] as bool? ?? false;

      if (mounted) {
        setState(() {
          _userName = userData['nombre'] ?? "Usuario";
          _lat = userData['latitud'] != null
              ? (userData['latitud'] as num).toDouble()
              : null;
          _lon = userData['longitud'] != null
              ? (userData['longitud'] as num).toDouble()
              : null;
          _userPhotoUrl = userData['path_foto_perfil'];
          _tutorialSuperado = tutorialSuperado || _hasShownTutorialSession;
        });

        if (_lat != null && _lon != null) {
          _updateAddressDisplay(_lat!, _lon!);
        } else {
          setState(() => _userLocation = "");
        }
      }

      if (!tutorialSuperado && !_hasShownTutorialSession) {
        _hasShownTutorialSession = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showTutorialPage(isInitial: true);
        });
      }
    } on DioException catch (e) {
      debugPrint("Error al cargar datos iniciales: ${e.message}");
      // Si es 401, el interceptor ya disparará _handleTokenExpired
      if (e.response?.statusCode != 401) {
        if (mounted) setState(() => _tutorialSuperado = true);
      }
    } catch (e) {
      debugPrint("Error general al cargar datos iniciales: $e");
      if (mounted) setState(() => _tutorialSuperado = true);
    } finally {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  Future<void> _updateAddressDisplay(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = "${place.locality}, ${place.administrativeArea}";
        if (mounted) {
          setState(() => _userLocation = address);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _userLocation = "Ubicación detectada");
      }
    }
  }

  void _handleTokenExpired() {
    // Evitamos mostrar múltiples diálogos si llegan varios 401 seguidos
    if (!mounted) return;

    // Usamos addPostFrameCallback para evitar conflictos si esto ocurre durante initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false, // Obligar a pulsar el botón
        builder: (context) => AlertDialog(
          title: const Text("Sesión Caducada"),
          content: const Text(
              "Tu sesión ha expirado por seguridad. Por favor, inicia sesión de nuevo."),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Cerrar diálogo
                await UserSession.clearSession(); // Limpiar datos locales
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
              child: const Text("Aceptar",
                  style: TextStyle(color: Color(0xFF142018))),
            ),
          ],
        ),
      );
    });
  }

  void _showTutorialPage({required bool isInitial}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => TutorialPage(
          apiClient: _apiClient,
          isCompulsory: isInitial,
          onFinished: () {
            Navigator.of(context).pop();
            if (mounted) {
              setState(() => _tutorialSuperado = true);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStatus || !_tutorialSuperado) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFF8B9E3A))),
      );
    }

    const Color darkBarColor = Color(0xFF142018); // Negro VitIA
    const Color activeTabColor =
        Color.fromARGB(255, 255, 255, 255); // Magenta/Vino
    return Scaffold(
      extendBody: true,
      body: _screens[currentIndex],
      // BARRA DE NAVEGACIÓN FLOTANTE (OPERATIVA)
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
        child: Container(
          decoration: BoxDecoration(
            color: darkBarColor,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: darkBarColor.withOpacity(0.5),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: GNav(
              gap: 8,
              color: Colors.white70,
              activeColor: Colors.white,
              tabBackgroundColor: activeTabColor,
              tabBorderRadius: 100,
              tabShadow: const [],
              padding: const EdgeInsets.all(12),
              selectedIndex: currentIndex,
              onTabChange: (index) {
                setState(() => currentIndex = index);
              },
              tabs: [
                GButton(
                  icon: Icons.home,
                  iconSize: 0,
                  leading: Image.asset('assets/navbar/icon_nav_home.png',
                      width: 30,
                      color: currentIndex == 0 ? Colors.black : Colors.white),
                ),
                GButton(
                  icon: Icons.camera_alt_outlined,
                  iconSize: 0,
                  leading: Image.asset('assets/navbar/icon_nav_camera.png',
                      width: 30,
                      color: currentIndex == 1 ? Colors.black : Colors.white),
                ),
                GButton(
                  icon: Icons.menu_book,
                  iconSize: 0,
                  leading: Image.asset('assets/navbar/icon_nav_catalogo.png',
                      width: 30,
                      color: currentIndex == 2 ? Colors.black : Colors.white),
                ),
                GButton(
                  icon: Icons.forum,
                  iconSize: 0,
                  leading: Image.asset('assets/navbar/icon_nav_foro.png',
                      width: 30,
                      color: currentIndex == 3 ? Colors.black : Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
