import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CustomCameraPage extends StatefulWidget {
  const CustomCameraPage({super.key});

  @override
  State<CustomCameraPage> createState() => _CustomCameraPageState();
}

class _CustomCameraPageState extends State<CustomCameraPage> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isLoading = true; // Track loading state
  String? _errorMessage; // Track error message
  FlashMode _currentFlashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = "No se encontraron cámaras disponibles.";
          });
        }
        return;
      }
      await _initCameraWithIndex(0);
    } catch (e) {
      debugPrint("Error initializing camera system: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error al iniciar la cámara: $e";
        });
      }
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
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint("Error initializing camera controller: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "No se pudo acceder a la cámara.";
        });
      }
    }
  }

  Future<void> _takePhoto() async {
    if (!_isCameraInitialized) return;
    try {
      final XFile photo = await _cameraController!.takePicture();
      if (mounted) {
        Navigator.pop(context, photo);
      }
    } catch (e) {
      debugPrint("Error taking photo: $e");
    }
  }

  Future<void> _toggleFlash() async {
    if (!_isCameraInitialized) return;
    FlashMode newMode = _currentFlashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await _cameraController!.setFlashMode(newMode);
    setState(() => _currentFlashMode = newMode);
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    int newIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _cameraController?.dispose();
    setState(() {
      _isCameraInitialized = false;
      _isLoading = true; // Show loading while switching
      _selectedCameraIndex = newIndex;
    });
    _initCameraWithIndex(newIndex);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Loading State
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // 2. Error State (No camera or permission denied)
    if (_errorMessage != null || !_isCameraInitialized) {
       return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? "Error desconocido de cámara",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
             // Close button always available to escape
            Positioned(
              top: 50,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            )
          ],
        ),
      );
    }

    // 3. Success State (Camera Preview)
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          
          // Controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   IconButton(
                    icon: Icon(
                      _currentFlashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
                      color: Colors.white, size: 30
                    ),
                    onPressed: _toggleFlash,
                  ),
                  GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 30),
                    onPressed: _switchCamera,
                  ),
                ],
              ),
            ),
          ),
          
          // Close button
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          )
        ],
      ),
    );
  }
}
