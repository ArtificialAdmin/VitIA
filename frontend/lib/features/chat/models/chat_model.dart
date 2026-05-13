class ChatMessage {
  final int idMessage;
  final int idRoom;
  final int idSender;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  ChatMessage({
    required this.idMessage,
    required this.idRoom,
    required this.idSender,
    required this.content,
    required this.createdAt,
    required this.isRead,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      idMessage: json['id_message'],
      idRoom: json['id_room'],
      idSender: json['id_sender'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      isRead: json['is_read'] ?? false,
    );
  }
}

class ChatRoom {
  final int idRoom;
  final int idUser1;
  final int idUser2;
  final DateTime createdAt;
  final String? otherUserName;
  final String? otherUserAvatar;
  final ChatMessage? lastMessage;

  ChatRoom({
    required this.idRoom,
    required this.idUser1,
    required this.idUser2,
    required this.createdAt,
    this.otherUserName,
    this.otherUserAvatar,
    this.lastMessage,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      idRoom: json['id_room'],
      idUser1: json['id_user1'],
      idUser2: json['id_user2'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      otherUserName: json['other_user_name'],
      otherUserAvatar: json['other_user_avatar'],
      lastMessage: json['last_message'] != null
          ? ChatMessage.fromJson(json['last_message'])
          : null,
    );
  }
}
