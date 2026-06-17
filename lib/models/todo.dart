class Todo {
  final String id;
  final String userId;
  final String title;
  final bool isCompleted;
  final String? categoryId;
  final int sortOrder;
  final DateTime? createdAt;

  Todo({
    required this.id,
    required this.userId,
    required this.title,
    this.isCompleted = false,
    this.categoryId,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      isCompleted: json['is_completed'] ?? false,
      categoryId: json['category_id'],
      sortOrder: json['sort_order'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}
