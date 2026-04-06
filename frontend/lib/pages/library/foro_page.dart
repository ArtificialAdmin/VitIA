import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/forum_provider.dart';
import '../../core/services/user_sesion.dart';
import 'post_detail_page.dart';
import 'create_post_page.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/vitia_header.dart';

class ForoPage extends ConsumerStatefulWidget {
  const ForoPage({super.key});

  @override
  ConsumerState<ForoPage> createState() => _ForoPageState();
}

class _ForoPageState extends ConsumerState<ForoPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _currentSort = 'newest';
  bool _isCreatingPost = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _cargarDatos() {
    ref.read(forumProvider.notifier).reload();
  }

  List<Map<String, dynamic>> _filterByText(List<Map<String, dynamic>> list) {
    if (_searchQuery.isEmpty) return list;
    final query = _searchQuery.toLowerCase();
    return list.where((post) {
      final title = post['titulo'].toString().toLowerCase();
      final content = post['text'].toString().toLowerCase();
      final user = post['user'].toString().toLowerCase();
      return title.contains(query) ||
          content.contains(query) ||
          user.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredList(List<Map<String, dynamic>> list) {
    List<Map<String, dynamic>> temp = _filterByText(list);

    switch (_currentSort) {
      case 'oldest':
        temp = List.from(temp.reversed);
        break;
      case 'likes':
        temp.sort((a, b) => (b['likes'] as int).compareTo(a['likes'] as int));
        break;
      case 'comments':
        temp.sort(
            (a, b) => (b['comments'] as int).compareTo(a['comments'] as int));
        break;
      case 'author':
        temp.sort(
            (a, b) => a['user'].toString().compareTo(b['user'].toString()));
        break;
      default:
        break;
    }
    return temp;
  }

  void _mostrarDialogoCrear() {
    if (UserSession.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Debes iniciar sesión para publicar.")));
      return;
    }
    setState(() => _isCreatingPost = true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _mostrarMenuFiltros(BuildContext context) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return StatefulBuilder(builder: (ctx, setModalState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  top: 24.0,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Ordenar por",
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Listo",
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text("Fecha",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: [
                        _buildFilterChip("Más Nuevos", 'newest', setModalState),
                        _buildFilterChip(
                            "Más Antiguos", 'oldest', setModalState),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text("Interacción",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: [
                        _buildFilterChip(
                            "Más Gustados", 'likes', setModalState),
                        _buildFilterChip(
                            "Más Comentados", 'comments', setModalState),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text("Otros",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: [
                        _buildFilterChip(
                            "Autor (A-Z)", 'author', setModalState),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          });
        });
  }

  Widget _buildFilterChip(
      String label, String value, StateSetter setModalState) {
    final isSelected = _currentSort == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.black,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      onSelected: (bool selected) {
        if (selected) {
          setModalState(() => _currentSort = value);
          setState(() {});
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final forumState = ref.watch(forumProvider);

    return PopScope(
      canPop: !_isCreatingPost,
      onPopInvoked: (didPop) {
        if (didPop) return;
        setState(() => _isCreatingPost = false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: Column(
                children: [
                  VitiaHeader(
                    title: "Comunidad",
                    actionIcon: IconButton(
                      icon: Icon(_isSearching ? Icons.close : Icons.search,
                          size: 28),
                      onPressed: () {
                        setState(() {
                          if (_isSearching) {
                            _isSearching = false;
                            _searchQuery = "";
                            _searchController.clear();
                          } else {
                            _isSearching = true;
                          }
                        });
                      },
                    ),
                  ),
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
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
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                      splashBorderRadius: BorderRadius.circular(30),
                      padding: const EdgeInsets.all(5),
                      tabs: const [
                        Tab(text: "Todos"),
                        Tab(text: "Tus hilos"),
                      ],
                    ),
                  ),
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: SizedBox(
                        height: _isSearching ? null : 0,
                        width: double.infinity,
                        child: _isSearching
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20.0, vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        onChanged: (value) {
                                          setState(() {
                                            _searchQuery = value;
                                          });
                                        },
                                        autofocus: true,
                                        decoration: InputDecoration(
                                          hintText: "Buscar...",
                                          prefixIcon: const Icon(Icons.search,
                                              color: Colors.grey),
                                          filled: true,
                                          fillColor: Colors.grey.shade200,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(30),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 20),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        shape: BoxShape.circle,
                                      ),
                                      child: InkWell(
                                        onTap: () =>
                                            _mostrarMenuFiltros(context),
                                        customBorder: const CircleBorder(),
                                        child: const Icon(Icons.sort,
                                            color: Colors.black54),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: forumState.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text("Error: $err")),
                      data: (allPosts) {
                        final popularPosts = ref.watch(popularPostsProvider);
                        final myPosts = ref.watch(myPostsProvider);

                        return TabBarView(
                          controller: _tabController,
                          children: [
                            RefreshIndicator(
                              onRefresh: () async =>
                                  ref.read(forumProvider.notifier).reload(),
                              child: CustomScrollView(
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          20, 10, 20, 10),
                                      child: Text("Populares",
                                          style: GoogleFonts.lora(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF2A2A2A))),
                                    ),
                                  ),
                                  SliverToBoxAdapter(
                                    child: SizedBox(
                                      height: 180,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        itemCount: _filterByText(popularPosts)
                                            .take(5)
                                            .length,
                                        itemBuilder: (context, index) {
                                          final filteredPop =
                                              _filterByText(popularPosts);
                                          return _PopularCard(
                                            post: filteredPop[index],
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        PostDetailPage(
                                                            post: filteredPop[
                                                                index])),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          20, 20, 20, 10),
                                      child: Text("Recientes",
                                          style: GoogleFonts.lora(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF2A2A2A))),
                                    ),
                                  ),
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final filteredAll =
                                            _getFilteredList(allPosts);
                                        return _RecentCard(
                                          post: filteredAll[index],
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      PostDetailPage(
                                                          post: filteredAll[
                                                              index])),
                                            );
                                          },
                                        );
                                      },
                                      childCount:
                                          _getFilteredList(allPosts).length,
                                    ),
                                  ),
                                  const SliverToBoxAdapter(
                                      child: SizedBox(height: 160)),
                                ],
                              ),
                            ),
                            RefreshIndicator(
                              onRefresh: () async =>
                                  ref.read(forumProvider.notifier).reload(),
                              child: CustomScrollView(
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          20, 20, 20, 10),
                                      child: Text("Tus publicaciones",
                                          style: GoogleFonts.lora(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF2A2A2A))),
                                    ),
                                  ),
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final filteredMine =
                                            _getFilteredList(myPosts);
                                        return _RecentCard(
                                          post: filteredMine[index],
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      PostDetailPage(
                                                          post: filteredMine[
                                                              index])),
                                            );
                                          },
                                        );
                                      },
                                      childCount:
                                          _getFilteredList(myPosts).length,
                                    ),
                                  ),
                                  const SliverToBoxAdapter(
                                      child: SizedBox(height: 160)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (!_isCreatingPost)
              Positioned(
                bottom: 110,
                left: 20,
                right: 20,
                child: ElevatedButton(
                  onPressed: _mostrarDialogoCrear,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7A7A30),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                    elevation: 4,
                    shadowColor: const Color(0xFF7A7A30).withOpacity(0.4),
                  ),
                  child: const Text("Crear hilo",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            if (_isCreatingPost)
              Positioned.fill(
                child: Container(
                    color: Colors.white,
                    child: CreatePostPage(
                      onPostCreated: () {
                        setState(() => _isCreatingPost = false);
                        _cargarDatos();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text("¡Publicación creada exitosamente!")));
                      },
                      onCancel: () {
                        setState(() => _isCreatingPost = false);
                      },
                    )),
              ),
          ],
        ),
      ),
    );
  }
}

class _PopularCard extends ConsumerWidget {
  final Map<String, dynamic> post;
  final VoidCallback onTap;

  const _PopularCard({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = post['isLiked'] ?? false;
    final likes = post['likes'] ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        margin: const EdgeInsets.only(right: 16, bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: post['avatar'] != null
                      ? NetworkImage(post['avatar'])
                      : null,
                  child: post['avatar'] == null
                      ? const Icon(Icons.person, color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post['user'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(post['time'],
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            if (post['titulo'] != null && post['titulo'] != '') ...[
              Text(
                post['titulo'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
            ],
            Expanded(
              child: Text(
                post['text'],
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.grey.shade800, fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      ref.read(forumProvider.notifier).toggleLike(post['id']),
                  child: Row(
                    children: [
                      Text("$likes",
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 16, color: isLiked ? Colors.red : Colors.grey),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text("${post['comments']}",
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Icon(Icons.chat_bubble_outline,
                    size: 16, color: Colors.grey),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _RecentCard extends ConsumerWidget {
  final Map<String, dynamic> post;
  final VoidCallback onTap;

  const _RecentCard({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = post['isLiked'] ?? false;
    final likes = post['likes'] ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.brown.shade100,
                  backgroundImage: post['avatar'] != null
                      ? NetworkImage(post['avatar'])
                      : null,
                  child: post['avatar'] == null
                      ? const Icon(Icons.person, color: Colors.brown)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post['user'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(post['time'],
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (post['titulo'] != null && post['titulo'] != '') ...[
              Text(
                post['titulo'],
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18, height: 1.2),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              post['text'],
              style: TextStyle(
                  color: Colors.grey.shade800, fontSize: 14, height: 1.5),
            ),
            if (post['image'] != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post['image'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      ref.read(forumProvider.notifier).toggleLike(post['id']),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isLiked
                          ? Colors.red.withOpacity(0.1)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: isLiked ? Colors.red : Colors.grey),
                        const SizedBox(width: 6),
                        Text("$likes",
                            style: TextStyle(
                              color: isLiked ? Colors.red : Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text("${post['comments']}",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
