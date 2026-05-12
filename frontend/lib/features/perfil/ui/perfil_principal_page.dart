// lib/pages/main_layout/perfil_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinas_mobile/shared/components/loading_indicator.dart';
import 'package:vinas_mobile/features/auth/services/auth_session_service.dart';
import 'package:vinas_mobile/features/auth/ui/auth_login_page.dart';
import 'edit_profile_page.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/features/experto/ui/validaciones_page.dart';
import 'package:vinas_mobile/features/experto/ui/anotacion_dataset_page.dart';

class PerfilPrincipalPage extends ConsumerStatefulWidget {
  const PerfilPrincipalPage({super.key});

  @override
  ConsumerState<PerfilPrincipalPage> createState() => _PerfilPrincipalPageState();
}

class _PerfilPrincipalPageState extends ConsumerState<PerfilPrincipalPage> {
  String _nombreUser = "";
  String? _userPhotoUrl; // Variable para foto
  String _rolUser = "usuario"; // Nuevo estado para el rol
  bool _profileUpdated = false;
  bool _isLoading = true; // <--- Nuevo estado de carga
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileHeader();
  }

  Future<void> _loadProfileHeader() async {
    try {
      final userData = await ref.read(apiProvider).getMe();
      if (mounted) {
        setState(() {
          _nombreUser = "${userData['nombre']} ${userData['apellidos']}";
          _userPhotoUrl = userData['path_foto_perfil'];
          _rolUser = userData['rol'] ?? "usuario";
        });
        
        if (_rolUser == 'experto' || _rolUser == 'admin') {
          _fetchPendingCount();
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchPendingCount() async {
    try {
      final count = await ref.read(apiProvider).getValidacionesPendientesCount();
      if (mounted) {
        setState(() {
          _pendingCount = count;
        });
      }
    } catch (e) {
      debugPrint("Error fetching pending count: $e");
    }
  }


  void logout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que quieres cerrar la sesión?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.black54)),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Cerrar Sesión',
                  style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await ref.read(apiProvider).logout();
      await AuthSessionService.clearSession();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthLoginPage()),
        (route) => false,
      );
    }
  }

  Widget _buildProfileCard(
      {required String title,
      required String subtitle,
      required Function() onTap,
      Color? textColor,
      int badgeCount = 0}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black26),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.ibmPlexSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor ?? Colors.black87),
                        ),
                        if (badgeCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              badgeCount > 99 ? "99+" : badgeCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ]
                      ],
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          subtitle,
                          style: GoogleFonts.ibmPlexSans(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_profileUpdated),
        ),
        title: Text("Perfil",
            style: GoogleFonts.lora(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (_isLoading)
              const LoadingIndicator()
            else ...[
              CircleAvatar(
                radius: 50,
                backgroundImage:
                    _userPhotoUrl != null ? NetworkImage(_userPhotoUrl!) : null,
                backgroundColor: Colors.grey.shade200,
                child: _userPhotoUrl == null
                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                    : null,
              ),
              const SizedBox(height: 15),
              Text(
                _nombreUser.isEmpty ? "Usuario" : _nombreUser,
                style: GoogleFonts.lora(fontSize: 28),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 40),

            _buildProfileCard(
              title: "Ajustes del perfil",
              subtitle: "Actualiza y modifica tu perfil",
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const EditProfilePage()),
                );
                if (result == true) {
                  _profileUpdated = true;
                  _loadProfileHeader();
                }
              },
            ),

            if (_rolUser == 'experto' || _rolUser == 'admin') ...[
              const SizedBox(height: 16),
              _buildProfileCard(
                title: "Validaciones Pendientes",
                subtitle: "Revisa las imágenes de la IA",
                textColor: const Color(0xFFD4AF37),
                badgeCount: _pendingCount,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ValidacionesPage()),
                  );
                  _fetchPendingCount();
                },
              ),
              const SizedBox(height: 12),
              _buildProfileCard(
                title: "Anotar Dataset Completo",
                subtitle: "Evalúa todas las imágenes del sistema",
                textColor: const Color(0xFF1E2623),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnotacionDatasetPage()),
                  );
                  _fetchPendingCount();
                },
              ),
            ],

            const SizedBox(height: 20),

            GestureDetector(
              onTap: () => logout(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text("Cerrar sesión",
                      style: GoogleFonts.ibmPlexSans(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
