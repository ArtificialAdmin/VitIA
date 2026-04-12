// lib/pages/auth/login_form_page.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/api_config.dart';
import 'package:vinas_mobile/features/auth/services/auth_session_service.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/features/home/ui/home_principal_page.dart';
import 'auth_register_page.dart';

class LoginFormPage extends ConsumerStatefulWidget {
  const LoginFormPage({super.key});

  @override
  ConsumerState<LoginFormPage> createState() => _LoginFormPageState();
}

class _LoginFormPageState extends ConsumerState<LoginFormPage> {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  final Color _authMainColor = const Color(0xFFA01B4C);
  final Color _authFieldColor = const Color(0xFFFFFFEB);

  Future<void> login() async {
    final baseUrl = getBaseUrl();
    final url = Uri.parse("$baseUrl/auth/token");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "username": emailCtrl.text.trim(),
          "password": passwordCtrl.text.trim(),
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data["access_token"];

        // 1. Persistencia tradicional (disco)
        await AuthSessionService.setToken(token);
        
        // 2. Notificación reactiva (Riverpod) - Token
        ref.read(sessionTokenProvider.notifier).state = token;

        // 3. Obtener el perfil completo (incluyendo id_usuario) para reactividad
        try {
          final userInfo = await ref.read(apiProvider).getMe();
          final userId = userInfo['id_usuario'];
          if (userId != null) {
            await AuthSessionService.setUserId(userId);
            ref.read(userIdProvider.notifier).state = userId;
          }
        } catch (e) {
          print("Error al recuperar perfil tras login: $e");
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Inicio de sesión exitoso")),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePrincipalPage()),
          (route) => false,
        );
      } else {
        String message = "Credenciales incorrectas o error de servidor.";
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            message = errorData["detail"] ?? message;
          } catch (_) {}
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Error de conexión al servidor: ${e.runtimeType}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _authMainColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Iniciar sesión",
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Lora'),
                ),
                const SizedBox(height: 50),
                TextField(
                  controller: emailCtrl,
                  style: TextStyle(color: _authMainColor, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "Correo electrónico",
                    prefixIcon:
                        Icon(Icons.email_outlined, color: _authMainColor),
                    filled: true,
                    fillColor: _authFieldColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide:
                            BorderSide(color: _authMainColor, width: 2)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide:
                            BorderSide(color: _authMainColor, width: 2)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide:
                            BorderSide(color: _authFieldColor, width: 2)),
                    labelStyle: TextStyle(color: _authMainColor),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  style: TextStyle(color: _authMainColor, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "Contraseña",
                    prefixIcon: Icon(Icons.lock_outline, color: _authMainColor),
                    filled: true,
                    fillColor: _authFieldColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide:
                            BorderSide(color: _authMainColor, width: 2)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide:
                            BorderSide(color: _authMainColor, width: 2)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide:
                            BorderSide(color: _authFieldColor, width: 2)),
                    labelStyle: TextStyle(color: _authMainColor),
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _authFieldColor,
                      foregroundColor: _authMainColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                    ),
                    child: const Text("Continuar",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 30),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthRegisterPage()),
                    );
                  },
                  child: const Text(
                    "No tienes cuenta? Regístrate",
                    style: TextStyle(
                        color: Colors.white,
                        decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
