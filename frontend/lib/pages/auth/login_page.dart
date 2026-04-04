// lib/pages/auth/login_page.dart

import 'package:flutter/material.dart';
import '../../widgets/vitia_logo.dart';
import 'package:vinas_mobile/core/services/user_sesion.dart';
import '../main_layout/home_page.dart';
import 'register_page.dart';
import 'login_form_page.dart'; // <<< Nuevo archivo de formulario

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Color principal (Vino VitIA: #A01B4C)
  final Color _authMainColor = const Color(0xFFA01B4C);
  // Blanco cálido VitIA: #FFFFEFB
  final Color _authFieldColor = const Color(0xFFFFFFEB);

  // Dialogo para cambiar la IP
  void _showServerConfigDialog(BuildContext context) {
    // Controlador con la URL actual o la por defecto
    final TextEditingController urlCtrl = TextEditingController(
      text: UserSession.baseUrl ?? 'http://127.0.0.1:8000',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Selecciona Servidor"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Configura tu Servidor Local:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: "IP Local",
                  hintText: "http://192.168.x.x:8000",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                child: const Text("Guardar IP Local"),
                onPressed: () async {
                  final newUrl = urlCtrl.text.trim();
                  if (newUrl.isNotEmpty) {
                    await UserSession.setBaseUrl(newUrl);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Conectado a IP Local")));
                  }
                  Navigator.pop(context);
                  setState(() {});
                },
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _authMainColor, // Fondo color Vino VitIA
      // Botón flotante discreto para configuración (DESHABILITADO: Comenta si necesitas cambiar IP manual)
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: Colors.white.withOpacity(0.2),
        elevation: 0,
        onPressed: () => _showServerConfigDialog(context),
        child: const Icon(Icons.settings, color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Título "Bienvenido a VitIA"
                const Text(
                  "Bienvenid@ a",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Lora'),
                ),
                const VitIALogo(fontSize: 64, color: Colors.white),
                const SizedBox(height: 30),

                // --- Ilustración de Inicio ---
                Image.asset(
                  'assets/inicio/ilustracion_inicio.png', // Ruta ajustada
                  height: 150,
                  width: 150,
                  color:
                      _authFieldColor, // Colorear la ilustración de blanco cálido
                ),
                const SizedBox(height: 50),

                // 🚨 BOTÓN 1: Iniciar Sesión (Lleva al formulario de credenciales)
                Container(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const LoginFormPage()), // <<< NAVEGA AL FORMULARIO
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: _authFieldColor,
                      side: BorderSide(color: _authFieldColor, width: 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                    ),
                    child: const Text("Iniciar sesión",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 15),

                // 🚨 BOTÓN 2: Registrarse (Lleva al formulario de registro)
                Container(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _authFieldColor,
                      foregroundColor: _authMainColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                    ),
                    child: const Text("Registrarse",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 30),

                // Indicador de estado
                Text(
                  "Conectado a: ${UserSession.baseUrl?.isNotEmpty == true ? UserSession.baseUrl : 'Localhost (Default)'}",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
      // <<< BARRA DE NAVEGACIÓN SIMULADA ELIMINADA >>>
    );
  }
}
