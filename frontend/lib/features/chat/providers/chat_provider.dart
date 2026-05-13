import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:vinas_mobile/core/providers.dart';
import 'package:vinas_mobile/core/api_config.dart';
import 'package:vinas_mobile/features/chat/models/chat_model.dart';

class ChatState {
  final bool isLoading;
  final List<ChatMessage> messages;
  final String? error;

  ChatState({this.isLoading = false, this.messages = const [], this.error});

  ChatState copyWith({bool? isLoading, List<ChatMessage>? messages, String? error}) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      error: error,
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

    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _connectWebSocket() {
    if (_currentRoomId == null || _currentUserId == null) return;
    
    // Replace http:// with ws://
    final wsBaseUrl = getBaseUrl().replaceFirst('http', 'ws');
    final wsUrl = Uri.parse('$wsBaseUrl/ws/chat/$_currentRoomId?user_id=$_currentUserId');
    
    _channel = WebSocketChannel.connect(wsUrl);

    _channel!.stream.listen((message) {
      final decoded = jsonDecode(message);
      final newMessage = ChatMessage.fromJson(decoded);
      
      // Insert at beginning because ListView is reversed
      state = state.copyWith(messages: [newMessage, ...state.messages]);
    }, onError: (error) {
      // Handle reconnect or show error
      print("WS Error: $error");
    }, onDone: () {
      print("WS Closed");
    });
  }

  void sendMessage(String content) {
    if (_channel != null && content.isNotEmpty) {
      _channel!.sink.add(jsonEncode({'content': content}));
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider.autoDispose<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
