import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../../core/services/user_sesion.dart';
import '../../core/api_client.dart';
import '../../core/services/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/vitia_header.dart';
import 'detalle_variedad_page.dart';
import 'user_variety_detail_page.dart';
import 'detalle_coleccion_page.dart';
import '../capture/foto_page.dart';

class CatalogoPage extends StatefulWidget {
  // ⬅️ CLASE RENOMBRADA A CATÁLOGO
  final int initialTab;
  final ApiClient? apiClient;
  final VoidCallback? onCameraTap; // CAMBIO: Callback para navegación externa

  const CatalogoPage(
      {super.key, this.initialTab = 0, this.apiClient, this.onCameraTap});

  @override
  State<CatalogoPage> createState() =>
      _CatalogoPageState(); // ⬅️ ESTADO RENOMBRADO A CATÁLOGO
}

class _CatalogoPageState extends State<CatalogoPage>
    with SingleTickerProviderStateMixin {
  // ⬅️ ESTADO RENOMBRADO A CATÁLOGO

  // --- VARIABLES DE ESTADO Y CONTROL ---
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Variables del estado original (mantidas para la lógica)
  bool _modoOscuro = false;
  // 1. AÑADE ESTAS VARIABLES
  List<Map<String, dynamic>> _variedades = [];
  List<Map<String, dynamic>> _coleccionUsuario = [];

  // --- FAVORITOS ---
  Set<int> _favoritosIds = {}; // Para búsqueda rápida O(1)
  List<Map<String, dynamic>> _listaFavoritos =
      []; // Objetos completos para el carrusel

  List<Map<String, dynamic>> _filtradas = [];

  // Modificado: Ahora _coleccionUsuario y _filtradasColeccion serán una lista de ÚNICOS (representantes)
  // para mostrar en la lista agrupada.
  List<Map<String, dynamic>> _filtradasColeccion = [];

  // Nuevo: Mapa para guardar todos los items agrupados por nombre de variedad
  Map<String, List<Map<String, dynamic>>> _mapaVariedadesUsuario = {};

  // CONTROL DE NAVEGACIÓN INTERNA (Para mantener BottomNavBar)
  Map<String, dynamic>? _variedadSeleccionada;
  Map<String, dynamic>? _grupoColeccionSeleccionado;

  bool _isLoading = true;
  ApiClient? _apiClient; // Usa ? para evitar problemas de late si algo falla

  // --- NUEVOS CONTROLADORES DE FILTRO ---
  String _currentSort = 'az'; // 'az', 'za'
  String _currentFilterColor = 'all'; // 'all', 'blanca', 'tinta'
  bool _showSearch = false; // Toggle para mostrar buscador

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.index = widget.initialTab;

    // 1. INYECCIÓN DE DEPENDENCIAS
    // Si el test nos pasa un cliente falso (mock), usamos ese. Si no, el real.
    _apiClient = widget.apiClient ?? ApiClient(getBaseUrl());

    // 2. CORRECCIÓN DEL CICLO DE VIDA (CRÍTICO PARA TESTS)
    // Usamos addPostFrameCallback para esperar a que la UI se construya antes de cargar.
    // Esto permite mostrar el SnackBar de error sin que falle el test.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (UserSession.token != null) {
        _apiClient!.setToken(UserSession.token!);
        _cargarTodo(); // Carga ambas listas (Biblioteca + Colección)
      } else {
        _cargarSoloBiblioteca(); // Carga solo la pública
      }
    });
  }

  Future<void> _cargarTodo() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _cargarVariedadesBackend(),
      _cargarColeccionBackend(),
      _cargarFavoritosBackend(), // <--- Nuevo
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _cargarSoloBiblioteca() async {
    setState(() => _isLoading = true);
    await _cargarVariedadesBackend();
    // No cargamos favoritos si no hay usuario, o los cargamos vacíos
    setState(() => _isLoading = false);
  }

  // 3. AÑADE ESTE MÉTODO
  Future<void> _cargarVariedadesBackend() async {
    // 1. Aseguramos que se muestre el spinner de carga al empezar
    setState(() => _isLoading = true);

    try {
      final lista = await _apiClient!.getVariedades();

      setState(() {
        _variedades = lista
            .map((item) {
              return {
                'id': item['id_variedad'],
                'nombre': item['nombre'],
                'descripcion': item['descripcion'],
                'region': 'España',
                'tipo': item['color'] ?? 'Desconocido',
                'imagen': (item['links_imagenes'] != null &&
                        (item['links_imagenes'] as List).isNotEmpty)
                    ? item['links_imagenes'][0]
                    : null,
                'morfologia': item['morfologia'],
                'info_extra': item['info_extra'],
              };
            })
            .toList()
            .cast<Map<String, dynamic>>();

        _filtradas = _variedades;
        // _isLoading = false; // LO QUITAMOS DE AQUÍ (se hace en finally)
      });
    } catch (e) {
      debugPrint("Error cargando catálogo: $e");

      // --- CORRECCIÓN VISUAL ---
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Error de conexión: No se pudieron cargar las viñas'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
                label: 'Reintentar',
                textColor: Colors.white,
                onPressed:
                    _cargarVariedadesBackend // Botón para probar otra vez
                ),
          ),
        );
      }
    } finally {
      // --- ESTO ASEGURA QUE EL CIRCULITO DEJE DE GIRAR SIEMPRE ---
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cargarColeccionBackend() async {
    try {
      final lista = await _apiClient!.getUserCollection();

      final List<Map<String, dynamic>> todosLosItems = lista
          .map((item) {
            final variedadData = item['variedad'] ?? {};
            return {
              'id': item['id_coleccion'],
              'nombre': variedadData['nombre'] ?? 'Sin nombre',
              'descripcion': item['notas'] ?? variedadData['descripcion'],
              'region': 'Mi Bodega',
              'tipo': variedadData['color'] ?? 'Personal',
              'imagen': item['path_foto_usuario'],
              'morfologia': variedadData['morfologia'],
              'fecha_captura': item['fecha_captura'],
              'latitud': item['latitud'],
              'longitud': item['longitud'],
              'es_local': false,
              'variedad_original': variedadData, // Guardamos info extra
            };
          })
          .toList()
          .cast<Map<String, dynamic>>();

      // 1. Agrupar por nombre
      final Map<String, List<Map<String, dynamic>>> agrupado = {};
      for (var item in todosLosItems) {
        final nombre = item['nombre'];
        if (!agrupado.containsKey(nombre)) {
          agrupado[nombre] = [];
        }
        agrupado[nombre]!.add(item);
      }

      // 2. Crear lista de representantes (uno por cada clave del mapa)
      final prefs = await SharedPreferences.getInstance();
      final userId = UserSession.userId ?? 0;
      final List<Map<String, dynamic>> representantes = [];

      for (var entry in agrupado.entries) {
        // Clonamos el primero para no mutar el original
        var rep = Map<String, dynamic>.from(entry.value.first);
        final keyPref = "cover_$userId" + "_" + (rep['nombre'] ?? '');
        final customCover = prefs.getString(keyPref);

        if (customCover != null) {
          rep['imagen'] = customCover;
        }

        representantes.add(rep);
      }

      setState(() {
        _coleccionUsuario = representantes; // Esto ahora es la lista de GRUPOS
        _mapaVariedadesUsuario = agrupado;
        _filtradasColeccion = _coleccionUsuario;
      });
    } catch (e) {
      debugPrint("Error cargando colección: $e");
      // Feedback visual también aquí
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar tu colección')),
        );
      }
    }
  }

  Future<void> _cargarFavoritosBackend() async {
    try {
      final lista = await _apiClient!.getFavorites();
      setState(() {
        _listaFavoritos = lista
            .map((item) => {
                  'id': item['id_variedad'],
                  'nombre': item['nombre'],
                  'imagen': (item['links_imagenes'] != null &&
                          (item['links_imagenes'] as List).isNotEmpty)
                      ? item['links_imagenes'][0]
                      : null,
                  // 'color': item['color'], // Podríamos usarlo para estilo
                })
            .toList()
            .cast<Map<String, dynamic>>();

        _favoritosIds = _listaFavoritos.map((e) => e['id'] as int).toSet();
      });
    } catch (e) {
      debugPrint("Error cargando favoritos: $e");
    }
  }

  Future<void> _toggleFavorito(int idVariedad) async {
    // Optimistic UI Update
    final bool esFavorito = _favoritosIds.contains(idVariedad);

    setState(() {
      if (esFavorito) {
        _favoritosIds.remove(idVariedad);
        _listaFavoritos.removeWhere((item) => item['id'] == idVariedad);
      } else {
        _favoritosIds.add(idVariedad);
        // Necesitamos el objeto completo para añadirlo a la lista visual de arriba.
        // Lo buscamos en _variedades (biblioteca) o en _coleccion (si aplica, aunque coleccion agrupa).
        // Lo más seguro es buscar en _variedades que tiene TODAS.
        final variedad = _variedades.firstWhere(
            (element) => element['id'] == idVariedad,
            orElse: () => {});
        if (variedad.isNotEmpty) {
          _listaFavoritos.add({
            'id': variedad['id'],
            'nombre': variedad['nombre'],
            'imagen': variedad['imagen']
          });
        }
      }
    });

    try {
      await _apiClient!.toggleFavorite(idVariedad);
      // Si todo va bien, no hacemos nada más.
    } catch (e) {
      // Revertir si falla (opcional, pero recomendado)
      // Por simplicidad, recargamos todo o mostramos error.
      debugPrint("Error al dar like: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al actualizar favoritos")));
      _cargarFavoritosBackend(); // Revertir al estado real
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- MÉTODOS DE GESTIÓN DE DATOS Y LÓGICA ORIGINAL (MANTENIDOS) ---

  void _filtrar(String query) {
    setState(() {
      // 1. Elegir la lista base según la pestaña
      List<Map<String, dynamic>> baseList =
          (_tabController.index == 0) ? _variedades : _coleccionUsuario;

      // 2. Filtrar por TEXTO
      var temp = baseList
          .where((v) => v['nombre'].toLowerCase().contains(query.toLowerCase()))
          .toList();

      // 3. Filtrar por COLOR
      if (_currentFilterColor != 'all') {
        final target = _currentFilterColor == 'blanca' ? 'Blanca' : 'Negra';
        // Ajustamos para que coincida con 'tipo' o 'color' que venga del backend
        temp = temp.where((v) {
          final tipo = v['tipo'].toString();
          // A veces viene "Blanca", otras "blanca". Normalizamos.
          return tipo.toLowerCase() == target.toLowerCase();
        }).toList();
      }

      // 4. ORDENAR (Sort)
      if (_currentSort == 'az') {
        temp.sort((a, b) => a['nombre'].compareTo(b['nombre']));
      } else {
        temp.sort((a, b) => b['nombre'].compareTo(a['nombre']));
      }

      // 5. Asignar al estado correspondiente
      if (_tabController.index == 0) {
        _filtradas = temp;
      } else {
        _filtradasColeccion = temp;
      }
    });
  }

  void _mostrarMenuFiltros(BuildContext context) {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return StatefulBuilder(builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Filtrar y Ordenar",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // Cierra el modal
                        },
                        child: const Text("Aplicar",
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("Orden",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ActionChip(
                        label: const Text("A - Z"),
                        backgroundColor: _currentSort == 'az'
                            ? Colors.black
                            : Colors.grey.shade100,
                        labelStyle: TextStyle(
                            color: _currentSort == 'az'
                                ? Colors.white
                                : Colors.black),
                        onPressed: () {
                          setModalState(() => _currentSort = 'az');
                          _filtrar(_searchController.text);
                          setState(() {}); // Actualiza la pantalla principal
                        },
                      ),
                      const SizedBox(width: 10),
                      ActionChip(
                        label: const Text("Z - A"),
                        backgroundColor: _currentSort == 'za'
                            ? Colors.black
                            : Colors.grey.shade100,
                        labelStyle: TextStyle(
                            color: _currentSort == 'za'
                                ? Colors.white
                                : Colors.black),
                        onPressed: () {
                          setModalState(() => _currentSort = 'za');
                          _filtrar(_searchController.text);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("Tipo de Uva",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ActionChip(
                        label: const Text("Todas"),
                        backgroundColor: _currentFilterColor == 'all'
                            ? Colors.black
                            : Colors.grey.shade100,
                        labelStyle: TextStyle(
                            color: _currentFilterColor == 'all'
                                ? Colors.white
                                : Colors.black),
                        onPressed: () {
                          setModalState(() => _currentFilterColor = 'all');
                          _filtrar(_searchController.text);
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 10),
                      ActionChip(
                        label: const Text("Blanca"),
                        backgroundColor: _currentFilterColor == 'blanca'
                            ? const Color(0xFF8B8000)
                            : Colors.grey.shade100, // Gold
                        labelStyle: TextStyle(
                            color: _currentFilterColor == 'blanca'
                                ? Colors.white
                                : Colors.black),
                        onPressed: () {
                          setModalState(() => _currentFilterColor = 'blanca');
                          _filtrar(_searchController.text);
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 10),
                      ActionChip(
                        label: const Text("Negra"),
                        backgroundColor: _currentFilterColor == 'tinta'
                            ? const Color(0xFF800020)
                            : Colors.grey.shade100, // Burgundy
                        labelStyle: TextStyle(
                            color: _currentFilterColor == 'tinta'
                                ? Colors.white
                                : Colors.black),
                        onPressed: () {
                          setModalState(() => _currentFilterColor = 'tinta');
                          _filtrar(_searchController.text);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          });
        });
  }

  void _abrirCamara() {
    // CAMBIO: Si se proporciona callback, úsalo para cambiar de tab.
    if (widget.onCameraTap != null) {
      widget.onCameraTap!();
    } else {
      // Fallback a navegación antigua (por si acaso)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FotoPage()),
      ).then((_) {
        _cargarVariedadesBackend();
      });
    }
  }

  void _mostrarDialogoNuevaVariedad(File imagen, String ubicacionInicial) {
    final nombreCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ubicCtrl = TextEditingController(text: ubicacionInicial);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nueva Variedad"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              Image.file(imagen, height: 100),
              TextField(
                controller: nombreCtrl,
                decoration:
                    const InputDecoration(labelText: "Nombre de variedad"),
              ),
              TextField(
                controller: descCtrl,
                decoration:
                    const InputDecoration(labelText: "Descripción (opcional)"),
              ),
              TextField(
                controller: ubicCtrl,
                decoration:
                    const InputDecoration(labelText: "Ubicación (opcional)"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text("Guardar"),
            onPressed: () {
              setState(() {
                _variedades.add({
                  'nombre': nombreCtrl.text,
                  'imagen': imagen.path,
                  'descripcion': descCtrl.text,
                  'ubicacion': ubicCtrl.text,
                  'region': 'Colección Personal',
                  'tipo': 'Desconocido',
                });
                _filtradas = List.from(_variedades);
              });
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEditarVariedad(Map<String, dynamic> variedad) {
    final nombreCtrl = TextEditingController(text: variedad['nombre']);
    final descCtrl = TextEditingController(text: variedad['descripcion']);
    final ubicCtrl = TextEditingController(text: variedad['ubicacion']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Editar Variedad"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: "Nombre"),
              ),
              TextField(
                controller: descCtrl,
                decoration:
                    const InputDecoration(labelText: "Descripción (opcional)"),
              ),
              TextField(
                controller: ubicCtrl,
                decoration:
                    const InputDecoration(labelText: "Ubicación (opcional)"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text("Guardar"),
            onPressed: () {
              setState(() {
                variedad['nombre'] = nombreCtrl.text;
                variedad['descripcion'] = descCtrl.text;
                variedad['ubicacion'] = ubicCtrl.text;
              });
              Navigator.pop(ctx);
              Navigator.pop(context);
              _mostrarFichaTecnica(variedad);
            },
          ),
        ],
      ),
    );
  }

  void _mostrarFichaTecnica(Map<String, dynamic> variedad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                variedad['imagen'],
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    variedad['nombre'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.brush, color: Colors.blueGrey),
                  tooltip: "Editar",
                  onPressed: () => _mostrarDialogoEditarVariedad(variedad),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: "Eliminar",
                  onPressed: () => _confirmarEliminacion(variedad),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              variedad['descripcion']?.isNotEmpty == true
                  ? variedad['descripcion']
                  : "Sin descripción disponible",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              variedad['ubicacion']?.isNotEmpty == true
                  ? "Ubicación: ${variedad['ubicacion']}"
                  : "Ubicación no especificada",
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminacion(Map<String, dynamic> variedad) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Variedad"),
        content: Text(
            "¿Seguro que deseas eliminar la variedad \"${variedad['nombre']}\"?"),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
            onPressed: () {
              setState(() {
                _variedades.remove(variedad);
                _filtradas = List.from(_variedades);
              });
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _alternarTema() {
    setState(() {
      _modoOscuro = !_modoOscuro;
    });
  }

  // ------------------------------------------------------------------
  // --- WIDGETS DE INTERFAZ (ADAPTADOS AL NUEVO DISEÑO) ---

  Widget _buildVarietyCard(Map<String, dynamic> variedad,
      {bool isColeccion = false}) {
    final bool isBlanca = variedad['tipo'] == 'Blanca';
    final String? imagenPath = variedad['imagen'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        // Mismo diseño de contenedor que la colección
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade900),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            if (isColeccion) {
              final idVar = variedad['variedad_original'] != null
                  ? variedad['variedad_original']['id_variedad']
                  : null;
              final bool esFav = idVar != null && _favoritosIds.contains(idVar);

              final resultado = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserVarietyDetailPage(
                    varietyInfo: variedad,
                    captures: _mapaVariedadesUsuario[variedad['nombre']] ?? [],
                    isFavoritoInicial: esFav,
                    onBack: () {
                      _cargarFavoritosBackend(); // Refresh favs if changed
                      Navigator.pop(context);
                    },
                  ),
                ),
              );
              // Refresh collections and favs
              _cargarColeccionBackend();
              _cargarFavoritosBackend();
            } else {
              // DETALLE GLOBALES ("Todas")
              final idVar = variedad['id'];
              final bool esFav = idVar != null && _favoritosIds.contains(idVar);

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetalleVariedadPage(
                      variedad: variedad,
                      isFavoritoInicial: esFav,
                      onBack: () {
                        _cargarFavoritosBackend();
                        Navigator.pop(context);
                      }),
                ),
              );
              // Al volver, refrescamos favoritos por si cambiaron dentro
              _cargarFavoritosBackend();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(
                20.0), // Padding aumentado a 20 como en colección
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header con Corazón (Visual)
                      Row(
                        children: [
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              final id = variedad['id'];
                              if (id != null) _toggleFavorito(id);
                            },
                            child: Icon(
                                _favoritosIds.contains(variedad['id'])
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 24, // Un poco más grande para tocar
                                color: _favoritosIds.contains(variedad['id'])
                                    ? Colors.redAccent
                                    : Colors.black54),
                          ),
                        ],
                      ),
                      // Nombre con estilo Serif
                      Text(
                        variedad['nombre'],
                        style: GoogleFonts.lora(
                            fontSize: 28,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF1E2623)),
                      ),
                      const SizedBox(height: 12),

                      // Pill de Tipo con colores Gold/Burgundy
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isBlanca
                              ? const Color(0xFF8B8000).withOpacity(0.8)
                              : const Color(0xFF800020).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          variedad['tipo'],
                          style: GoogleFonts.lora(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                // Imagen mantenida
                const SizedBox(width: 16),
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(15), // Radio un poco más suave
                  child: imagenPath != null
                      ? Image.network(
                          imagenPath,
                          width: 80, // Un poco más grande
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey)),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[200],
                          child:
                              const Icon(Icons.wine_bar, color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBarAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _filtrar,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(
                10), // Padding para que el icono no toque los bordes
            decoration: BoxDecoration(
              color: Colors.grey.shade100, // Color de fondo gris claro
              shape: BoxShape.circle, // Forma circular
            ),
            child: InkWell(
              // InkWell para el efecto de splash al pulsar (opcional)
              onTap: () {
                _mostrarMenuFiltros(context);
              },
              customBorder:
                  const CircleBorder(), // Asegura que el splash sea circular
              child: const Icon(
                Icons.sort,
                color: Colors.black54,
                size: 24, // Tamaño del icono
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- NUEVOS WIDGETS PARA FAVORITOS Y HEADER ---

  Widget _buildFavoritosSection() {
    // Datos mockeados para la visualización
    final favoritos = [
      {'nombre': 'Merseguera', 'imagen': 'assets/icons/Propiedad2=hoja.png'},
      {'nombre': 'Trepadell', 'imagen': 'assets/icons/Propiedad2=racimo.png'},
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151B18), // Dark green/black background
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.favorite_border, color: Colors.white70, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Favoritos",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Text(
                "${_listaFavoritos.length}",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180, // Altura fija para el scroll horizontal
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _listaFavoritos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _buildFavoritoCard(_listaFavoritos[index]);
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFavoritoCard(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () {
        // Al tocar la carta entera, vamos al detalle
        // Necesitamos el objeto completo de la variedad.
        // Como item ya tiene lo básico (id, nombre, imagen...),
        // intentamos buscar el objeto completo en _variedades para tener descripción, etc.
        final variedadCompleta = _variedades.firstWhere(
            (v) => v['id'] == item['id'],
            orElse: () => item); // Si no está, usamos lo que tenemos

        setState(() {
          _variedadSeleccionada = variedadCompleta;
        });
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: InkWell(
                  onTap: () {
                    if (item['id'] != null) _toggleFavorito(item['id']);
                  },
                  child: const Icon(Icons.favorite,
                      color: Colors.redAccent, size: 18)),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item['imagen'] != null
                  ? Image.network(
                      item['imagen'],
                      height: 80,
                      width: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.wine_bar,
                          size: 50, color: Colors.grey),
                    )
                  : const Icon(Icons.wine_bar, size: 50, color: Colors.grey),
            ),
            Text(
              item['nombre'] ?? 'Sin nombre',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionGroupCard(Map<String, dynamic> item) {
    // Buscamos cuántas tienes
    final nombre = item['nombre'];
    final cantidad = _mapaVariedadesUsuario[nombre]?.length ?? 0;
    final bool isBlanca = item['tipo'] == 'Blanca';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        // Usamos Container para borde personalizado si se quiere
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade900),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Navegación interna (Master-Detail)
            setState(() {
              _grupoColeccionSeleccionado = item;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header con Corazón (Visual)
                      Row(
                        children: [
                          const Spacer(),
                          // Usamos lógica real tmb aquí si tenemos el ID de variedad
                          // Nota: item es un grupo, pero item['variedad_original']['id_variedad'] o item['id']...
                          // Revisemos _cargarColeccionBackend:
                          // 'variedad_original': variedadData (que tiene id_variedad)
                          // item['variedad_original']['id_variedad']
                          InkWell(
                            onTap: () {
                              // Necesitamos el ID de la variedad REAL, no de la colección
                              // En _cargarColeccionBackend guardamos 'variedad_original'
                              final mapVariedad = item['variedad_original'];
                              if (mapVariedad != null &&
                                  mapVariedad['id_variedad'] != null) {
                                _toggleFavorito(mapVariedad['id_variedad']);
                              }
                            },
                            child: Icon(
                                (item['variedad_original'] != null &&
                                        _favoritosIds.contains(
                                            item['variedad_original']
                                                ['id_variedad']))
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 24,
                                color: (item['variedad_original'] != null &&
                                        _favoritosIds.contains(
                                            item['variedad_original']
                                                ['id_variedad']))
                                    ? Colors.redAccent
                                    : Colors.black54),
                          ),
                        ],
                      ),
                      Text(
                        nombre,
                        style: GoogleFonts.lora(
                          fontSize: 28,
                          fontWeight: FontWeight.w400, // Letra estilo display
                          color: const Color(0xFF1E2623),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isBlanca
                              ? const Color(0xFF8B8000).withOpacity(0.8)
                              : const Color(0xFF800020)
                                  .withOpacity(0.8), // Gold/Burgundy
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item['tipo'], // "Blanca" / "Tinta"
                          style: GoogleFonts.lora(
                              // Consistent font
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (cantidad > 1) ...[
                        const SizedBox(height: 10),
                        Text("$cantidad capturas",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12))
                      ]
                    ],
                  ),
                ),
                // Imagen (NUEVO)
                const SizedBox(width: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: item['imagen'] != null
                      ? _buildImageWidget(
                          item['imagen']) // Helper or direct image
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[200],
                          child:
                              const Icon(Icons.wine_bar, color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper para manejar URLs vs Archivos Locales (ya que colección puede tener ambos)
  Widget _buildImageWidget(String path) {
    if (path.startsWith('http')) {
      return Image.network(path,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(
              width: 80,
              height: 80,
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image)));
    } else {
      return Image.file(File(path),
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(
              width: 80,
              height: 80,
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image)));
    }
  }

  Widget _buildAddCollectionCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GestureDetector(
        onTap: _abrirCamara,
        child: Container(
          height: 120, // Altura discreta pero suficiente
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.grey.shade300, style: BorderStyle.solid),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo, color: Colors.grey.shade600, size: 30),
                const SizedBox(height: 8),
                Text(
                  "Añadir Variedad",
                  style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // 1. SI HAY UNA VARIEDAD SELECCIONADA, MOSTRAMOS SU DETALLE (Dentro del Scaffold padre)
    if (_variedadSeleccionada != null) {
      final id = _variedadSeleccionada!['id'];
      final bool esFav = id != null && _favoritosIds.contains(id);

      // Usamos un WillPopScope (o PopScope) para manejar el botón físico de atrás de Android
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          setState(() => _variedadSeleccionada = null);
          _cargarFavoritosBackend(); // Refrescar por si cambió
        },
        child: DetalleVariedadPage(
          variedad: _variedadSeleccionada!,
          isFavoritoInicial: esFav,
          onBack: () {
            setState(() => _variedadSeleccionada = null);
            _cargarFavoritosBackend(); // Refrescar por si cambió
          },
        ),
      );
    }

    // 2. SI HAY UN GRUPO DE COLECCIÓN SELECCIONADO
    if (_grupoColeccionSeleccionado != null) {
      final nombre = _grupoColeccionSeleccionado!['nombre'];
      final listaCapturas = _mapaVariedadesUsuario[nombre] ?? [];

      final idVar = _grupoColeccionSeleccionado!['variedad_original'] != null
          ? _grupoColeccionSeleccionado!['variedad_original']['id_variedad']
          : null;
      final bool esFav = idVar != null && _favoritosIds.contains(idVar);

      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          setState(() => _grupoColeccionSeleccionado = null);
          _cargarColeccionBackend(); // Refrescar al volver
          _cargarFavoritosBackend();
        },
        child: UserVarietyDetailPage(
          varietyInfo: _grupoColeccionSeleccionado!,
          captures: listaCapturas,
          isFavoritoInicial: esFav,
          onBack: () {
            setState(() => _grupoColeccionSeleccionado = null);
            _cargarColeccionBackend();
            _cargarFavoritosBackend();
          },
        ),
      );
    }

    // Un header personalizado en lugar de AppBar
    return Scaffold(
      backgroundColor: Colors.white, // Fondo general
      body: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: Column(
          children: [
            // 1. HEADER PERSONALIZADO
            VitiaHeader(
              title: "Biblioteca",
              actionIcon: IconButton(
                icon: Icon(_showSearch ? Icons.close : Icons.search, size: 28),
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      _currentSort = 'az';
                      _currentFilterColor = 'all';
                      _filtrar('');
                    }
                  });
                },
              ),
            ),

            // 2. TABS PERSONALIZADOS (Pills)
            Container(
              margin: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 8), // Más margen lateral
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2), // Gris clarito específico
                borderRadius: BorderRadius.circular(30),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ],
                ),
                labelColor: Colors.black87,
                unselectedLabelColor: Colors.grey.shade500,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                splashBorderRadius: BorderRadius.circular(30),
                padding: const EdgeInsets.all(
                    5), // Espacio interno para que el indicador "flote"
                tabs: const [
                  Tab(text: "Todas"),
                  Tab(text: "Tus variedades"),
                ],
              ),
            ),
            // 3. BUSCADOR ANIMADO (FLOTANTE/VISIBLE AL SCROLLEAR)
            // 3. BUSCADOR ANIMADO (FLOTANTE/VISIBLE AL SCROLLEAR)
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: SizedBox(
                  height: _showSearch ? null : 0,
                  width: double.infinity,
                  child: _showSearch
                      ? _buildSearchBarAndFilters()
                      : const SizedBox.shrink(),
                ),
              ),
            ),

            // 4. CONTENIDO (TabBarView con Scroll único para la primera pestaña)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // --- PESTAÑA 1: TODAS ---
                  CustomScrollView(
                    slivers: [
                      // 1. Buscador y Filtros (ELIMINADO DE AQUÍ)

                      // 2. Sección Favoritos (scrollea con la página)
                      SliverToBoxAdapter(
                        child: _buildFavoritosSection(),
                      ),

                      // Buscador y Título "Todas las variedades"
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // _buildSearchBarAndFilters() moved up
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0, vertical: 12.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Todas las variedades (${_filtradas.length})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Lista de Variedades
                      _filtradas.isEmpty
                          ? SliverFillRemaining(
                              child: Center(
                                child: _isLoading
                                    ? const CircularProgressIndicator()
                                    : const Text(
                                        "No se encontraron variedades"),
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  return _buildVarietyCard(_filtradas[index]);
                                },
                                childCount: _filtradas.length,
                              ),
                            ),

                      // Espacio final
                      // Espacio final aumentado para navbar flotante
                      const SliverToBoxAdapter(child: SizedBox(height: 160)),
                    ],
                  ),

                  // --- PESTAÑA 2: COLECCIÓN (Igual que antes) ---
                  UserSession.token == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Inicia sesión para ver tu colección"),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                  onPressed: () {}, // Navegar login
                                  child: const Text("Ir a Login"))
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // _buildSearchBarAndFilters(), // ELIMINADO DE AQUÍ (Ya está arriba)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0, vertical: 12.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Mis variedades (${_filtradasColeccion.length})",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey),
                                ),
                              ),
                            ),
                            Expanded(
                              child: _filtradasColeccion.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.wine_bar,
                                              size: 50, color: Colors.grey),
                                          const SizedBox(height: 10),
                                          const Text(
                                              'Tu colección está vacía.'),
                                          TextButton(
                                            onPressed: _abrirCamara,
                                            child: const Text(
                                                '¡Escanea tu primera variedad!'),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding:
                                          const EdgeInsets.only(bottom: 150),
                                      itemCount: _filtradasColeccion.length + 1,
                                      itemBuilder: (context, index) {
                                        if (index ==
                                            _filtradasColeccion.length) {
                                          return _buildAddCollectionCard();
                                        }
                                        return _buildCollectionGroupCard(
                                            _filtradasColeccion[index]);
                                      },
                                    ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
