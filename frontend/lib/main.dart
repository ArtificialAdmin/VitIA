import 'package:flutter/material.dart';
import 'package:vinas_mobile/features/auth/ui/auth_login_page.dart';
import 'package:vinas_mobile/features/home/ui/home_principal_page.dart';
import 'package:vinas_mobile/features/auth/services/auth_session_service.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vinas_mobile/shared/styles/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Firebase (con salvaguarda para Web/Missing Config)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("----------------------------------------------------------------");
    debugPrint("⚠️ FIREBASE ERROR: La app continuará sin notificaciones push.");
    debugPrint("Detalle: $e");
    debugPrint("----------------------------------------------------------------");
  }

  // Cargamos la sesión antes de iniciar la UI
  bool hasSession = false;
  try {
    hasSession = await AuthSessionService.loadSession();
  } catch (e) {
    debugPrint("Error loading session: $e");
  }

  runApp(
    ProviderScope(
      child: MyApp(isLoggedIn: hasSession),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VitIA',
      theme: AppTheme.themeData,
      // Si hay sesión, vamos directo a HomePrincipalPage. Si no, a login.
      home: isLoggedIn ? const HomePrincipalPage() : const AuthLoginPage(),
    );
  }
}
