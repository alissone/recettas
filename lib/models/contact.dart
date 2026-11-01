/// Someone in the user's "Pessoas" list: an email plus the nickname
/// typed after "@" to tag them on a todo. The nickname is private to the
/// owner of the contact; it never changes anything on the other account.
class Contact {
  final String id;
  final String ownerId;
  final String email;
  final String nickname;

  /// The account behind [email]; null while that email hasn't signed up,
  /// in which case tagging this contact doesn't share anything.
  final String? contactUserId;
  final DateTime? createdAt;

  Contact({
    required this.id,
    required this.ownerId,
    required this.email,
    required this.nickname,
    this.contactUserId,
    this.createdAt,
  });

  bool get hasAccount => contactUserId != null;

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      ownerId: json['owner_id'],
      email: json['email'] ?? '',
      nickname: json['nickname'] ?? '',
      contactUserId: json['contact_user_id'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toDb() => {
        'id': id,
        'owner_id': ownerId,
        'email': email,
        'nickname': nickname,
        'contact_user_id': contactUserId,
        'created_at': createdAt?.toIso8601String(),
      };

  factory Contact.fromDb(Map<String, dynamic> row) {
    return Contact(
      id: row['id'],
      ownerId: row['owner_id'],
      email: row['email'],
      nickname: row['nickname'],
      contactUserId: row['contact_user_id'],
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'])
          : null,
    );
  }
}
