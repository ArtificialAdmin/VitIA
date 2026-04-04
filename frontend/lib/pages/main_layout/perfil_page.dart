// lib/pages/main_layout/perfil_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinas_mobile/core/services/user_sesion.dart';
import '../auth/login_page.dart';
import '../../core/api_client.dart';
import 'edit_profile_page.dart';
import 'package:geocoding/geocoding.dart';

class PerfilPage extends StatefulWidget {
  final ApiClient apiClient;

  const PerfilPage({super.key, required this.apiClient});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
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
      final userData = await widget.apiClient.getMe();
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
      await widget.apiClient.logout();
      await UserSession.clearSession();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
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
        // Eliminados Actions (Los 3 puntos)
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // --- Encabezado ---
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
            // Eliminado el icono de Lápiz al lado del nombre (User Request)

            const SizedBox(height: 40),

            // --- Tarjeta: MODIFICAR PERFIL ---
            _buildProfileCard(
              title: "Ajustes del perfil",
              subtitle: "Actualiza y modifica tu perfil",
              onTap: () async {
                // Navegar a editar y esperar resultado
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          EditProfilePage(apiClient: widget.apiClient)),
                );
                // Si devuelve true, recargar datos cabecera
                if (result == true) {
                  _profileUpdated = true;
                  _loadProfileHeader();
                }
              },
            ),

            const SizedBox(height: 20),

            // --- Botón de CERRAR SESIÓN ---
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
