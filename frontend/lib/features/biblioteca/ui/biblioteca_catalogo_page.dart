import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

import 'package:vinas_mobile/core/api_config.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/shared/widgets/vitia_header.dart';
import 'package:vinas_mobile/features/biblioteca/ui/biblioteca_variedad_detalle_page.dart';
import 'package:vinas_mobile/features/coleccion/ui/coleccion_variedad_detalle_page.dart';
import 'package:vinas_mobile/features/coleccion/ui/coleccion_captura_page.dart';

class BibliotecaCatalogoPage extends ConsumerStatefulWidget {
  final int initialTab;
  final VoidCallback? onCameraTap;

  const BibliotecaCatalogoPage({
    super.key, 
    this.initialTab = 0, 
    this.onCameraTap,
  });

  @override
  ConsumerState<BibliotecaCatalogoPage> createState() => _BibliotecaCatalogoPageState();
}

class _BibliotecaCatalogoPageState extends ConsumerState<BibliotecaCatalogoPage>
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _variedades = [];
  List<Map<String, dynamic>> _filtradas = [];
  List<Map<String, dynamic>> _listaFavoritos = [];
  Set<int> _favoritosIds = {};

  List<Map<String, dynamic>> _filtradasColeccion = [];
  Map<String, List<Map<String, dynamic>>> _mapaVariedadesUsuario = {};

  bool _isLoading = true;
  bool _showSearch = false;
  String _currentFilterColor = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.index = widget.initialTab;
    
    // Cargamos los datos iniciales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarTodo();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _cargarVariedadesBackend(),
        _cargarColeccionBackend(),
        _cargarFavoritosBackend(),
      ]);
    } catch (e) {
      debugPrint("Error al cargar datos iniciales: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarVariedadesBackend() async {
    final api = ref.read(apiProvider);
    try {
      final lista = await api.getVariedades();
      if (mounted) {
        setState(() {
          _variedades = lista.map((v) {
            final map = Map<String, dynamic>.from(v);
            // Mapeamos links_imagenes a imagen si existe
            if (map['imagen'] == null &&
                map['links_imagenes'] != null &&
                (map['links_imagenes'] as List).isNotEmpty) {
              map['imagen'] = (map['links_imagenes'] as List).first;
            }
            return map;
          }).toList();
          _filtrar(_searchController.text);
        });
      }
    } catch (e) {
      debugPrint("Error loading varieties: $e");
    }
  }

  Future<void> _cargarFavoritosBackend() async {
    final api = ref.read(apiProvider);
    try {
      final lista = await api.getFavorites();
      if (mounted) {
        setState(() {
          _listaFavoritos = lista.map((v) {
            final map = Map<String, dynamic>.from(v);
            if (map['imagen'] == null &&
                map['links_imagenes'] != null &&
                (map['links_imagenes'] as List).isNotEmpty) {
              map['imagen'] = (map['links_imagenes'] as List).first;
            }
            return map;
          }).toList();
          _favoritosIds = _listaFavoritos
              .map((v) => (v['id'] ?? v['id_variedad']) as int)
              .toSet();
        });
      }
    } catch (e) {
      debugPrint("Error loading favorites: $e");
    }
  }

  Future<void> _cargarColeccionBackend() async {
    final api = ref.read(apiProvider);
    try {
      final lista = await api.getCollection();
      if (mounted) {
        final List<Map<String, dynamic>> items = lista.map((item) {
          final variedadData = item['variedad'] ?? {};
          return {
            'id': item['id_coleccion'],
            'nombre': variedadData['nombre'] ?? 'Sin nombre',
            'notas': item['notas'],
            'tipo': variedadData['color'] ?? 'Personal',
            'imagen': item['path_foto_usuario'],
            'fecha_captura': item['fecha_captura'],
            'latitud': item['latitud'],
            'longitud': item['longitud'],
            'fotos_premium': item['fotos_premium'],
            'analisis_ia': item['analisis_ia'],
            'es_premium': item['es_premium'] ?? false,
            'variedad_original': variedadData,
          };
        }).toList();

        final Map<String, List<Map<String, dynamic>>> agrupado = {};
        for (var item in items) {
          final nombre = item['nombre'];
          agrupado.putIfAbsent(nombre, () => []).add(item);
        }

        setState(() {
          _mapaVariedadesUsuario = agrupado;
          _filtradasColeccion = agrupado.keys.map((nombre) => agrupado[nombre]![0]).toList();
        });
      }
    } catch (e) {
      debugPrint("Library collection error: $e");
    }
  }

  void _filtrar(String query) {
    setState(() {
      _filtradas = _variedades.where((v) {
        final matchesQuery = v['nombre'].toLowerCase().contains(query.toLowerCase());
        final matchesColor = _currentFilterColor == 'all' || 
                           v['tipo'].toString().toLowerCase() == _currentFilterColor;
        return matchesQuery && matchesColor;
      }).toList();
    });
  }

  void _toggleFavorito(int idVariedad) async {
    final api = ref.read(apiProvider);
    try {
      await api.toggleFavorite(idVariedad);
      _cargarFavoritosBackend();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al actualizar favorito")));
    }
  }

  void _abrirCamara() {
    if (widget.onCameraTap != null) {
      widget.onCameraTap!();
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ColeccionCapturaPage())).then((_) => _cargarTodo());
    }
  }

  // --- WIDGET BUILDERS ---

  Widget _buildFavoritosSection() {
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
            height: 180,
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
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BibliotecaVariedadDetallePage(
              variedad: item,
              isFavoritoInicial: true,
              onBack: () {
                _cargarFavoritosBackend();
                Navigator.pop(context);
              },
            ),
          ),
        );
        _cargarFavoritosBackend();
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
                    final id = item['id'] ?? item['id_variedad'];
                    if (id != null) _toggleFavorito(id);
                  },
                  child: const Icon(Icons.favorite,
                      color: Colors.redAccent, size: 18)),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _buildImage(item['imagen'], size: 80),
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

  Widget _buildVarietyCard(Map<String, dynamic> variedad) {
    final int idVar = variedad['id'] ?? variedad['id_variedad'];
    final bool esFav = _favoritosIds.contains(idVar);
    final bool isBlanca = variedad['tipo'] == 'Blanca';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade900),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BibliotecaVariedadDetallePage(
                    variedad: variedad,
                    isFavoritoInicial: esFav,
                    onBack: () {
                      _cargarFavoritosBackend();
                      Navigator.pop(context);
                    }),
              ),
            );
            _cargarFavoritosBackend();
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
                          InkWell(
                            onTap: () => _toggleFavorito(idVar),
                            child: Icon(
                                esFav ? Icons.favorite : Icons.favorite_border,
                                size: 24,
                                color: esFav ? Colors.redAccent : Colors.black54),
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
                      // Pill de Tipo
                      _buildColorBadge(variedad['tipo']),
                    ],
                  ),
                ),
                // Imagen a la DERECHA
                const SizedBox(width: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _buildImage(variedad['imagen'], size: 80),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionGroupCard(Map<String, dynamic> item) {
    final String nombre = item['nombre'] ?? '';
    final int cantidad = _mapaVariedadesUsuario[nombre]?.length ?? 0;
    final originalVar = item['variedad_original'] ?? {};
    final int idVar = originalVar['id_variedad'] ?? 0;
    final bool esFav = _favoritosIds.contains(idVar);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade900),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ColeccionVariedadDetallePage(
                  varietyInfo: item,
                  captures: _mapaVariedadesUsuario[nombre] ?? [],
                  isFavoritoInicial: esFav,
                  onBack: () {
                    _cargarFavoritosBackend();
                    Navigator.pop(context);
                  },
                ),
              ),
            );
            _cargarColeccionBackend();
            _cargarFavoritosBackend();
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
                      // Header con Corazón
                      Row(
                        children: [
                          const Spacer(),
                          InkWell(
                            onTap: () => _toggleFavorito(idVar),
                            child: Icon(
                                esFav ? Icons.favorite : Icons.favorite_border,
                                size: 24,
                                color: esFav ? Colors.redAccent : Colors.black54),
                          ),
                        ],
                      ),
                      Text(
                        nombre,
                        style: GoogleFonts.lora(
                          fontSize: 28,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF1E2623),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildColorBadge(originalVar['color']),
                      if (cantidad > 0) ...[
                        const SizedBox(height: 10),
                        Text("$cantidad capturas",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12))
                      ]
                    ],
                  ),
                ),
                // Imagen a la DERECHA
                const SizedBox(width: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _buildImage(item['imagen'], size: 80),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddCollectionCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: _abrirCamara,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.grey.shade100,
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  "Agregar nueva variedad",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorBadge(String? tipo) {
    final String label = (tipo == null || tipo.isEmpty) ? "Desconocido" : tipo;
    final bool isBlanca = label.toLowerCase() == 'blanca';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isBlanca
            ? const Color(0xFF8B8000).withOpacity(0.8)
            : const Color(0xFF800020).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.lora(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildImage(String? path, {double size = 100}) {
    if (path == null || path.isEmpty) {
      return Container(
          width: size,
          height: size,
          color: Colors.grey.shade200,
          child: Icon(Icons.wine_bar, color: Colors.grey, size: size * 0.5));
    }

    ImageProvider img;
    String resolvedPath = path;

    if (path.startsWith('http')) {
      img = NetworkImage(path);
    } else if (path.startsWith('assets/') || path.startsWith('icons/')) {
      // Si empieza por icons/, asumimos que es un asset
      if (path.startsWith('icons/')) resolvedPath = 'assets/$path';
      img = AssetImage(resolvedPath);
    } else {
      // Si no es un asset conocido ni http, puede ser una ruta relativa del server o un archivo local
      if (path.contains('cache') || path.contains('data/user')) {
        img = FileImage(File(path));
      } else {
        // Fallback: intentar cargarlo desde el backend si no parece ruta de archivo
        final baseUrl = getBaseUrl();
        final fullUrl = path.startsWith('/') ? "$baseUrl$path" : "$baseUrl/$path";
        img = NetworkImage(fullUrl);
      }
    }

    return Image(
      image: img,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) {
        // Segundo intento: si falló como Network/File, probar como Asset por si acaso
        return Image.asset(
          'assets/icons/Propiedad1=uva.png', // Fallback a icono genérico de uva
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (c2, e2, s2) => Container(
            width: size,
            height: size,
            color: Colors.grey.shade200,
            child: Icon(Icons.broken_image, color: Colors.grey, size: size * 0.5),
          ),
        );
      },
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sort,
              color: Colors.black54,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: SafeArea(
        bottom: false, // Evitamos el borde blanco inferior
        child: Column(
          children: [
            VitiaHeader(
              title: "Biblioteca",
              actionIcon: IconButton(
                icon: Icon(_showSearch ? Icons.close : Icons.search, size: 28),
                onPressed: () => setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchController.clear();
                    _filtrar("");
                  }
                }),
              ),
            ),
            
            // TABS
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              height: 50,
              decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(30)),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                labelColor: Colors.black87,
                unselectedLabelColor: Colors.grey.shade500,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                splashBorderRadius: BorderRadius.circular(30),
                padding: const EdgeInsets.all(5),
                tabs: const [Tab(text: "Todas"), Tab(text: "Tus variedades")],
              ),
            ),

            // SEARCH BAR ANIMATED
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: SizedBox(
                  height: _showSearch ? null : 0,
                  width: double.infinity,
                  child: _showSearch ? _buildSearchBarAndFilters() : const SizedBox.shrink(),
                ),
              ),
            ),

            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: TODAS
                      CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(child: _buildFavoritosSection()),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                              child: Text('Todas las variedades (${_filtradas.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            ),
                          ),
                          _filtradas.isEmpty
                            ? const SliverFillRemaining(child: Center(child: Text("No se encontraron variedades")))
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _buildVarietyCard(_filtradas[index]),
                                  childCount: _filtradas.length,
                                ),
                              ),
                          const SliverToBoxAdapter(child: SizedBox(height: 100)),
                        ],
                      ),

                      // TAB 2: COLECCION
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text("Mis variedades (${_filtradasColeccion.length})", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            ),
                          ),
                          Expanded(
                            child: _filtradasColeccion.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.wine_bar, size: 50, color: Colors.grey),
                                      const SizedBox(height: 10),
                                      const Text('Tu colección está vacía.'),
                                      TextButton(onPressed: _abrirCamara, child: const Text('¡Escanea tu primera variedad!')),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 150),
                                  itemCount: _filtradasColeccion.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == _filtradasColeccion.length) {
                                      return _buildAddCollectionCard();
                                    }
                                    return _buildCollectionGroupCard(_filtradasColeccion[index]);
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
