enum CloudFileEventKind { upload, download }

/// One upload or download of a file, with the device that did it.
class CloudFileEvent {
  final CloudFileEventKind kind;
  final String deviceName;
  final DateTime at;

  CloudFileEvent({
    required this.kind,
    required this.deviceName,
    required this.at,
  });

  factory CloudFileEvent.fromJson(Map<String, dynamic> json) {
    return CloudFileEvent(
      kind: CloudFileEventKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => CloudFileEventKind.download,
      ),
      deviceName: json['device_name'] ?? '',
      at: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}

/// A file in the "Arquivos" drive (cloud_files row).
class CloudFile {
  final String id;
  final String name;
  final int sizeBytes;
  final String? mimeType;
  final String storagePath;
  final DateTime createdAt;

  CloudFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    this.mimeType,
    required this.storagePath,
    required this.createdAt,
  });

  factory CloudFile.fromJson(Map<String, dynamic> json) {
    return CloudFile(
      id: json['id'],
      name: json['name'],
      sizeBytes: (json['size_bytes'] as num).toInt(),
      mimeType: json['mime_type'],
      storagePath: json['storage_path'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }

  /// Lowercase extension without the dot ("pdf"), or '' if there is none.
  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  /// Short label for the type column: "PDF", "TXT", or "Arquivo".
  String get typeLabel =>
      extension.isEmpty ? 'Arquivo' : extension.toUpperCase();

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Finder-style time buckets for the file list, newest first.
class CloudFileGroup {
  final String title;
  final List<CloudFile> files;

  CloudFileGroup(this.title, this.files);

  /// Groups [files] (any order) as Finder does: Hoje, Ontem, Últimos 7
  /// dias, Últimos 30 dias, then one group per month of the current year
  /// and one per year before that. Files within a group are newest first.
  static List<CloudFileGroup> group(List<CloudFile> files, DateTime now) {
    const monthNames = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    final today = DateTime(now.year, now.month, now.day);
    final sorted = [...files]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final groups = <CloudFileGroup>[];

    String titleFor(DateTime t) {
      final day = DateTime(t.year, t.month, t.day);
      final days = today.difference(day).inDays;
      if (days <= 0) return 'Hoje';
      if (days == 1) return 'Ontem';
      if (days <= 7) return 'Últimos 7 dias';
      if (days <= 30) return 'Últimos 30 dias';
      if (t.year == now.year) return monthNames[t.month - 1];
      return '${t.year}';
    }

    for (final file in sorted) {
      final title = titleFor(file.createdAt);
      if (groups.isEmpty || groups.last.title != title) {
        groups.add(CloudFileGroup(title, []));
      }
      groups.last.files.add(file);
    }
    return groups;
  }
}
