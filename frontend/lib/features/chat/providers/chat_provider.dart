import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:convert';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/core/api_config.dart';
import 'package:vinas_mobile/features/chat/models/chat_model.dart';

class ChatState {
  final bool isLoading;
  final List<ChatMessage> messages;
  final String? error;

  final bool isOtherUserOnline;

  ChatState({
    this.isLoading = false,
    this.messages = const [],
    this.error,
    this.isOtherUserOnline = false,
  });

  ChatState copyWith({
    bool? isLoading,
    List<ChatMessage>? messages,
    String? error,
    bool? isOtherUserOnline,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      error: error,
      isOtherUserOnline: isOtherUserOnline ?? this.isOtherUserOnline,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref ref;
  WebSocketChannel? _channel;
  int? _currentRoomId;
  int? _currentUserId;

  ChatNotifier(this.ref) : super(ChatState());

  Future<void> initChat(int roomId, int myUserId) async {
    _currentRoomId = roomId;
    _currentUserId = myUserId;
    
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 1. Fetch historical messages
      final api = ref.read(apiProvider);
      final rawMessages = await api.getChatMessages(roomId);
      final messages = (rawMessages as List).map((m) => ChatMessage.fromJson(m)).toList();
      
      // Riverpod state expects newest at top for ListView.builder(reverse: true) usually,
      // but let's just keep them as returned by the API (which is desc ordered, newest first).
      state = state.copyWith(isLoading: false, messages: messages);

      // 2. Connect WebSocket
      _connectWebSocket();

      // 3. Mark fetched messages as read (they will be broadcasted once connected)
      markVisibleMessagesAsRead();

    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _connectWebSocket() {
    if (_currentRoomId == null || _currentUserId == null) return;
    
    // Replace http:// with ws://
    final wsBaseUrl = getBaseUrl().replaceFirst('http', 'ws');
    final wsUrl = Uri.parse('$wsBaseUrl/ws/chat/$_currentRoomId?user_id=$_currentUserId');
    
    _channel = IOWebSocketChannel.connect(wsUrl, pingInterval: const Duration(seconds: 10));

    _channel!.stream.listen((message) {
      final decoded = jsonDecode(message);
      final msgType = decoded['type'] ?? 'chat_message';

      if (msgType == 'presence') {
        final userId = decoded['user_id'];
        final status = decoded['status'];
        if (userId != _currentUserId) {
          state = state.copyWith(isOtherUserOnline: status == 'online');
        }
      } 
      else if (msgType == 'read_receipt') {
        final msgId = decoded['id_message'];
        final currentList = state.messages.map((m) {
          if (m.idMessage == msgId) {
            return ChatMessage(
              idMessage: m.idMessage,
              idRoom: m.idRoom,
              idSender: m.idSender,
              content: m.content,
              createdAt: m.createdAt,
              isRead: true, // Marked as read!
            );
          }
          return m;
        }).toList();
        state = state.copyWith(messages: currentList);
      }
      else if (msgType == 'chat_message') {
        final newMessage = ChatMessage.fromJson(decoded);
        
        // Prevenir duplicados (si usamos update optimista)
        bool isDuplicate = false;
        final currentList = state.messages.map((m) {
          if (m.idSender == newMessage.idSender && m.content == newMessage.content && m.idMessage < 0) {
             isDuplicate = true;
             return newMessage; // Reemplazar el temporal por el real
          }
          return m;
        }).toList();

        if (!isDuplicate) {
          currentList.insert(0, newMessage);
        }
        
        state = state.copyWith(messages: currentList);

        // Si el mensaje es del otro usuario y estamos en la pantalla, enviar read_receipt
        if (newMessage.idSender != _currentUserId) {
           _sendReadReceipt(newMessage.idMessage);
        }
      }
    }, onError: (error) {
      print("WS Error: $error");
    }, onDone: () {
      print("WS Closed");
      // Reconexión automática simple tras 3 segundos si la pantalla sigue abierta
      if (_currentRoomId != null) {
         Future.delayed(const Duration(seconds: 3), () {
            if (_currentRoomId != null) _connectWebSocket();
         });
      }
    });
  }

  void sendMessage(String content) {
    if (_channel != null && content.isNotEmpty) {
      // Optimistic update
      final tempMessage = ChatMessage(
        idMessage: -DateTime.now().millisecondsSinceEpoch, // Temporal negativo
        idRoom: _currentRoomId!,
        idSender: _currentUserId!,
        content: content,
        createdAt: DateTime.now(),
        isRead: false,
      );
      state = state.copyWith(messages: [tempMessage, ...state.messages]);

      _channel!.sink.add(jsonEncode({'type': 'chat_message', 'content': content}));
    }
  }

  void _sendReadReceipt(int messageId) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'read_receipt',
        'id_message': messageId,
      }));
    }
  }

  void markVisibleMessagesAsRead() {
    // Al abrir el chat, marcamos los no leídos como leídos
    if (_channel == null || _currentUserId == null) return;
    
    bool hasChanges = false;
    final currentList = state.messages.map((m) {
       if (m.idSender != _currentUserId && !m.isRead) {
          hasChanges = true;
          _sendReadReceipt(m.idMessage);
          return ChatMessage(
            idMessage: m.idMessage,
            idRoom: m.idRoom,
            idSender: m.idSender,
            content: m.content,
            createdAt: m.createdAt,
            isRead: true,
          );
       }
       return m;
    }).toList();

    if (hasChanges) {
       state = state.copyWith(messages: currentList);
    }
  }

  @override
  void dispose() {
    _currentRoomId = null;
    _channel?.sink.close();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider.autoDispose<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
