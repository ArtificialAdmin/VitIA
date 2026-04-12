import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:vinas_mobile/core/api_config.dart';
import 'package:vinas_mobile/features/home/ui/home_principal_page.dart';
import 'auth_login_page.dart';
import 'package:vinas_mobile/features/auth/services/auth_session_service.dart';
import 'package:geolocator/geolocator.dart';

class AuthRegisterPage extends StatefulWidget {
  const AuthRegisterPage({super.key});

  @override
  State<AuthRegisterPage> createState() => _AuthRegisterPageState();
}

class _AuthRegisterPageState extends State<AuthRegisterPage> {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final TextEditingController nombreCtrl = TextEditingController();
  final TextEditingController apellidosCtrl = TextEditingController();
  
  bool _shareLocation = false;
  bool _isLocating = false;

  final Color _authMainColor = const Color(0xFFA01B4C);
  final Color _authFieldColor = const Color(0xFFFFFFEB);

  XFile? _pickedFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _pickedFile = picked;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> register() async {
    final baseUrl = getBaseUrl();
    final registerUrl = Uri.parse("$baseUrl/auth/register");

    try {
      var request = http.MultipartRequest('POST', registerUrl);
      request.fields['email'] = emailCtrl.text.trim();
      request.fields['password'] = passCtrl.text.trim();
      request.fields['nombre'] = nombreCtrl.text.trim();
      request.fields['apellidos'] = apellidosCtrl.text.trim();

      if (_shareLocation) {
        setState(() => _isLocating = true);
        try {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          
          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium
            );
            request.fields['latitud'] = position.latitude.toString();
            request.fields['longitud'] = position.longitude.toString();
          }
        } catch (e) {
          debugPrint("Error al capturar ubicación en registro: $e");
        } finally {
          setState(() => _isLocating = false);
        }
      }

      if (_pickedFile != null) {
        final bytes = await _pickedFile!.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'foto',
          bytes,
          filename: _pickedFile!.name,
        ));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        final loginUrl = Uri.parse("$baseUrl/auth/token");
        final loginResponse = await http.post(
          loginUrl,
          headers: {"Content-Type": "application/x-www-form-urlencoded"},
          body: {
            "username": emailCtrl.text.trim(),
            "password": passCtrl.text.trim(),
          },
        );

        if (!mounted) return;

        if (loginResponse.statusCode == 200) {
          final tokenData = jsonDecode(loginResponse.body);
          final token = tokenData["access_token"];
          await AuthSessionService.setToken(token);
          
          final userData = tokenData["user"];
          if (userData != null && userData["id"] != null) {
            await AuthSessionService.setUserId(userData["id"]);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Usuario creado e iniciado sesión correctamente")),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePrincipalPage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Usuario creado, pero error al iniciar sesión automáticamente. Por favor, inicie sesión manualmente.")),
          );
          Navigator.pop(context);
        }
      } else {
        String message = "Error al crear la cuenta.";
        if (response.body.isNotEmpty) {
          try {
            final errorData = jsonDecode(response.body);
            message = errorData["detail"] ?? message;
          } catch (_) {}
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error de conexión al servidor: ${e.runtimeType}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (_pickedFile != null) {
      if (kIsWeb) {
        imageProvider = NetworkImage(_pickedFile!.path);
      } else {
        imageProvider = FileImage(File(_pickedFile!.path));
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
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
                  "Registrarse",
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Lora'),
                ),
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: _authFieldColor,
                        backgroundImage: imageProvider,
                        child: _pickedFile == null
                            ? Icon(Icons.person, size: 50, color: _authMainColor)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.camera_alt, size: 18, color: _authMainColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: nombreCtrl,
                  style: TextStyle(color: _authMainColor, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "Nombre",
                    prefixIcon: Icon(Icons.person_outline, color: _authMainColor),
                    filled: true,
                    fillColor: _authFieldColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: _authMainColor, width: 2)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: _authMainColor, width: 2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: _authFieldColor, width: 2)),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: apellidosCtrl,
                  style: TextStyle(color: _authMainColor, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "Apellidos",
                    prefixIcon: Icon(Icons.person_outline, color: _authMainColor),
                    filled: true,
                    fillColor: _authFieldColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: _authMainColor, width: 2)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: _authMainColor, width: 2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: _authFieldColor, width: 2)),
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(color: _authFieldColor, borderRadius: BorderRadius.circular(25)),
                  child: SwitchListTile(
                    title: Text("Compartir ubicación para el clima", style: TextStyle(color: _authMainColor, fontSize: 14, fontWeight: FontWeight.w500)),
                    value: _shareLocation,
                    activeColor: _authMainColor,
                    onChanged: (bool value) => setState(() => _shareLocation = value),
                    secondary: Icon(Icons.location_on_outlined, color: _authMainColor),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: emailCtrl,
                  style: TextStyle(color: _authMainColor, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "Correo electrónico",
                    prefixIcon: Icon(Icons.email_outlined, color: _authMainColor),
                    filled: true,
                    fillColor: _authFieldColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: _authMainColor, width: 2)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: _authMainColor, width: 2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: _authFieldColor, width: 2)),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: passCtrl,
                  style: TextStyle(color: _authMainColor, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "Contraseña",
                    prefixIcon: Icon(Icons.lock_outline, color: _authMainColor),
                    filled: true,
                    fillColor: _authFieldColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: _authMainColor, width: 2)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: _authMainColor, width: 2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: _authFieldColor, width: 2)),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: register,
                    style: ElevatedButton.styleFrom(backgroundColor: _authFieldColor, foregroundColor: _authMainColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                    child: _isLocating 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Continuar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 30),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(" Ya tienes una cuenta? Inicia sesión", style: TextStyle(color: Colors.white, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
