class ShoppingItem {
  final String id;
  final String userId;
  final String item;
  final bool isPurchased;

  /// Gasto created when the item was marked as purchased.
  final String? purchaseId;
  final DateTime? purchasedAt;
  final DateTime? createdAt;

  ShoppingItem({
    required this.id,
    required this.userId,
    required this.item,
    this.isPurchased = false,
    this.purchaseId,
    this.purchasedAt,
    this.createdAt,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'],
      userId: json['user_id'],
      item: json['item'] ?? '',
      isPurchased: json['is_purchased'] ?? false,
      purchaseId: json['purchase_id'],
      purchasedAt: json['purchased_at'] != null
          ? DateTime.tryParse(json['purchased_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}
