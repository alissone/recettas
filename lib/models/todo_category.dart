import 'category_base.dart';

class TodoCategory extends CategoryBase {
  @override
  final String id;
  @override
  final String userId;
  @override
  final String name;
  @override
  final int colorValue;
  @override
  final DateTime? createdAt;

  const TodoCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.colorValue,
    this.createdAt,
  });

  factory TodoCategory.fromJson(Map<String, dynamic> json) {
    return TodoCategory(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      colorValue: json['color_value'] ?? 0xFFFF8C42,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toDb() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'color_value': colorValue,
        'created_at': createdAt?.toIso8601String(),
      };

  factory TodoCategory.fromDb(Map<String, dynamic> row) {
    return TodoCategory(
      id: row['id'],
      userId: row['user_id'],
      name: row['name'],
      colorValue: row['color_value'] ?? 0xFFFF8C42,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'])
          : null,
    );
  }

  static const List<int> presetColors = CategoryBase.presetColors;
}
