import 'package:dio/dio.dart';

class ChatService {
  final Dio _dio;

  ChatService(this._dio);

  // --- NOTIFICACIONES ---

  Future<List<dynamic>> getMyNotifications() async {
    final response = await _dio.get('/notifications');
    return response.data;
  }

  Future<void> markNotificationsAsRead() async {
    await _dio.post('/notifications/read');
  }

  // --- CHAT ROOMS ---

  Future<List<dynamic>> getMyChatRooms() async {
    final response = await _dio.get('/chat/rooms');
    return response.data;
  }

  Future<Map<String, dynamic>> getOrCreateChat(int otherUserId) async {
    final response = await _dio.post('/chat/rooms/$otherUserId');
    return response.data;
  }

  Future<List<dynamic>> getChatMessages(int roomId, {int skip = 0, int limit = 50}) async {
    final response = await _dio.get(
      '/chat/rooms/$roomId/messages',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    return response.data;
  }
}
