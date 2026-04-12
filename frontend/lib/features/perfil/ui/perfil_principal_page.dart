// lib/pages/main_layout/perfil_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinas_mobile/features/auth/services/auth_session_service.dart';
import 'package:vinas_mobile/features/auth/ui/auth_login_page.dart';
import 'edit_profile_page.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/providers.dart';

class PerfilPrincipalPage extends ConsumerStatefulWidget {
  const PerfilPrincipalPage({super.key});

  @override
  ConsumerState<PerfilPrincipalPage> createState() => _PerfilPrincipalPageState();
}

class _PerfilPrincipalPageState extends ConsumerState<PerfilPrincipalPage> {
  String _nombreUser = "";
  String _ubicacionUser = "";
  String? _userPhotoUrl; // Variable para foto
  bool _profileUpdated = false;
  bool _isLoading = true; // <--- Nuevo estado de carga

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
          
          double? lat = userData['latitud'] != null ? (userData['latitud'] as num).toDouble() : null;
          double? lon = userData['longitud'] != null ? (userData['longitud'] as num).toDouble() : null;
          
          if (lat != null && lon != null) {
            _updateAddressDisplay(lat, lon);
          } else {
            _ubicacionUser = "Sin ubicación";
          }
        });
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

  Future<void> _updateAddressDisplay(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = "${place.locality}, ${place.administrativeArea}";
        if (mounted) {
          setState(() => _ubicacionUser = address);
        }
      } else {
        if (mounted) {
          setState(() => _ubicacionUser = "$lat, $lon");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _ubicacionUser = "Ubicación detectada");
      }
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
      IconData? icon,
      Color? textColor}) {
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
                    Text(
                      title,
                      style: GoogleFonts.ibmPlexSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor ?? Colors.black87),
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
              const Center(child: CircularProgressIndicator())
            else ...[
              CircleAvatar(
                radius: 50,
                backgroundImage:
                    _userPhotoUrl != null ? NetworkImage(_userPhotoUrl!) : null,
                child: _userPhotoUrl == null
                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                    : null,
                backgroundColor: Colors.grey.shade200,
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
