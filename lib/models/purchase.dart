class Purchase {
  final String id;
  final String userId;

  /// Data in YYYY-MM-DD format (matches the `date` column).
  final String purchaseDate;
  final String item;

  /// Valor in BRL.
  final double valor;
  final String? local;

  /// Importância (purchase category).
  final String? categoryId;
  final String? receiptJobId;
  final DateTime? createdAt;

  Purchase({
    required this.id,
    required this.userId,
    required this.purchaseDate,
    required this.item,
    required this.valor,
    this.local,
    this.categoryId,
    this.receiptJobId,
    this.createdAt,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['id'],
      userId: json['user_id'],
      purchaseDate: json['purchase_date'] ?? '',
      item: json['item'] ?? '',
      valor: double.tryParse(json['valor'].toString()) ?? 0,
      local: json['local'],
      categoryId: json['category_id'],
      receiptJobId: json['receipt_job_id'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}
