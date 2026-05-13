import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vinas_mobile/features/chat/providers/chat_provider.dart';
import 'package:vinas_mobile/shared/styles/app_theme.dart';
import 'package:vinas_mobile/shared/components/loading_indicator.dart';
import 'package:intl/intl.dart';

class ChatRoomPage extends ConsumerStatefulWidget {
  final int roomId;
  final int myUserId;
  final String otherUserName;
  final String? otherUserAvatar;

  const ChatRoomPage({
    super.key,
    required this.roomId,
    required this.myUserId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize chat asynchronously after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).initChat(widget.roomId, widget.myUserId);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      ref.read(chatProvider.notifier).sendMessage(text);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.vinoVitIA,
              backgroundImage: widget.otherUserAvatar != null
                  ? NetworkImage(widget.otherUserAvatar!)
                  : null,
              child: widget.otherUserAvatar == null
                  ? const Icon(Icons.person, color: Colors.white, size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.otherUserName,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.isLoading
                ? const LoadingIndicator(label: "Cargando mensajes...")
                : chatState.error != null
                    ? Center(child: Text("Error: ${chatState.error}"))
                    : chatState.messages.isEmpty
                        ? const Center(child: Text("No hay mensajes aún. ¡Escribe el primero!", style: TextStyle(color: Colors.black54)))
                        : ListView.builder(
                            reverse: true, // Newest messages at the bottom
                            padding: const EdgeInsets.all(16),
                            itemCount: chatState.messages.length,
                            itemBuilder: (context, index) {
                              final msg = chatState.messages[index];
                              final isMe = msg.idSender == widget.myUserId;

                              return Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isMe ? AppColors.vinoVitIA : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isMe ? 16 : 0),
                                      bottomRight: Radius.circular(isMe ? 0 : 16),
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg.content,
                                        style: TextStyle(
                                          color: isMe ? Colors.white : Colors.black87,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('HH:mm').format(msg.createdAt),
                                        style: TextStyle(
                                          color: isMe ? Colors.white70 : Colors.black45,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          
          // Input Area
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Escribe un mensaje...",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.vinoVitIA,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
