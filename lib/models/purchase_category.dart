import 'category_base.dart';

/// "Importância" of a purchase. Mirrors TodoCategory but lives in its
/// own table (purchase_categories).
class PurchaseCategory extends CategoryBase {
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

  const PurchaseCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.colorValue,
    this.createdAt,
  });

  factory PurchaseCategory.fromJson(Map<String, dynamic> json) {
    return PurchaseCategory(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      colorValue: json['color_value'] ?? 0xFFFF8C42,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}
