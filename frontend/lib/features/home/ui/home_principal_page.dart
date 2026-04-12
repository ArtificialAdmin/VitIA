import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dio/dio.dart';

// Importaciones de páginas y servicios
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/features/biblioteca/ui/biblioteca_catalogo_page.dart';
import 'package:vinas_mobile/features/coleccion/ui/coleccion_captura_page.dart';
import 'package:vinas_mobile/features/foro/ui/foro_principal_page.dart';
import 'home_inicio_seccion.dart';
import 'package:vinas_mobile/features/perfil/ui/perfil_principal_page.dart';
import 'package:vinas_mobile/features/auth/services/auth_session_service.dart';
import 'package:vinas_mobile/features/tutorial/ui/tutorial_principal_page.dart';
import 'package:vinas_mobile/features/auth/ui/auth_login_page.dart';

class HomePrincipalPage extends ConsumerStatefulWidget {
  const HomePrincipalPage({super.key});

  @override
  ConsumerState<HomePrincipalPage> createState() => _HomePrincipalPageState();
}

class _HomePrincipalPageState extends ConsumerState<HomePrincipalPage> {
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

  // CAMBIO: Convertimos _screens en un método get para poder acceder a setState y lógica de instancia
  List<Widget> get _screens => [
        HomeInicioSeccion(
          userName: _userName,
          location: _userLocation,
          lat: _lat,
          lon: _lon,
          userPhotoUrl: _userPhotoUrl, // Pasamos la foto
          onProfileTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PerfilPrincipalPage()),
            );
            if (result == true) {
              _checkTutorialStatus();
            }
          },
        ),
        const ColeccionCapturaPage(),
        // CAMBIO: Ahora pasamos el callback al catálogo
        BibliotecaCatalogoPage(
          initialTab: 0,
          onCameraTap: () {
            setState(() {
              currentIndex = 1; // Cambia al tab de cámara (ColeccionCapturaPage)
            });
          },
        ),
        const ForoPrincipalPage(),
      ];

  @override
  void initState() {
    super.initState();
    _checkAuthAndTutorial();
  }

  bool _checkIsAuthenticated() {
    return AuthSessionService.token != null && AuthSessionService.token!.isNotEmpty;
  }

  void _checkAuthAndTutorial() {
    _isAuthenticated = _checkIsAuthenticated();

    if (!_isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthLoginPage()),
          (route) => false,
        );
      });
    } else {
      _checkTutorialStatus();
    }
  }

  Future<void> _checkTutorialStatus() async {
    if (!mounted) return;
    setState(() => _isLoadingStatus = true);

    try {
      // Optimizamos: Una sola llamada para Tutorial y Perfil
      final userData = await ref.read(apiProvider).getMe();
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

  void _showTutorialPage({required bool isInitial}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => TutorialPage(
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
    // Escuchamos cambios en la sesión para redirigir si el token se pierde (ej: 401 interceptor)
    ref.listen(sessionTokenProvider, (previous, next) {
      if (next == null && _isAuthenticated) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthLoginPage()),
          (route) => false,
        );
      }
    });

    const Color darkBarColor = Color(0xFF142018); // Negro VitIA
    const Color activeTabColor = Colors.white;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: _screens[currentIndex],
      ),
      // BARRA DE NAVEGACIÓN FLOTANTE (ESTILO ORIGINAL RESTAURADO)
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
              activeColor: Colors.black, // Color del icono cuando está activo
              tabBackgroundColor: activeTabColor, // Fondo blanco sólido al presionar
              tabBorderRadius: 100,
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
