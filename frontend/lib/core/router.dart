import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vinas_mobile/features/auth/ui/auth_login_page.dart';
import 'package:vinas_mobile/features/home/ui/home_principal_page.dart';
import 'package:vinas_mobile/features/foro/ui/foro_principal_page.dart';
import 'package:vinas_mobile/features/coleccion/ui/coleccion_captura_page.dart';
import 'package:vinas_mobile/features/biblioteca/ui/biblioteca_catalogo_page.dart';
import 'package:vinas_mobile/features/mapa/ui/mapa_principal_page.dart';
import 'package:vinas_mobile/features/perfil/ui/perfil_principal_page.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePrincipalPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const AuthLoginPage(),
    ),
    GoRoute(
      path: '/foro',
      builder: (context, state) => const ForoPrincipalPage(),
    ),
    GoRoute(
      path: '/catalogo',
      builder: (context, state) => const BibliotecaCatalogoPage(),
    ),
    GoRoute(
      path: '/captura',
      builder: (context, state) => const ColeccionCapturaPage(),
    ),
    GoRoute(
      path: '/mapa',
      builder: (context, state) => const MapaPrincipalPage(),
    ),
    GoRoute(
      path: '/perfil',
      builder: (context, state) => const PerfilPrincipalPage(),
    ),
  ],
);
