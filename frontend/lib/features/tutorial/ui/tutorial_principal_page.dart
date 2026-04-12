import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

// Asegúrate de que estos imports sean correctos
import 'package:vinas_mobile/core/api_client.dart';
import 'package:vinas_mobile/core/providers.dart';

class TutorialPage extends ConsumerStatefulWidget {
  final VoidCallback onFinished;
  final bool isCompulsory;

  const TutorialPage(
      {super.key,
      required this.onFinished,
      required this.isCompulsory});

  @override
  ConsumerState<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends ConsumerState<TutorialPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 6; // Pantalla 0 (Intro) + 5 Guías (1 a 5)

  // Estados de carga
  bool _isCompleting = false;

  // --- COLORES AJUSTADOS A FIGMA ---
  final Color _mainColor =
      const Color(0xFF8B9E3A); // Verde Musgo (Usado en el botón de la P0)

  // El color oscuro de la barra ya no es necesario aquí.

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Lógica para finalizar el tutorial (marcar en API y navegar)
  Future<void> _completeTutorial() async {
    if (_isCompleting) return;

    if (widget.isCompulsory) {
      setState(() => _isCompleting = true);
      try {
        await ref.read(apiProvider).markTutorialAsComplete();
      } on DioException catch (e) {
        debugPrint(
            "Error al completar el tutorial en el servidor: ${e.message}");
      } finally {
        if (mounted) setState(() => _isCompleting = false);
      }
    }

    // Navegar a la pantalla principal
    widget.onFinished();
  }

  // --- UTILERIAS DE WIDGETS ---

  // 1. Tarjeta de Consejos (P3)
  Widget _buildImageTipCard(String assetName) {
    return Container(
      width: 140,
      height: 140,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
      child: Image.asset(
        'assets/tutorial/$assetName', // Nombres seguros
        fit: BoxFit.contain,
      ),
    );
  }

  // 2. Tarjeta de Biblioteca (P5)
  Widget _buildFinalCard(String title, String content) {
    return Container(
      width: 140,
      height: 120,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 5),
          Text(content,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  // --- Contenido específico de cada pantalla ---

  Widget _buildPageContent(int index) {
    switch (index) {
      case 0: // Pantalla 0: Introducción
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50),
            // Título con fuente Lora simulada
            const Text('Es tu primera vez\npor aquí?',
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                    fontFamily: 'Lora')),
            const SizedBox(height: 15),
            const Text(
                'Vitia te ayuda a identificar variedades de viñas usando la cámara.'),

            const Spacer(flex: 3),

            const Text('¿Quieres aprender cómo funciona?',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 15),

            const Spacer(flex: 1),
          ],
        );

      case 1: // Pantalla 1: Abre la cámara
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            const Text('¡Empieza aquí!',
                style: TextStyle(fontWeight: FontWeight.normal, fontSize: 18)),
            const Spacer(),
            // 🖼️ Burbuja P1: (burbuja_p1.png)
            Center(
              child: Image.asset(
                'assets/tutorial/burbuja_p1.png',
                width: 280,
                fit: BoxFit.contain,
              ),
            ),
            // Ajuste visual para que la flecha de la burbuja apunte a la cámara (2º icono)
            const SizedBox(height: 10),
          ],
        );

      case 2: // Pantalla 2: Preparación
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              const Text('Preparación',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text(
                  'Coloca la hoja o racimo delante del móvil. Cuanta más claridad tenga la imagen, mejor será la detección'),
              const SizedBox(height: 30),
              Center(
                // 🖼️ Ilustración del móvil/mano (ilustracion_movil.png)
                child: Image.asset(
                  'assets/tutorial/ilustracion_movil.png',
                  width: 300, // Aumentado de 250
                  height: 400, // Aumentado de 350
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        );

      case 3: // Pantalla 3: Consejos para la Foto
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              const Text('Haz una foto clara y centrada',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                // 🖼️ Tarjetas de consejos
                children: [
                  _buildImageTipCard('tarjeta_consejo_1.png'),
                  _buildImageTipCard('tarjeta_consejo_2.png'),
                  _buildImageTipCard('tarjeta_consejo_3.png'),
                  _buildImageTipCard('tarjeta_consejo_4.png'),
                ],
              ),
              const SizedBox(height: 50),
            ],
          ),
        );

      case 4: // Pantalla 4: Detección Instantánea
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              const Text('Detectamos la variedad al instante',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text(
                  'Cuando haces una foto, Vitia identifica la variedad y la desbloquea automáticamente en tu biblioteca'),
              const SizedBox(height: 40),
              Center(
                  child: Stack(alignment: Alignment.topCenter, children: [
                // 🖼️ Tarjeta de Trepadell
                Image.asset(
                  'assets/tutorial/tarjeta_deteccion_p4.png', // Nombre seguro
                  width: 150,
                  height: 250,
                  fit: BoxFit.contain,
                ),
                // 🖼️ Línea punteada
                Padding(
                  padding: const EdgeInsets.only(top: 220),
                  child: Image.asset(
                    'assets/tutorial/flecha_p4.png', // Nombre seguro
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                ),
              ])),
              const SizedBox(height: 50),
            ],
          ),
        );

      case 5: // Pantalla 5: Final / Biblioteca
        return Column(
          children: [
            const SizedBox(height: 30),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Consulta tu biblioteca',
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
            const SizedBox(height: 20),

            // Tarjetas de Biblioteca
            Row(
              mainAxisAlignment: MainAxisAlignment
                  .spaceBetween, // Ajustado a between para que ocupen ancho
              children: [
                _buildFinalCard("Todas las variedades",
                    "Información completa de cualquier variedad"),
                _buildFinalCard("Tus variedades",
                    "Galería de todas las variedades que hayas detectado"),
              ],
            ),

            const Spacer(),

            // 🖼️ Burbuja Final con el botón "Comenzar" DENTRO - CON INTERACCIÓN
            Center(
              child: Container(
                width: 320,
                height: 180,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // 1. Imagen de la burbuja (fondo visual)
                    Image.asset(
                      'assets/tutorial/burbuja_p5.png', // Nombre seguro
                      width: 320,
                      fit: BoxFit.contain,
                    ),
                    // 2. Botón interactivo superpuesto sobre la ilustración
                    Positioned(
                      right: 20,
                      bottom: 25,
                      child: SizedBox(
                        width: 120, // Ajustado a un tamaño intermedio
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _completeTutorial,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                          ),
                          child: const SizedBox.shrink(), // No muestra texto
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Apunta al catálogo (3er icono)
            const SizedBox(height: 10),
          ],
        );

      default:
        return const Center(child: Text('Error de página'));
    }
  }

  Widget _buildTutorialScreen(int index) {
    final isLastPage = index == _numPages - 1;
    final isFirstPage = index == 0;
    final isGuidePage = index > 0;

    // Define la ruta del indicador de progreso (Uvas)
    String indicatorAsset = '';
    if (isGuidePage) {
      indicatorAsset = 'assets/tutorial/indicadores_uvas_$index.png';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFCFBF6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. HEADER REFACTORIZADO

              // Fila Superior: Solo el botón de Cerrar (Alienado a la derecha)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 30),
                  onPressed:
                      isFirstPage ? widget.onFinished : _completeTutorial,
                ),
              ),

              if (isGuidePage) ...[
                // Fila del Título: "Guía de uso" ----- "X/5"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Guía de uso',
                        style: TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 32,
                            fontWeight: FontWeight.bold)),
                    Text('$index/5',
                        style: const TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 32,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),

                // Fila de Navegación: Flecha < -- Uvas -- Flecha >
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Flecha Atrás
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          size: 30,
                          color: index > 1
                              ? const Color(
                                  0xFFC48B9F) // Un rosa más suave según diseño
                              : Colors.transparent),
                      onPressed: index > 1
                          ? () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.ease)
                          : null,
                    ),

                    // Indicadores (Uvas)
                    Image.asset(
                      indicatorAsset,
                      height: 25, // Un poco más grandes
                      fit: BoxFit.contain,
                    ),

                    // Flecha Adelante
                    IconButton(
                      icon: Icon(Icons.arrow_forward,
                          size: 30,
                          color: !isLastPage
                              ? const Color(0xFFC48B9F)
                              : Colors.transparent),
                      onPressed: !isLastPage
                          ? () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.ease)
                          : null,
                    ),
                  ],
                ),
              ],

              // 2. CONTENIDO
              Expanded(child: _buildPageContent(index)),

              // 3. Botones Inferiores (Solo en P0)
              if (isFirstPage)
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.ease),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: _mainColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25)),
                      ),
                      child: const Text('Ver tutorial',
                          style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: widget.onFinished,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: BorderSide(color: _mainColor, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25)),
                      ),
                      child:
                          Text('Saltar', style: TextStyle(color: _mainColor)),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: isGuidePage ? _buildStaticNavBar(index) : null,
    );
  }

  Widget _buildStaticNavBar(int pageIndex) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF142018), // Mismo color que HomePrincipalPage
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF142018).withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavIcon('assets/navbar/icon_nav_home.png', false),
            // Activar Cámara en P1
            _buildNavIcon('assets/navbar/icon_nav_camera.png', pageIndex == 1),
            // Activar Catálogo en P4 y P5
            _buildNavIcon('assets/navbar/icon_nav_catalogo.png',
                pageIndex == 4 || pageIndex == 5),
            _buildNavIcon('assets/navbar/icon_nav_foro.png', false),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(String assetPath, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: isActive
          ? const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            )
          : null,
      child: Image.asset(
        assetPath,
        width: 24,
        height: 24,
        color: isActive
            ? const Color(0xFF142018)
            : Colors.white, // Blanco brillante si es inactivo (outline)
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) => setState(() => _currentPage = index),
      children:
          List.generate(_numPages, (index) => _buildTutorialScreen(index)),
    );
  }
}
