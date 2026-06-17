class Todo {
  final String id;
  final String userId;
  final String title;
  final bool isCompleted;
  final DateTime? createdAt;

  Todo({
    required this.id,
    required this.userId,
    required this.title,
    this.isCompleted = false,
    this.createdAt,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      isCompleted: json['is_completed'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}
