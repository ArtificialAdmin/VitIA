import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/shared/styles/app_theme.dart';
import 'package:vinas_mobile/features/chat/models/chat_model.dart';
import 'chat_room_page.dart';
import 'package:intl/intl.dart';

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  bool _isLoading = true;
  List<ChatRoom> _rooms = [];

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    setState(() => _isLoading = true);
    try {
      final rawData = await ref.read(apiProvider).getMyChatRooms();
      if (mounted) {
        setState(() {
          _rooms = (rawData as List).map((json) => ChatRoom.fromJson(json)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al cargar chats: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text("Mensajes", style: GoogleFonts.lora(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 80, color: Colors.black12),
                      SizedBox(height: 16),
                      Text("No tienes chats activos", style: TextStyle(color: Colors.black54, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchRooms,
                  child: ListView.builder(
                    itemCount: _rooms.length,
                    itemBuilder: (context, index) {
                      final room = _rooms[index];
                      final myUserId = ref.read(userIdProvider) ?? 0;
                      
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.vinoVitIA.withValues(alpha: 0.1),
                          backgroundImage: room.otherUserAvatar != null ? NetworkImage(room.otherUserAvatar!) : null,
                          child: room.otherUserAvatar == null ? const Icon(Icons.person, color: AppColors.vinoVitIA) : null,
                        ),
                        title: Text(room.otherUserName ?? "Usuario", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          room.lastMessage != null ? room.lastMessage!.content : "Sin mensajes",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (room.lastMessage != null)
                              Text(
                                DateFormat('HH:mm').format(room.lastMessage!.createdAt),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            if (room.lastMessage != null && !room.lastMessage!.isRead && room.lastMessage!.idSender != myUserId)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                              ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatRoomPage(
                                roomId: room.idRoom,
                                myUserId: myUserId,
                                otherUserName: room.otherUserName ?? "Usuario",
                                otherUserAvatar: room.otherUserAvatar,
                              ),
                            ),
                          );
                          // Recargar al volver por si hay nuevos mensajes
                          _fetchRooms();
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
