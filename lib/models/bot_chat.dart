/// A conversation with the local assistant (migration 047). Private to
/// its owner; the replies are written by the PC worker
/// (transcriber/bot_chat.py).
class BotChat {
  final String id;
  final String title;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  /// 'user' or 'assistant': who sent [lastMessage].
  final String? lastRole;
  final DateTime? updatedAt;

  BotChat({
    required this.id,
    required this.title,
    this.lastMessage,
    this.lastMessageAt,
    this.lastRole,
    this.updatedAt,
  });

  factory BotChat.fromJson(Map<String, dynamic> json) => BotChat(
        id: json['id'],
        title: (json['title'] ?? 'Assistente').toString(),
        lastMessage: json['last_message'],
        lastMessageAt: _time(json['last_message_at']),
        lastRole: json['last_role'],
        updatedAt: _time(json['updated_at']),
      );

  /// Same rule as ChatRoom.sortTime, so both kinds sort together.
  DateTime get sortTime =>
      lastMessageAt ?? updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

class BotMessage {
  final String id;
  final String chatId;

  /// 'user' or 'assistant'.
  final String role;
  final String content;

  /// Data the app attached for the model (e.g. the todo list); not shown
  /// in the bubble.
  final String? context;

  /// User messages only: requested -> processing -> done | error.
  final String? status;
  final String? errorMessage;
  final DateTime createdAt;

  BotMessage({
    required this.id,
    required this.chatId,
    required this.role,
    required this.content,
    this.context,
    this.status,
    this.errorMessage,
    required this.createdAt,
  });

  factory BotMessage.fromJson(Map<String, dynamic> json) => BotMessage(
        id: json['id'],
        chatId: json['chat_id'],
        role: (json['role'] ?? 'user').toString(),
        content: (json['content'] ?? '').toString(),
        context: json['context'],
        status: json['status'],
        errorMessage: json['error_message'],
        createdAt: _time(json['created_at']) ?? DateTime.now(),
      );

  bool get isMine => role == 'user';
  bool get isWaiting => status == 'requested' || status == 'processing';
  bool get hasContext => (context ?? '').trim().isNotEmpty;
}

DateTime? _time(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
