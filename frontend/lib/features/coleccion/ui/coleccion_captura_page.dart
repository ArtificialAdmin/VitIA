import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vinas_mobile/core/api_client.dart';
import 'package:vinas_mobile/core/api_config.dart';
import 'package:vinas_mobile/core/models/prediction_model.dart';
import 'package:vinas_mobile/features/auth/services/auth_session_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart'; // Standard date formatting if available, or just use raw strings
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/features/perfil/providers/perfil_state_provider.dart';
import 'package:vinas_mobile/features/coleccion/ui/widgets/premium_guide_overlay.dart';

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

class ColeccionCapturaPage extends ConsumerStatefulWidget {
  const ColeccionCapturaPage({super.key});

  @override
  ConsumerState<ColeccionCapturaPage> createState() => _ColeccionCapturaPageState();
}

class _ColeccionCapturaPageState extends ConsumerState<ColeccionCapturaPage> with TickerProviderStateMixin {
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
  
  // Premium / Advanced Mode State
  bool _isAdvancedMode = false;
  PremiumStep _premiumStep = PremiumStep.leafFront;
  // Temporary storage for photos of the CURRENT premium step
  final List<XFile> _currentStepPhotos = [];
  // Final storage for all premium photos
  final List<XFile> _allPremiumPhotos = [];

  // Now we store a LIST of groups
  List<GroupedResult> _results = [];

  // Controller for the currently viewed result (if we have multiple varieties, we page them)
  final PageController _resultPageController = PageController();
  int _currentResultIndex = 0;

  final DraggableScrollableController _sheetController = DraggableScrollableController();

  final ImagePicker _picker = ImagePicker();

  // Controllers map: Index in _results -> TextEditingController
  final String _fallbackImage =
      'https://images.unsplash.com/photo-1596244956306-a9df17907407?q=80&w=1974&auto=format&fit=crop';

  @override
  void initState() {
    super.initState();
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

  void _toggleAdvancedMode(bool value) {
    setState(() {
      _isAdvancedMode = value;
      _premiumStep = PremiumStep.leafFront;
      _currentStepPhotos.clear();
      _allPremiumPhotos.clear();
      _capturedPhotos.clear();
      _uiState = 0;
      if (_sheetController.isAttached) {
        _sheetController.animateTo(0.15, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    });
  }

  void _onNextPremiumStep() {
    setState(() {
      _allPremiumPhotos.addAll(_currentStepPhotos);
      _currentStepPhotos.clear();
      
      if (_premiumStep.index < PremiumStep.values.length - 1) {
        _premiumStep = PremiumStep.values[_premiumStep.index + 1];
      } else {
        // Finished all 4 types
        _capturedPhotos = List.from(_allPremiumPhotos);
        _identifyPhotos();
      }
    });
  }

  void _removeCurrentStepPhoto(int index) {
    setState(() {
      _currentStepPhotos.removeAt(index);
    });
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

      if (_isAdvancedMode) {
        setState(() {
          _currentStepPhotos.add(photo);
          // We NO LONGER auto-advance here. 
          // The user must click "Next Step" or "Finish"
        });
      } else {
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

        final api = ref.read(apiProvider);
        final List<PredictionModel> predictions;

        if (_isAdvancedMode) {
          // Send ALL captured photos to the premium endpoint
          predictions = await api.predictImagePremium(_capturedPhotos);
          if (predictions.isNotEmpty) {
            variety = predictions.first.variedad;
            confidence = predictions.first.confianza;
          }
        } else {
          // Regular mode sends only one photo
          predictions = await api.predictImageBase(photo);
          if (predictions.isNotEmpty) {
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

        await ref.read(apiProvider).saveToCollection(
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
    // Reset premium state too
    setState(() {
      _uiState = 0;
      _capturedPhotos.clear();
      _results.clear();
      _currentResultIndex = 0;
      _premiumStep = PremiumStep.leafFront;
      _currentStepPhotos.clear();
      _allPremiumPhotos.clear();
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
          // 1. MAIN LAYOUT (Viewfinder + Dock)
          Column(
            children: [
              // TOP: VIEW FINDER AREA
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildCameraView()),
                    
                    // Guides & Toggle over the camera ONLY
                    if (_uiState == 0) ...[
                      // Mode Toggle
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 20,
                        left: 0,
                        right: 0,
                        child: Center(child: _buildModeToggle()),
                      ),

                      Positioned.fill(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _isAdvancedMode
                              ? PremiumGuideOverlay(
                                  step: _premiumStep,
                                  label: _getPremiumLabel(),
                                )
                              : const ScannerOverlay(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // BOTTOM: CONTROL DOCK (Black bar for thumbnails & buttons)
              if (_uiState == 0) _buildControlDock(),
            ],
          ),

          // 2. DRAGGABLE SHEET (Always on top)
          _buildDraggableSheet(),
        ],
      ),
    );
  }

  Widget _buildControlDock() {
    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0F0A), // Very dark solid dock
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Review Gallery (Thumbnails)
          if (_isAdvancedMode && _currentStepPhotos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildPhotoReviewGallery(),
            ),

          // 2. Counter and Next Button (NOW ABOVE TRIGGER)
          if (_isAdvancedMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPhotoCounter(),
                  if (_currentStepPhotos.isNotEmpty) _buildNextStepButton(),
                ],
              ),
            ),

          if (_isAdvancedMode) const SizedBox(height: 12),

          // 3. Main Controls (Flash, Trigger, Switch)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _currentFlashModeIcon(),
                    _cameraSwitchIcon(),
                  ],
                ),
                _buildTriggerButton(),
              ],
            ),
          ),

          // EXTRA SPACE to ensure buttons are above the bottom sheet handle
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // Refactored helper widgets for the new Dock
  Widget _currentFlashModeIcon() {
    return IconButton(
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
    );
  }

  Widget _cameraSwitchIcon() {
    return IconButton(
      icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white, size: 28),
      onPressed: _onSwitchCamera,
    );
  }

  Widget _buildTriggerButton() {
    return GestureDetector(
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
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
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

  Widget _buildModeToggle() {
    final userAsync = ref.watch(userProfileProvider);

    return userAsync.when(
      data: (user) {
        if (user['es_premium'] != true) return const SizedBox();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toggleItem("Rápido", !_isAdvancedMode, () => _toggleAdvancedMode(false)),
              _toggleItem("Avanzado", _isAdvancedMode, () => _toggleAdvancedMode(true), isPremium: true),
            ],
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _toggleItem(String title, bool active, VoidCallback onTap, {bool isPremium = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? (isPremium ? const Color(0xFFD4AF37) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            if (isPremium) ...[
              Icon(Icons.stars, size: 16, color: active ? Colors.black : const Color(0xFFD4AF37)),
              const SizedBox(width: 6),
            ],
            Text(
              title,
              style: TextStyle(
                color: active ? Colors.black : Colors.white70,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextStepButton() {
    bool isLast = _premiumStep == PremiumStep.singleGrape;
    return ElevatedButton.icon(
      onPressed: _onNextPremiumStep,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 10,
      ),
      icon: Icon(isLast ? Icons.check_circle : Icons.arrow_forward),
      label: Text(
        isLast ? "Finalizar" : "Siguiente Fase",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPhotoCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_outlined, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            "${_currentStepPhotos.length} fotos",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoReviewGallery() {
    return Container(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _currentStepPhotos.length,
        itemBuilder: (context, index) {
          final photo = _currentStepPhotos[index];
          return Container(
            margin: const EdgeInsets.only(right: 12),
            width: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 2),
              image: DecorationImage(
                image: photo.path == 'simulated_path' 
                   ? const NetworkImage('https://images.unsplash.com/photo-1596244956306-a9df17907407?auto=format&fit=crop&w=200') as ImageProvider
                   : FileImage(File(photo.path)),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -2,
                  right: -2,
                  child: IconButton(
                    iconSize: 20,
                    icon: const CircleAvatar(
                      backgroundColor: Colors.red,
                      radius: 10,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                    onPressed: () => _removeCurrentStepPhoto(index),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getPremiumLabel() {
    switch (_premiumStep) {
      case PremiumStep.leafFront:
        return "Fase 1/4: Haz de la hoja\n(Encuadra la hoja de frente)";
      case PremiumStep.leafBack:
        return "Fase 2/4: Envés de la hoja\n(Dale la vuelta a la hoja)";
      case PremiumStep.cluster:
        return "Fase 3/4: Racimo\n(Encuadra el racimo completo)";
      case PremiumStep.singleGrape:
        return "Fase 4/4: Uva individual\n(Acerca la cámara a una uva)";
    }
  }

  // Legacy helper removed in favor of _buildControlDock and trigger helpers

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
                            bottom: 100,
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
                            bottom: 100,
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
