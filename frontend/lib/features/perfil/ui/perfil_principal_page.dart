// lib/pages/main_layout/perfil_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinas_mobile/shared/components/loading_indicator.dart';
import 'package:vinas_mobile/features/auth/services/auth_session_service.dart';
import 'package:vinas_mobile/features/auth/ui/auth_login_page.dart';
import 'edit_profile_page.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/features/experto/ui/validaciones_page.dart';
import 'package:vinas_mobile/features/experto/ui/anotacion_dataset_page.dart';
import 'package:vinas_mobile/features/chat/ui/chat_room_page.dart';
import 'package:vinas_mobile/features/foro/ui/foro_post_detalle_page.dart';
import 'package:vinas_mobile/features/experto/ui/validacion_detalle_page.dart';

class PerfilPrincipalPage extends ConsumerStatefulWidget {
  const PerfilPrincipalPage({super.key});

  @override
  ConsumerState<PerfilPrincipalPage> createState() => _PerfilPrincipalPageState();
}

class _PerfilPrincipalPageState extends ConsumerState<PerfilPrincipalPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _nombreUser = "";
  String? _userPhotoUrl; // Variable para foto
  String _rolUser = "usuario"; // Nuevo estado para el rol
  bool _profileUpdated = false;
  bool _isLoading = true;
  bool _isLoadingNotifs = false;
  int _pendingCount = 0;
  int _tabIndex = 0; // 0 = Ajustes, 1 = Notificaciones
  List<dynamic> _notificaciones = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _tabIndex = _tabController.index;
      });
      if (_tabIndex == 1 && _notificaciones.isEmpty) {
        _fetchNotificaciones();
      }
    });
    _loadProfileHeader();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileHeader() async {
    try {
      final userData = await ref.read(apiProvider).getMe();
      if (mounted) {
        setState(() {
          _nombreUser = "${userData['nombre']} ${userData['apellidos']}";
          _userPhotoUrl = userData['path_foto_perfil'];
          _rolUser = userData['rol'] ?? "usuario";
        });
        
        if (_rolUser == 'experto' || _rolUser == 'admin') {
          _fetchPendingCount();
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchPendingCount() async {
    try {
      final count = await ref.read(apiProvider).getValidacionesPendientesCount();
      if (mounted) {
        setState(() {
          _pendingCount = count;
        });
      }
    } catch (e) {
      debugPrint("Error fetching pending count: $e");
    }
  }

  Future<void> _deleteNotification(int id) async {
    try {
      await ref.read(apiProvider).deleteNotification(id);
      setState(() {
        _notificaciones.removeWhere((n) => n['id_notification'] == id);
      });
    } catch (e) {
      debugPrint("Error deleting notification: $e");
    }
  }

  Future<void> _deleteAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Borrar todas?"),
        content: const Text("¿Estás seguro de que quieres eliminar todas las notificaciones? Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Borrar todas"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(apiProvider).deleteAllNotifications();
      setState(() {
        _notificaciones.clear();
      });
    } catch (e) {
      debugPrint("Error deleting all notifications: $e");
    }
  }

  Future<void> _fetchNotificaciones() async {
    setState(() {
      _isLoadingNotifs = true;
    });
    try {
      final notifs = await ref.read(apiProvider).getMyNotifications();
      
      List<dynamic> groupedNotifs = [];
      Map<int, int> chatIndices = {};

      for (var n in notifs) {
        if (n['type'] == 'chat' && n['related_id'] != null) {
          int roomId = n['related_id'];
          if (chatIndices.containsKey(roomId)) {
             int idx = chatIndices[roomId]!;
             var group = Map<String, dynamic>.from(groupedNotifs[idx]);
             int count = (group['count'] ?? 1) + 1;
             group['count'] = count;
             group['body'] = "Tienes $count mensajes sin revisar en este chat";
             if (n['is_read'] == false) group['is_read'] = false;
             groupedNotifs[idx] = group;
          } else {
             var newN = Map<String, dynamic>.from(n);
             newN['count'] = 1;
             groupedNotifs.add(newN);
             chatIndices[roomId] = groupedNotifs.length - 1;
          }
        } else {
          groupedNotifs.add(n);
        }
      }

      if (mounted) {
        setState(() {
          _notificaciones = groupedNotifs;
        });
        // Mark as read after fetching
        await ref.read(apiProvider).markNotificationsAsRead();
      }
    } catch (e) {
      debugPrint("Error fetching notifs: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingNotifs = false;
        });
      }
    }
  }


  void _handleNotificationClick(Map<String, dynamic> notif) async {
    final type = notif['type'];
    final relatedIdStr = notif['related_id']?.toString();
    
    debugPrint("Notification clicked: type=$type, related_id=$relatedIdStr");

    if (relatedIdStr == null) {
      debugPrint("No related_id found for notification");
      return;
    }
    final relatedId = int.tryParse(relatedIdStr);
    if (relatedId == null) {
      debugPrint("Could not parse related_id: $relatedIdStr");
      return;
    }

    // Marcar como leída visualmente de inmediato
    if (notif['is_read'] == false) {
       setState(() {
         notif['is_read'] = true;
       });
    }

    // Mostrar feedback de carga
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Abriendo..."), duration: Duration(milliseconds: 500)),
    );

    try {
      if (type == 'chat') {
        final rooms = await ref.read(apiProvider).getMyChatRooms();
        final room = rooms.firstWhere((r) => r['id_room'] == relatedId, orElse: () => null);
        
        if (room != null && mounted) {
          final myUserId = ref.read(userIdProvider);
          if (myUserId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatRoomPage(
                  roomId: relatedId,
                  myUserId: myUserId,
                  otherUserName: room['other_user_name'] ?? "Chat",
                  otherUserAvatar: room['other_user_avatar'],
                ),
              ),
            );
          }
        } else {
          throw "No se encontró la sala de chat";
        }
      } else if (type == 'forum') {
        final post = await ref.read(apiProvider).getPublicacion(relatedId);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ForoPostDetallePage(post: post),
            ),
          );
        }
      } else if (type == 'validation') {
        final val = await ref.read(apiProvider).getValidacion(relatedId);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ValidacionDetallePage(validacion: val),
            ),
          );
        }
      } else {
        debugPrint("Unknown notification type: $type");
      }
    } catch (e) {
      debugPrint("Error navigating from notification: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo abrir el contenido: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void logout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que quieres cerrar la sesión?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.black54)),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Cerrar Sesión',
                  style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await ref.read(apiProvider).logout();
      await AuthSessionService.clearSession();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthLoginPage()),
        (route) => false,
      );
    }
  }

  Widget _buildProfileCard(
      {required String title,
      required String subtitle,
      required Function() onTap,
      Color? textColor,
      int badgeCount = 0}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black26),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.ibmPlexSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor ?? Colors.black87),
                        ),
                        if (badgeCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              badgeCount > 99 ? "99+" : badgeCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ]
                      ],
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          subtitle,
                          style: GoogleFonts.ibmPlexSans(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_profileUpdated),
        ),
        title: Text("Perfil",
            style: GoogleFonts.lora(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (_isLoading)
              const LoadingIndicator()
            else ...[
              CircleAvatar(
                radius: 50,
                backgroundImage:
                    _userPhotoUrl != null ? NetworkImage(_userPhotoUrl!) : null,
                backgroundColor: Colors.grey.shade200,
                child: _userPhotoUrl == null
                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                    : null,
              ),
              const SizedBox(height: 15),
              Text(
                _nombreUser.isEmpty ? "Usuario" : _nombreUser,
                style: GoogleFonts.lora(fontSize: 28),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 10),

            // --- TABS (SLIDER ESTÁNDAR) ---
            Container(
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
                  Tab(text: "Ajustes"),
                  Tab(text: "Notificaciones"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_tabIndex == 0) ...[
              // --- VISTA DE AJUSTES ---

            _buildProfileCard(
              title: "Ajustes del perfil",
              subtitle: "Actualiza y modifica tu perfil",
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const EditProfilePage()),
                );
                if (result == true) {
                  _profileUpdated = true;
                  _loadProfileHeader();
                }
              },
            ),

            if (_rolUser == 'experto' || _rolUser == 'admin') ...[
              const SizedBox(height: 16),
              _buildProfileCard(
                title: "Validaciones Pendientes",
                subtitle: "Revisa las imágenes de la IA",
                textColor: const Color(0xFFD4AF37),
                badgeCount: _pendingCount,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ValidacionesPage()),
                  );
                  _fetchPendingCount();
                },
              ),
              const SizedBox(height: 12),
              _buildProfileCard(
                title: "Anotar Dataset Completo",
                subtitle: "Evalúa todas las imágenes del sistema",
                textColor: const Color(0xFF1E2623),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AnotacionDatasetPage()),
                  );
                  _fetchPendingCount();
                },
              ),
            ],

            const SizedBox(height: 20),

            GestureDetector(
              onTap: () => logout(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text("Cerrar sesión",
                      style: GoogleFonts.ibmPlexSans(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const SizedBox(height: 40),
            ] else ...[
              // --- VISTA DE NOTIFICACIONES ---
              _buildNotificacionesView(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificacionesView() {
    if (_isLoadingNotifs) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: LoadingIndicator(label: "Cargando notificaciones..."),
      );
    }

    if (_notificaciones.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.notifications_off_outlined, size: 64, color: Colors.black26),
              SizedBox(height: 16),
              Text("No tienes notificaciones", style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Notificaciones",
              style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _deleteAllNotifications,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.redAccent),
              label: const Text("Borrar todas", style: TextStyle(color: Colors.redAccent, fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _notificaciones.length,
          itemBuilder: (context, index) {
            final notif = _notificaciones[index];
            final id = notif['id_notification'];
            final isRead = notif['is_read'] ?? true;
            final title = notif['title'] ?? 'Notificación';
            final body = notif['body'] ?? '';
            final type = notif['type'] ?? 'general';

            IconData icon;
            Color iconColor;

            switch (type) {
              case 'chat':
                icon = Icons.chat_bubble;
                iconColor = const Color(0xFF7A2048); // Vino VitIA
                break;
              case 'forum':
                icon = Icons.forum;
                iconColor = Colors.blue;
                break;
              case 'validation':
                icon = Icons.verified;
                iconColor = const Color(0xFFD4AF37); // Dorado VitIA
                break;
              default:
                icon = Icons.notifications;
                iconColor = Colors.grey;
            }

            return Dismissible(
              key: Key("notif_$id"),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (direction) {
                _deleteNotification(id);
              },
              child: InkWell(
                onTap: () => _handleNotificationClick(notif),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.grey.shade200 : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isRead ? Colors.transparent : Colors.blue.shade300, width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: isRead ? Colors.grey.shade300 : iconColor.withOpacity(0.15),
                        child: Icon(icon, color: isRead ? Colors.grey.shade600 : iconColor, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(body, style: TextStyle(color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
