import 'package:flutter/material.dart';
import 'pages/auth/login_page.dart';
import 'pages/main_layout/home_page.dart';
import 'core/services/user_sesion.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargamos la sesión antes de iniciar la UI
  final bool hasSession = await UserSession.loadSession();

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
      theme: ThemeData(
        textTheme: GoogleFonts.ibmPlexSansTextTheme(),
        useMaterial3: true,
      ),
      // Si hay sesión, vamos directo a HomePage. Si no, a login.
      home: isLoggedIn ? const HomePage() : const LoginPage(),
    );
  }
}
