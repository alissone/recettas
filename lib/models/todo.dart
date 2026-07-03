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

  Map<String, dynamic> toDb() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'is_completed': isCompleted ? 1 : 0,
        'category_id': categoryId,
        'sort_order': sortOrder,
        'created_at': createdAt?.toIso8601String(),
      };

  factory Todo.fromDb(Map<String, dynamic> row) {
    return Todo(
      id: row['id'],
      userId: row['user_id'],
      title: row['title'],
      isCompleted: (row['is_completed'] ?? 0) != 0,
      categoryId: row['category_id'],
      sortOrder: row['sort_order'] ?? 0,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'])
          : null,
    );
  }
}
