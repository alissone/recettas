enum ReceiptJobStatus { queued, processing, done, error }

class ReceiptJob {
  final String id;
  final String userId;
  final String imagePath;
  final ReceiptJobStatus status;
  final String? errorMessage;
  final int? itemsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ReceiptJob({
    required this.id,
    required this.userId,
    required this.imagePath,
    required this.status,
    this.errorMessage,
    this.itemsCount,
    this.createdAt,
    this.updatedAt,
  });

  factory ReceiptJob.fromJson(Map<String, dynamic> json) {
    return ReceiptJob(
      id: json['id'],
      userId: json['user_id'],
      imagePath: json['image_path'],
      status: ReceiptJobStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ReceiptJobStatus.queued,
      ),
      errorMessage: json['error_message'],
      itemsCount: json['items_count'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }
}
