import 'package:flutter/material.dart';
import 'package:vinas_mobile/features/auth/ui/auth_login_page.dart';
import 'package:vinas_mobile/features/home/ui/home_principal_page.dart';
import 'package:vinas_mobile/features/auth/services/auth_session_service.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargamos la sesión antes de iniciar la UI
  final bool hasSession = await AuthSessionService.loadSession();

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
      // Si hay sesión, vamos directo a HomePrincipalPage. Si no, a login.
      home: isLoggedIn ? const HomePrincipalPage() : const AuthLoginPage(),
    );
  }
}
