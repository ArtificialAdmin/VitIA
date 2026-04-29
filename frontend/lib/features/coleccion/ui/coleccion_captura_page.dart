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
import 'package:vinas_mobile/features/coleccion/ui/premium_result_page.dart';
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

  final List<XFile> _capturedPhotos = [];
  bool _isAdvancedMode = false;
  final Map<PremiumStep, List<XFile>> _premiumPhotosMap = {
    PremiumStep.leafFront: [],
    PremiumStep.leafBack: [],
    PremiumStep.cluster: [],
    PremiumStep.singleGrape: [],
  };
  PremiumStep _premiumStep = PremiumStep.leafFront;

  // Now we store a LIST of groups
  List<GroupedResult> _results = [];

  // Controller for the currently viewed result (if we have multiple varieties, we page them)
  final PageController _resultPageController = PageController();
  int _currentResultIndex = 0;

  final DraggableScrollableController _sheetController = DraggableScrollableController();

  final ImagePicker _picker = ImagePicker();

  // Controllers map: Index in _results -> TextEditingController
  final String _fallbackImage =
      'https://images.unsplash.com/photo-1504221507732-5246c045949b?q=80&w=1000&auto=format&fit=crop';

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
      _capturedPhotos.clear();
      for (var step in PremiumStep.values) {
        _premiumPhotosMap[step]!.clear();
      }
      _uiState = 0;
      if (_sheetController.isAttached) {
        _sheetController.animateTo(0.15,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut);
      }
    });
  }

  void _onNextPremiumStep() {
    setState(() {
      if (_premiumStep.index < PremiumStep.values.length - 1) {
        _premiumStep = PremiumStep.values[_premiumStep.index + 1];
      } else {
        // Finished all 4 types -> Collect all and identify
        _capturedPhotos.clear();
        for (var step in PremiumStep.values) {
          _capturedPhotos.addAll(_premiumPhotosMap[step]!);
        }

        if (_capturedPhotos.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Captura al menos una foto en total.")));
          return;
        }

        _identifyPhotos();
      }
    });
  }

  void _onPreviousPremiumStep() {
    if (_premiumStep.index > 0) {
      setState(() {
        _premiumStep = PremiumStep.values[_premiumStep.index - 1];
      });
    }
  }

  void _discardPremiumCapture() {
    setState(() {
      for (var step in PremiumStep.values) {
        _premiumPhotosMap[step]!.clear();
      }
      _premiumStep = PremiumStep.leafFront;
    });
  }


  // --- ACTIONS ---

  Future<void> _takePhoto() async {
    if (!_isCameraInitialized && !_useSimulatedCamera) return;
    try {
      XFile photo;
      if (_useSimulatedCamera) {
          // Generar una imagen mínima (1x1 px transparente) válida para que el flujo no se rompa
          // y los bytes sean reales.
          final miniJpg = Uint8List.fromList([
            0xFF, 0xD8, 0xFF, 0xEE, 0x00, 0x0E, 0x41, 0x64, 0x6F, 0x62, 0x65, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00,
            0xFF, 0xDB, 0x00, 0x43, 0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09, 0x09, 0x08,
            0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12, 0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D,
            0x1A, 0x1C, 0x1C, 0x20, 0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29, 0x2C, 0x30,
            0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32, 0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00,
            0x0B, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x14, 0x01, 0x01, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xDA, 0x00, 0x08,
            0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0x37, 0xFF, 0xD9
          ]);
        photo = XFile.fromData(miniJpg, name: 'simulated_${DateTime.now().millisecondsSinceEpoch}.jpg', mimeType: 'image/jpeg');
      } else {
        photo = await _cameraController!.takePicture();
      }

      if (_isAdvancedMode) {
        setState(() {
          _premiumPhotosMap[_premiumStep]!.add(photo);
          // We NO LONGER auto-advance here. 
          // The user must click "Next Step" or "Finish"
        });
      } else {
        setState(() {
          _capturedPhotos.clear(); // Ensure only 1 photo in basic mode
          _capturedPhotos.add(photo);
        });
        // Expand sheet to show the captured photo
        if (_sheetController.isAttached) {
          _sheetController.animateTo(
            0.7,
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
          if (_isAdvancedMode) {
            _premiumPhotosMap[_premiumStep]!.addAll(images);
          } else {
            _capturedPhotos.clear(); // Ensure only 1 photo in basic mode
            _capturedPhotos.add(images.first);
          }
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

  void _removePhotoDynamic(XFile file) {
    setState(() {
      if (_isAdvancedMode) {
        for (var step in PremiumStep.values) {
          if (_premiumPhotosMap[step]!.contains(file)) {
            _premiumPhotosMap[step]!.remove(file);
            break;
          }
        }
      } else if (_capturedPhotos.contains(file)) {
        _capturedPhotos.remove(file);
      }
    });
  }

  Future<void> _identifyPhotos() async {
    if (_capturedPhotos.isEmpty) return;

    setState(() {
      _uiState = 1;
      _results.clear();
      _currentResultIndex = 0;
    });

    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.7,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

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

      // --- NEW LOGIC: SEPARATE ADVANCED FROM STANDARD ---
      if (_isAdvancedMode) {
        bool hasMissing = false;
        for (var step in PremiumStep.values) {
          if (_premiumPhotosMap[step]!.isEmpty) hasMissing = true;
        }

        final api = ref.read(apiProvider);
        // Send ALL 4 captured photos to the premium endpoint
        final response = await api.predictImagePremium(_capturedPhotos);
        final List<PredictionModel> premiumPredictions =
            response["predictions"];
        final String premiumAnalysis =
            response["analysis"] ?? "Análisis no disponible.";

        if (mounted && premiumPredictions.isNotEmpty) {
          // NAVIGATE TO PREMIUM RESULT PAGE
          final bool? saved = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PremiumResultPage(
                variety: premiumPredictions.first.variedad,
                confidence: premiumPredictions.first.confianza,
                color: premiumPredictions.first.color,
                photos: List.from(_capturedPhotos),
                analysisText: premiumAnalysis,
                hasMissingPhases: hasMissing,
                lat: position?.latitude,
                lon: position?.longitude,
              ),
            ),
          );

          // Reset state when coming back
          if (mounted) {
            setState(() {
              _capturedPhotos.clear();
              for (var step in PremiumStep.values) {
                _premiumPhotosMap[step]!.clear();
              }
              _premiumStep = PremiumStep.leafFront;
              _uiState = 0;
            });
            if (_sheetController.isAttached) {
              _sheetController.animateTo(0.15,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut);
            }
          }
          return;
        } else {
          // No se detectó nada válido en las fotos
          if (mounted) {
            setState(() => _uiState = 0);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("🔍 No hemos detectado una vid clara en estas fotos. Intenta acercarte más o mejorar la iluminación."),
                backgroundColor: Colors.orangeAccent,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      }

      // --- STANDARD MODE FLOW ---
      final List<GroupedResult> finalResults = [];

      for (var photo in _capturedPhotos) {
        String variety = "Desconocido";
        double confidence = 0.0;

        final api = ref.read(apiProvider);
        
        // Regular mode sends only one photo
        final List<PredictionModel> predictions = await api.predictImageBase(photo);
        if (predictions.isNotEmpty) {
          variety = predictions.first.variedad;
          confidence = predictions.first.confianza;
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
        String errorMessage = e.toString();
        if (errorMessage.startsWith("Exception: ")) {
          errorMessage = errorMessage.substring(11); // Removes "Exception: "
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
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
      for (var step in PremiumStep.values) {
        _premiumPhotosMap[step]!.clear();
      }
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
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0F0A), // Very dark solid dock
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. INSTRUCTIONS & PROGRESS (The "Green" part, now in the dock)
          if (_isAdvancedMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    _getPremiumLabel(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      bool active = index <= _premiumStep.index;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 3,
                          decoration: BoxDecoration(
                            color: active ? Colors.greenAccent : Colors.white12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // 2. Navigation & Photo Counter
          if (_isAdvancedMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPhotoCounter(),
                  _buildAdvancedControls(),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // 3. Main Controls (Flash, Trigger, Switch)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
          // SPACE to ensure buttons are above the bottom sheet handle
          const SizedBox(height: 120),
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

  // _canProceed removed, logic integrated into _buildAdvancedControls

  Widget _buildAdvancedControls() {
    bool isFirst = _premiumStep == PremiumStep.leafFront;
    bool isLast = _premiumStep == PremiumStep.singleGrape;
    
    int totalPhotos = 0;
    for (var list in _premiumPhotosMap.values) {
      totalPhotos += list.length;
    }
    bool canProceed = !isLast || totalPhotos > 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!isFirst) ...[
          ElevatedButton(
            onPressed: _onPreviousPremiumStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black45,
              foregroundColor: Colors.white,
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: Colors.white24)),
              elevation: 0,
            ),
            child: const Icon(Icons.arrow_back, size: 20),
          ),
          const SizedBox(width: 6),
        ],
        if (isLast)
          ElevatedButton.icon(
            onPressed: canProceed ? _onNextPremiumStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canProceed 
                  ? const Color(0xFFD4AF37) 
                  : Colors.grey.withOpacity(0.3),
              foregroundColor: canProceed 
                  ? Colors.black 
                  : Colors.white24,
              minimumSize: const Size(50, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              elevation: canProceed ? 10 : 0,
            ),
            icon: const Icon(Icons.check_circle, size: 20),
            label: const Text("Finalizar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          )
        else
          ElevatedButton(
            onPressed: canProceed ? _onNextPremiumStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canProceed 
                  ? const Color(0xFFD4AF37) 
                  : Colors.grey.withOpacity(0.3),
              foregroundColor: canProceed 
                  ? Colors.black 
                  : Colors.white24,
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              elevation: canProceed ? 10 : 0,
            ),
            child: const Icon(Icons.arrow_forward, size: 20),
          ),
      ],
    );
  }

  Widget _buildPhotoCounter() {
    int totalCount = 0;
    if (_isAdvancedMode) {
      for (var list in _premiumPhotosMap.values) {
        totalCount += list.length;
      }
    } else {
      totalCount = _capturedPhotos.length;
    }

    return Row(
      children: [
        GestureDetector(
          onTap: _pickFromGallery,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.add_photo_alternate, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            if (totalCount > 0 && _sheetController.isAttached) {
              _sheetController.animateTo(
                0.7,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_library_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  "$totalCount fotos",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
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
    double maxSize = 0.9;
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
    if (_isAdvancedMode) {
      int totalPhotos = 0;
      for (var list in _premiumPhotosMap.values) {
        totalPhotos += list.length;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Capturas de la vid",
            style: GoogleFonts.lora(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Revisa las fotos tomadas en todas las fases",
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 24),

          if (totalPhotos == 0)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text(
                      "Aún no hay fotos capturadas",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ...PremiumStep.values.map((step) {
              final stepPhotos = _premiumPhotosMap[step]!;
              if (stepPhotos.isEmpty) return const SizedBox();

              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E3B2E), // Dark green
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Fase ${step.index + 1}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "${stepPhotos.length} fotos",
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: stepPhotos.length,
                        itemBuilder: (context, idx) {
                          final file = stepPhotos[idx];
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey[100],
                                    child: kIsWeb
                                        ? Image.network(file.path, fit: BoxFit.cover)
                                        : Image.file(File(file.path), fit: BoxFit.cover),
                                  ),
                                ),

                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _discardPremiumCapture,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                label: const Text("DESCARTAR IDENTIFICACIÓN",
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 100),
        ],
      );
    }

    // MODO RÁPIDO (Original)
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
                        onTap: () => _removePhotoDynamic(file),
                        child: CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.9),
                          radius: 12,
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.black),
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

  // Helpers for grouped gallery
  IconData _getStepIcon(PremiumStep step) {
    switch (step) {
      case PremiumStep.leafFront:
        return Icons.eco;
      case PremiumStep.leafBack:
        return Icons.eco_outlined;
      case PremiumStep.cluster:
        return Icons.grain;
      case PremiumStep.singleGrape:
        return Icons.fiber_manual_record;
    }
  }

  String _getStepTitle(PremiumStep step) {
    switch (step) {
      case PremiumStep.leafFront:
        return "Haz de la hoja";
      case PremiumStep.leafBack:
        return "Envés de la hoja";
      case PremiumStep.cluster:
        return "Racimo completo";
      case PremiumStep.singleGrape:
        return "Detalle de uva";
    }
  }

  void _removePhotoFromStep(PremiumStep step, int index) {
    setState(() {
      _premiumPhotosMap[step]!.removeAt(index);
    });
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
