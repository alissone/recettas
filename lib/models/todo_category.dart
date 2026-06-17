import 'package:flutter/material.dart';

class TodoCategory {
  final String id;
  final String userId;
  final String name;
  final int colorValue;
  final DateTime? createdAt;

  TodoCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.colorValue,
    this.createdAt,
  });

  Color get color => Color(colorValue);

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

  static const List<int> presetColors = [
    0xFFE57373,
    0xFFFF8C42,
    0xFFFFB74D,
    0xFF81C784,
    0xFF4DB6AC,
    0xFF64B5F6,
    0xFFBA68C8,
    0xFFF06292,
  ];
}
