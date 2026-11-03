/// One entry of the shared clipboard (table clipboard_items, migration 043).
enum ClipboardKind { text, image }

class ClipboardItem {
  final String id;
  final ClipboardKind kind;

  /// The text, for [ClipboardKind.text].
  final String? content;

  /// Object path in the "clipboard" bucket, for [ClipboardKind.image].
  final String? storagePath;
  final String? mimeType;
  final int? sizeBytes;
  final DateTime createdAt;

  const ClipboardItem({
    required this.id,
    required this.kind,
    this.content,
    this.storagePath,
    this.mimeType,
    this.sizeBytes,
    required this.createdAt,
  });

  bool get isImage => kind == ClipboardKind.image;

  factory ClipboardItem.fromJson(Map<String, dynamic> json) => ClipboardItem(
        id: json['id'] as String,
        kind: json['kind'] == 'image' ? ClipboardKind.image : ClipboardKind.text,
        content: json['content'] as String?,
        storagePath: json['storage_path'] as String?,
        mimeType: json['mime_type'] as String?,
        sizeBytes: (json['size_bytes'] as num?)?.toInt(),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
      );
}
