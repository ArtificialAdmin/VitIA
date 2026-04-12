import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'dart:io';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidosController = TextEditingController();
  final TextEditingController _ubicacionDisplayController = TextEditingController();
  
  // Coordenadas
  double? _lat;
  double? _lon;
  bool _shareLocation = false;
  bool _isLocating = false;

  // Imagen
  XFile? _imageFile; // Cambiado a XFile para compatibilidad Web
  String? _currentPhotoUrl;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;

  // Valores iniciales para detectar cambios
  String _initialNombre = "";
  String _initialApellidos = "";
  double? _initialLat;
  double? _initialLon;

  @override
  void initState() {
    super.initState();
    // Escuchar cambios para habilitar/deshabilitar el botón de guardar
    _nombreController.addListener(_rebuild);
    _apellidosController.addListener(_rebuild);
    _loadUserData();
  }

  void _rebuild() => setState(() {});

  Future<void> _loadUserData() async {
    try {
      final userData = await ref.read(apiProvider).getMe();
      if (mounted) {
        setState(() {
          _nombreController.text = userData['nombre'] ?? '';
          _apellidosController.text = userData['apellidos'] ?? '';
          _lat = userData['latitud'] != null ? (userData['latitud'] as num).toDouble() : null;
          _lon = userData['longitud'] != null ? (userData['longitud'] as num).toDouble() : null;
          _currentPhotoUrl = userData['path_foto_perfil'];
          
          // Guardar iniciales
          _initialNombre = _nombreController.text;
          _initialApellidos = _apellidosController.text;
          _initialLat = _lat;
          _initialLon = _lon;
          
          _isLoading = false;
        });

        // Si hay coordenadas, obtener el nombre del lugar para mostrarlo
        if (_lat != null && _lon != null) {
          _shareLocation = true;
          _updateAddressDisplay(_lat!, _lon!);
        } else {
          _shareLocation = false;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargar perfil: $e')),
        );
      }
    }
  }

  Future<void> _updateAddressDisplay(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = "${place.locality}, ${place.administrativeArea}, ${place.country}";
        _ubicacionDisplayController.text = address;
      } else {
        _ubicacionDisplayController.text = "Ubicación activa";
      }
    } catch (e) {
      _ubicacionDisplayController.text = "Ubicación activa";
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Permiso de ubicación denegado';
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw 'Permisos denegados permanentemente. Por favor, actívalos en ajustes.';
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      if (mounted) {
        setState(() {
          _lat = position.latitude;
          _lon = position.longitude;
        });
      }

      await _updateAddressDisplay(_lat!, _lon!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación obtenida correctamente')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al geolocalizar: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile; // Guardamos XFile directamente
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // 1. Subir foto si hay una nueva seleccionada
      if (_imageFile != null) {
        // _imageFile ya es XFile
        await ref.read(apiProvider).uploadAvatar(_imageFile!);
      }

      // 2. Actualizar datos de texto
      final Map<String, dynamic> updates = {
        "nombre": _nombreController.text.trim(),
        "apellidos": _apellidosController.text.trim(),
        "latitud": _lat,
        "longitud": _lon,
      };

      await ref.read(apiProvider).updateProfile(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );
        Navigator.pop(context, true); // Devuelve true para indicar éxito
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool get _hasChanges {
    final bool nombreChanged = _nombreController.text.trim() != _initialNombre;
    final bool apellidosChanged = _apellidosController.text.trim() != _initialApellidos;
    final bool latChanged = _lat != _initialLat;
    final bool lonChanged = _lon != _initialLon;
    final bool imageChanged = _imageFile != null;
    
    return nombreChanged || apellidosChanged || latChanged || lonChanged || imageChanged;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _ubicacionDisplayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (_imageFile != null) {
      if (kIsWeb) {
        // En Web, path es un blob URL, usamos NetworkImage
        imageProvider = NetworkImage(_imageFile!.path);
      } else {
        // En Móvil, path es ruta de archivo, usamos FileImage
        imageProvider = FileImage(File(_imageFile!.path));
      }
    } else if (_currentPhotoUrl != null) {
      imageProvider = NetworkImage(_currentPhotoUrl!);
    } else {
      imageProvider = null;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Ajustes del perfil",
            style: GoogleFonts.lora(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SELECCION DE FOTO ---
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFFF5F5F5),
                              backgroundImage: imageProvider,
                              child: imageProvider == null
                                  ? const Icon(Icons.person, size: 50)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF142018),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildTextField(
                      controller: _nombreController,
                      label: "Nombre",
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _apellidosController,
                      label: "Apellidos",
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 20),
                    // INTERRUPTOR DE UBICACIÓN AUTOMÁTICA
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCFBF6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            title: const Text(
                              "Compartir ubicación para el clima",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF142018),
                              ),
                            ),
                            subtitle: const Text(
                              "Captura tu posición actual automáticamente",
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _shareLocation,
                            activeColor: const Color(0xFF142018),
                            secondary: const Icon(Icons.location_on_outlined, color: Color(0xFF142018)),
                            onChanged: (bool value) {
                              setState(() {
                                _shareLocation = value;
                              });
                              if (value) {
                                _getCurrentLocation();
                              } else {
                                setState(() {
                                  _lat = null;
                                  _lon = null;
                                  _ubicacionDisplayController.clear();
                                });
                              }
                            },
                          ),
                          if (_shareLocation && _ubicacionDisplayController.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 70, bottom: 12, right: 16),
                              child: Text(
                                _isLocating ? "Localizando..." : _ubicacionDisplayController.text,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (_isSaving || _isLocating || !_hasChanges) ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF142018),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("Guardar Cambios",
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLocating || _isSaving)
              Container(
                color: Colors.white.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF142018),
                  ),
                ),
              ),
          ],
        ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool isOptional = false,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: const Color(0xFFFCFBF6),
      ),
      validator: (value) {
        if (!isOptional && (value == null || value.isEmpty)) {
          return 'Campo obligatorio';
        }
        return null;
      },
    );
  }
}
