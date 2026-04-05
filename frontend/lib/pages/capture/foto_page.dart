import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';
import '../../core/services/api_config.dart';
import '../../core/models/prediction_model.dart';
import '../../core/services/user_sesion.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart'; // Standard date formatting if available, or just use raw strings
import 'package:google_fonts/google_fonts.dart';

class GroupedResult {
  final String variety;
  final double confidence;
  final List<XFile> photos;
  final Set<String> selectedPaths;
  final DateTime date;
  final String location;
  final double? latitude;
  final double? longitude;
  bool isPublic; // <--- NUEVO: Atributo mutable para la privacidad

  GroupedResult(
    this.variety,
    this.confidence,
    this.photos, {
    Set<String>? selected,
    required this.date,
    required this.location,
    this.latitude,
    this.longitude,
    this.isPublic = true, // <--- Valor por defecto
  }) : selectedPaths = selected ?? photos.map((e) => e.path).toSet();
}

class FotoPage extends StatefulWidget {
  const FotoPage({super.key});

  @override
  State<FotoPage> createState() => _FotoPageState();
}

class _FotoPageState extends State<FotoPage> with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  FlashMode _currentFlashMode = FlashMode.off;
  bool _isCameraInitialized = false;
  bool _useSimulatedCamera = false;

  // States: 0 = Capture/Gallery, 1 = Analysis/Loading, 2 = Result
  int _uiState = 0;
  bool _isSaving = false;

  List<XFile> _capturedPhotos = [];

  // Now we store a LIST of groups
  List<GroupedResult> _results = [];

  // Controller for the currently viewed result (if we have multiple varieties, we page them)
  final PageController _resultPageController = PageController();
  int _currentResultIndex = 0;

  final DraggableScrollableController _sheetController = DraggableScrollableController();

  late ApiClient _apiClient;
  final ImagePicker _picker = ImagePicker();

  // Controllers map: Index in _results -> TextEditingController
  final String _fallbackImage =
      'https://images.unsplash.com/photo-1596244956306-a9df17907407?q=80&w=1974&auto=format&fit=crop';

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(getBaseUrl());
    if (UserSession.token != null) {
      _apiClient.setToken(UserSession.token!);
    }
    _initCamera();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _useSimulatedCamera = true);
        return;
      }
      
      // Initialize the selected camera
      await _initCameraWithIndex(_selectedCameraIndex);
      
    } catch (e) {
      debugPrint("Error cámara: $e");
      if (mounted) setState(() => _useSimulatedCamera = true);
    }
  }

  Future<void> _initCameraWithIndex(int index) async {
    final camera = _cameras[index];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      try {
        await _cameraController!.setFlashMode(_currentFlashMode);
      } catch (_) {}
      try {
        await _cameraController!
            .lockCaptureOrientation(DeviceOrientation.portraitUp);
      } catch (_) {}
      
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _resultPageController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _onSwitchCamera() async {
    if (_cameras.length < 2) return;
    
    // Calculate new index
    int newIndex = (_selectedCameraIndex + 1) % _cameras.length;
    
    // Dispose current
    await _cameraController?.dispose();
    setState(() {
      _isCameraInitialized = false;
      _selectedCameraIndex = newIndex;
    });

    // Re-init with new index
    await _initCameraWithIndex(newIndex);
  }

  Future<void> _onToggleFlash() async {
    if (!_isCameraInitialized || _cameraController == null) return;

    FlashMode newMode;
    if (_currentFlashMode == FlashMode.off) {
      newMode = FlashMode.auto;
    } else if (_currentFlashMode == FlashMode.auto) {
      newMode = FlashMode.torch; // Or always
    } else {
      newMode = FlashMode.off;
    }

    try {
      await _cameraController!.setFlashMode(newMode);
      setState(() => _currentFlashMode = newMode);
    } catch (e) {
      debugPrint("Error toggling flash: $e");
    }
  }

  // --- ACTIONS ---

  Future<void> _takePhoto() async {
    if (!_isCameraInitialized && !_useSimulatedCamera) return;
    try {
      XFile photo;
      if (_useSimulatedCamera) {
        photo = XFile('simulated_path');
      } else {
        photo = await _cameraController!.takePicture();
      }

      setState(() {
        _capturedPhotos.add(photo);
      });
      // Expand sheet to show the captured photo
      if (_sheetController.isAttached) {
        _sheetController.animateTo(
          0.5,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      debugPrint("Error taking photo: $e");
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _capturedPhotos.addAll(images);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _capturedPhotos.removeAt(index);
    });
  }

  Future<void> _identifyPhotos() async {
    if (_capturedPhotos.isEmpty) return;

    setState(() {
      _uiState = 1;
      _results.clear();
      _currentResultIndex = 0;
    });

    try {
      // Get Context Data
      // Safe Location Fetch
      Position? position;
      String locationStr = "Ubicación desconocida";

      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            // Get position with timeout
            try {
              position = await Geolocator.getCurrentPosition(
                  timeLimit: const Duration(seconds: 5));
            } catch (e) {
              debugPrint("Error getting position: $e");
            }

            if (position != null) {
               // Reverse Geocoding
               try {
                  List<Placemark> placemarks = await placemarkFromCoordinates(
                      position.latitude, position.longitude);
                  
                  if (placemarks.isNotEmpty) {
                    final place = placemarks.first;
                    // Priority: City, Country -> Country -> Unknown
                    final String city = place.locality ?? place.subAdministrativeArea ?? '';
                    final String country = place.country ?? '';

                    if (city.isNotEmpty && country.isNotEmpty) {
                      locationStr = "$city, $country";
                    } else if (country.isNotEmpty) {
                      locationStr = country;
                    } else {
                      locationStr = "Ubicación detectada";
                    }
                  }
               } catch (e) {
                 debugPrint("Error reverse geocoding: $e");
                 // User requested NO coordinates. Fallback to generic message.
                 locationStr = "Ubicación desconocida"; 
               }
               
               if (locationStr.isEmpty || locationStr == ",") {
                   locationStr = "Ubicación desconocida";
               }
            }
          }
        }
      } catch (e) {
        debugPrint("Location Permission/Service Error: $e");
        if (_useSimulatedCamera) {
          locationStr = "Requena, Valencia (Sim)";
        }
      }

      final DateTime now = DateTime.now();

      // 1. Analyze ALL photos
      // 1. Analyze ALL photos
      final List<GroupedResult> finalResults = [];

      for (var photo in _capturedPhotos) {
        String variety = "Desconocido";
        double confidence = 0.0;

        // Simulation Check
        if (_useSimulatedCamera && photo.path == 'simulated_path') {
          await Future.delayed(const Duration(milliseconds: 500));
          variety = "Moscatel";
          confidence = 98.2;
        } else {
          // Real API
          final predictions = await _apiClient.predictImage(photo);
          if (predictions != null && predictions.isNotEmpty) {
            variety = predictions.first.variedad;
            confidence = predictions.first.confianza;
          }
        }

        // Create individual result for each photo
        finalResults.add(GroupedResult(
          variety,
          confidence,
          [photo],
          date: now,
          location: locationStr,
          latitude: position?.latitude,
          longitude: position?.longitude,
        ));
      }

      if (mounted) {
        setState(() {
          _results = finalResults;

          if (_results.isEmpty) {
            _uiState = 0;
            if (_sheetController.isAttached) {
               _sheetController.animateTo(
                0.15, // Back to capture size
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("No se pudo identificar nada.")));
          } else {
            _uiState = 2;
             // Animate to result view size
            if (_sheetController.isAttached) {
              _sheetController.animateTo(
                0.65, // Result view size
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
              );
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uiState = 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveCurrentResult() async {
    if (_results.isEmpty) return;

    final currentGroup = _results[_currentResultIndex];
    final nameToSave = currentGroup.variety;

    final photosToSave = currentGroup.photos;

    setState(() => _isSaving = true);

    try {
      int successCount = 0;
      // Save ALL selected photos in this group
      for (var photo in photosToSave) {
        if (_useSimulatedCamera && photo.path == 'simulated_path') continue;

        await _apiClient.saveToCollection(
          imageFile: photo,
          nombreVariedad: nameToSave,
          notas:
              "Identificado con VitIA (${currentGroup.confidence.toStringAsFixed(1)}%)",
          lat: currentGroup.latitude,
          lon: currentGroup.longitude,
          esPublica: currentGroup.isPublic, // <--- Pasamos el estado del toggle
        );
        successCount++;
      }

      if (mounted) {
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('¡$successCount fotos guardadas en "$nameToSave"!'),
                backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Simulación: No se guardó nada.")));
        }

        // Remove THIS group from list
        setState(() {
          _results.removeAt(_currentResultIndex);
          // Adjust index if needed
          if (_currentResultIndex >= _results.length) {
            _currentResultIndex = _results.length - 1;
          }

          // If no more results, reset everything
          if (_results.isEmpty) {
            _reset();
          } else {
            // Force PageView to jump to valid page if index shifted?
            // PageView controller is tricky when list creates shifts.
            // Simplest: Replace PageController if index invalid, or just jump
            if (_resultPageController.hasClients) {
              // Wait next frame to jump safely? Or just rebuild will handle?
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _discardCurrentResult() {
    setState(() {
      _results.removeAt(_currentResultIndex);
      if (_currentResultIndex >= _results.length) {
        _currentResultIndex = _results.length - 1;
      }

      if (_results.isEmpty) {
        _reset();
      }
    });
  }

  void _reset() {
    setState(() {
      _uiState = 0;
      _capturedPhotos.clear();
      _results.clear();
      _currentResultIndex = 0;
    });
    // Animate back to initial capture size
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.15,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Camera Layer
          Positioned.fill(
            child: _buildCameraView(),
          ),

          // 2. Camera Controls
          if (_uiState == 0) ...[
            Positioned(
              left: 0, right: 0,
              top: MediaQuery.of(context).padding.top + 100,
              bottom: 350, // Moved up from 250
              child: const ScannerOverlay(),
            ),
            Positioned(
              left: 0, right: 0,
              bottom: 220, // Moved up from 120
              child: _buildCameraControls(),
            ),
          ],

          // 3. Top Bar - REMOVED CLOSE BUTTON as requested

          // 4. Draggable Bottom Sheet
          _buildDraggableSheet(),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    if (!_isCameraInitialized && !_useSimulatedCamera) {
      return Container(color: Colors.black);
    }
    if (_useSimulatedCamera) {
      return Image.network(_fallbackImage, fit: BoxFit.cover);
    }
    // Defensive check
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
       return Container(color: Colors.black); 
    }
    return CameraPreview(_cameraController!);
  }

  Widget _buildCameraControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              _currentFlashMode == FlashMode.off
                  ? Icons.flash_off
                  : _currentFlashMode == FlashMode.auto
                      ? Icons.flash_auto
                      : Icons.flash_on,
              color: Colors.white,
              size: 28,
            ),
            onPressed: _onToggleFlash,
          ),
          GestureDetector(
            onTap: _takePhoto,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Center(
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined,
                color: Colors.white, size: 28),
            onPressed: _onSwitchCamera,
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableSheet() {
    double minSize = 0.15;
    double maxSize = 0.85;
    double initialSize = 0.15;

    // Check UI State for initial sizing logic (only for reset/init)
    // We remove ValueKey so this widget is NOT recreated on state change.
    // We control the height via the controller in the state methods.

    return DraggableScrollableSheet(
      // key: ValueKey(_uiState), // REMOVED to prevent recreation hanging the UI
      controller: _sheetController,
      initialChildSize: initialSize, 
      minChildSize: minSize,
      maxChildSize: maxSize,
      snap: true, 
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -2))
              ]),
          child: LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildSheetContent(),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildSheetContent() {
    switch (_uiState) {
      case 1:
        return _buildLoadingState();
      case 2:
        return _buildResultState();
      case 0:
      default:
        return _buildCaptureState();
    }
  }

  Widget _buildCaptureState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Fotos capturadas",
          style: GoogleFonts.lora(
            fontSize: 24,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            ..._capturedPhotos.map((file) => Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: kIsWeb
                          ? Image.network(file.path, fit: BoxFit.cover)
                          : Image.file(File(file.path), fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () =>
                            _removePhoto(_capturedPhotos.indexOf(file)),
                        child: const CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 12,
                          child:
                              Icon(Icons.close, size: 14, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                )),
            GestureDetector(
              onTap: _pickFromGallery,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Icon(Icons.collections, color: Colors.black54),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _capturedPhotos.isNotEmpty ? _identifyPhotos : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B8036),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              elevation: 0,
            ),
            child: const Text("Identificar",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
              color: Color(0xFF8B1E5C), strokeWidth: 6),
        ),
        const SizedBox(height: 24),
        const Text("Identificando...",
            style: TextStyle(
                fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildResultState() {
    if (_results.isEmpty) return const SizedBox();

    return SizedBox(
      height: 600, // Constrain height for PageView
      child: PageView.builder(
        controller: _resultPageController,
        itemCount: _results.length,
        onPageChanged: (idx) => setState(() => _currentResultIndex = idx),
        itemBuilder: (context, index) {
          final group = _results[index];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER with Counter (if multiple groups)
              if (_results.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                      "Foto ${index + 1} de ${_results.length}",
                      style: const TextStyle(color: Colors.grey)),
                ),

              // STATIC NAME
              Text(
                group.variety,
                style:
                    GoogleFonts.lora(fontSize: 32, fontWeight: FontWeight.w400),
              ),

              Text(
                "Variedad identificada (${(group.confidence).toStringAsFixed(1)}% confianza)",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // MOSAIC GALLERY
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 400,
                  color: Colors.grey[100],
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // THE MOSAIC WIDGET
                      MosaicGallery(
                        photos: group.photos,
                      ),

                      // Bottom Info Overlay
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      DateFormat('dd/MM/yyyy')
                                          .format(group.date),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  Text(group.location,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // --- SELECTOR DE PRIVACIDAD ---
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          group.isPublic
                                              ? Icons.public
                                              : Icons.lock_outline,
                                          size: 18,
                                          color: group.isPublic
                                              ? const Color(0xFF8B8036)
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          group.isPublic
                                              ? "Visibilidad: Pública"
                                              : "Visibilidad: Privada",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: group.isPublic
                                                ? Colors.black87
                                                : Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Switch(
                                      value: group.isPublic,
                                      activeColor: const Color(0xFF8B8036),
                                      onChanged: (val) {
                                        setState(() {
                                          group.isPublic = val;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // BUTTON TO SAVE
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton(
                                  onPressed:
                                      _isSaving ? null : _saveCurrentResult,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[200],
                                      foregroundColor: Colors.black54,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(22))),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Text("Añadir a colección"),
                                ),
                              ),

                              // DISCARD BUTTON
                              Center(
                                child: TextButton(
                                  onPressed:
                                      _isSaving ? null : _discardCurrentResult,
                                  child: const Text("Descartar",
                                      style: TextStyle(
                                          color: Colors.grey,
                                          decoration:
                                              TextDecoration.underline)),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),

                      // Navigation Arrows (only if multiple Groups)
                      if (_results.length > 1) ...[
                        if (index > 0)
                          Positioned(
                            left: 8,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: CircleAvatar(
                                backgroundColor: Colors.black26,
                                radius: 20,
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_left,
                                      color: Colors.white, size: 28),
                                  onPressed: () {
                                    _resultPageController.previousPage(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut);
                                  },
                                ),
                              ),
                            ),
                          ),
                        if (index < _results.length - 1)
                          Positioned(
                            right: 8,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: CircleAvatar(
                                backgroundColor: Colors.black26,
                                radius: 20,
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_right,
                                      color: Colors.white, size: 28),
                                  onPressed: () {
                                    _resultPageController.nextPage(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut);
                                  },
                                ),
                              ),
                            ),
                          ),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MosaicGallery extends StatelessWidget {
  final List<XFile> photos;

  const MosaicGallery({super.key, required this.photos});

  void _showFullScreen(BuildContext context, int initialIndex) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              itemCount: photos.length,
              controller: PageController(initialPage: initialIndex),
              itemBuilder: (context, index) {
                final file = photos[index];
                return InteractiveViewer(
                  child: kIsWeb
                      ? Image.network(file.path, fit: BoxFit.contain)
                      : Image.file(File(file.path), fit: BoxFit.contain),
                );
              },
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox();
    if (photos.length == 1) return _img(context, photos[0], 0);

    if (photos.length == 2) {
      return Row(children: [
        Expanded(child: _img(context, photos[0], 0)),
        const SizedBox(width: 2),
        Expanded(child: _img(context, photos[1], 1)),
      ]);
    }

    if (photos.length == 3) {
      return Row(children: [
        Expanded(flex: 2, child: _img(context, photos[0], 0)),
        const SizedBox(width: 2),
        Expanded(
            child: Column(
          children: [
            Expanded(child: _img(context, photos[1], 1)),
            const SizedBox(height: 2),
            Expanded(child: _img(context, photos[2], 2)),
          ],
        ))
      ]);
    }

    // 4 or more
    return Column(children: [
      Expanded(
          child: Row(children: [
        Expanded(child: _img(context, photos[0], 0)),
        const SizedBox(width: 2),
        Expanded(child: _img(context, photos[1], 1)),
      ])),
      const SizedBox(height: 2),
      Expanded(
          child: Row(children: [
        Expanded(child: _img(context, photos[2], 2)),
        const SizedBox(width: 2),
        Expanded(child: _img(context, photos[3], 3)),
      ])),
    ]);
  }

  Widget _img(BuildContext context, XFile file, int index) {
    return GestureDetector(
      onTap: () => _showFullScreen(context, index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: file.path,
            child: kIsWeb
                ? Image.network(file.path, fit: BoxFit.cover)
                : Image.file(File(file.path), fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }
}

Widget _buildBottomNav() {
  return Container(
    height: 70, // Slightly taller
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    decoration: BoxDecoration(
      color: const Color(0xFF151D14), // Dark green/black
      borderRadius: BorderRadius.circular(35),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.white54),
            onPressed: () {}),
        Container(
          decoration:
              const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          padding: const EdgeInsets.all(8),
          child: const Icon(Icons.camera_alt, color: Colors.black, size: 20),
        ),
        IconButton(
            icon: const Icon(Icons.book_outlined, color: Colors.white54),
            onPressed: () {}),
        IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white54),
            onPressed: () {}),
      ],
    ),
  );
}

// Custom Painter for the brackets
class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 250,
        height: 250,
        child: CustomPaint(painter: ScannerCornerPainter()),
      ),
    );
  }
}

class ScannerCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    double length = 40.0;
    double radius = 24.0;

    // TL
    canvas.drawPath(
        Path()
          ..moveTo(0, length)
          ..lineTo(0, radius)
          ..arcToPoint(Offset(radius, 0), radius: Radius.circular(radius))
          ..lineTo(length, 0),
        paint);

    // TR
    canvas.drawPath(
        Path()
          ..moveTo(size.width - length, 0)
          ..lineTo(size.width - radius, 0)
          ..arcToPoint(Offset(size.width, radius),
              radius: Radius.circular(radius))
          ..lineTo(size.width, length),
        paint);

    // BL
    canvas.drawPath(
        Path()
          ..moveTo(0, size.height - length)
          ..lineTo(0, size.height - radius)
          ..arcToPoint(Offset(radius, size.height),
              radius: Radius.circular(radius), clockwise: false)
          ..lineTo(length, size.height),
        paint);

    // BR
    canvas.drawPath(
        Path()
          ..moveTo(size.width - length, size.height)
          ..lineTo(size.width - radius, size.height)
          ..arcToPoint(Offset(size.width, size.height - radius),
              radius: Radius.circular(radius), clockwise: false)
          ..lineTo(size.width, size.height - length),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
