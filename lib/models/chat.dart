/// One-to-one conversation between two e-mail addresses (migration 031).
/// The pair is what identifies the room - the other side doesn't need an
/// account yet, and the room outlives any change to either profile.
class ChatRoom {
  final String id;
  final String? createdBy;

  /// Both members, lowercased and sorted by the database.
  final List<String> memberEmails;

  /// Newest message, denormalized onto the room so the inbox renders
  /// without a query per row.
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderEmail;
  final DateTime? updatedAt;

  /// Partner's display name, resolved separately from `profiles` - null
  /// until they sign up, in which case the UI falls back to the address.
  final String? partnerName;

  ChatRoom({
    required this.id,
    this.createdBy,
    required this.memberEmails,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSenderEmail,
    this.updatedAt,
    this.partnerName,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'],
      createdBy: json['created_by'],
      memberEmails: (json['member_emails'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      lastMessage: json['last_message'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'])?.toLocal()
          : null,
      lastSenderEmail: json['last_sender_email'],
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])?.toLocal()
          : null,
    );
  }

  ChatRoom withPartnerName(String? name) => ChatRoom(
        id: id,
        createdBy: createdBy,
        memberEmails: memberEmails,
        lastMessage: lastMessage,
        lastMessageAt: lastMessageAt,
        lastSenderEmail: lastSenderEmail,
        updatedAt: updatedAt,
        partnerName: name,
      );

  /// The member who isn't [myEmail]. Falls back to the first address so
  /// a malformed row still renders something.
  String partnerEmail(String myEmail) {
    final me = myEmail.toLowerCase();
    return memberEmails.firstWhere(
      (e) => e != me,
      orElse: () => memberEmails.isEmpty ? '' : memberEmails.first,
    );
  }

  /// What the inbox row and the chat header are titled.
  String partnerLabel(String myEmail) {
    final name = partnerName;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return partnerEmail(myEmail);
  }

  /// Sort key: rooms with no messages yet fall back to their creation
  /// bump, so a freshly opened room lands at the top.
  DateTime get sortTime =>
      lastMessageAt ?? updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

class ChatMessage {
  final String id;
  final String roomId;
  final String? senderId;
  final String senderEmail;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.roomId,
    this.senderId,
    required this.senderEmail,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      roomId: json['room_id'],
      senderId: json['sender_id'],
      senderEmail: (json['sender_email'] ?? '').toString(),
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  bool isMine(String myEmail) =>
      senderEmail.toLowerCase() == myEmail.toLowerCase();
}
