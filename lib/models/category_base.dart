import 'package:flutter/material.dart';

/// Shared shape for user-defined categories (todo categories and
/// purchase "Importância" categories) so screens can work with either.
abstract class CategoryBase {
  const CategoryBase();

  String get id;
  String get userId;
  String get name;
  int get colorValue;
  DateTime? get createdAt;

  Color get color => Color(colorValue);

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
