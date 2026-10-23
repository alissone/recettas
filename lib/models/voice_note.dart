enum VoiceNoteStatus { queued, processing, done, error }

/// State of a Claude task on a note (summary, shopping list, expenses),
/// each in its own `*_status` column.
enum VoiceTaskStatus { requested, processing, done, error }

/// The Claude tasks the worker runs on request, by status column.
enum VoiceTask {
  summary('summary_status'),
  shopping('shopping_status'),
  expenses('expenses_status');

  final String statusColumn;
  const VoiceTask(this.statusColumn);
}

/// A purchase the worker extracted from a note and inserted into Gastos.
class VoiceExpense {
  final String item;
  final double valor;
  final String? local;

  /// YYYY-MM-DD; the recording day unless another date was mentioned.
  final String data;
  final String? categoria;

  VoiceExpense({
    required this.item,
    required this.valor,
    this.local,
    required this.data,
    this.categoria,
  });

  factory VoiceExpense.fromJson(Map<String, dynamic> json) {
    return VoiceExpense(
      item: json['item'] ?? '',
      valor: (json['valor'] as num?)?.toDouble() ?? 0,
      local: json['local'],
      data: json['data'] ?? '',
      categoria: json['categoria'],
    );
  }
}

/// A voice note on the server, transcribed by the local WhisperX worker
/// (transcriber/worker.py).
class VoiceNote {
  final String id;
  final String? audioPath;
  final int? durationSeconds;
  final VoiceNoteStatus status;
  final String? errorMessage;
  final String? transcript;
  final String? summary;
  final VoiceTaskStatus? summaryStatus;
  final String? shopping;
  final VoiceTaskStatus? shoppingStatus;
  final List<VoiceExpense> expenses;
  final VoiceTaskStatus? expensesStatus;
  final DateTime recordedAt;

  VoiceNote({
    required this.id,
    this.audioPath,
    this.durationSeconds,
    required this.status,
    this.errorMessage,
    this.transcript,
    this.summary,
    this.summaryStatus,
    this.shopping,
    this.shoppingStatus,
    this.expenses = const [],
    this.expensesStatus,
    required this.recordedAt,
  });

  factory VoiceNote.fromJson(Map<String, dynamic> json) {
    return VoiceNote(
      id: json['id'],
      audioPath: json['audio_path'],
      durationSeconds: json['duration_seconds'],
      status: VoiceNoteStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => VoiceNoteStatus.queued,
      ),
      errorMessage: json['error_message'],
      transcript: json['transcript'],
      summary: json['summary'],
      summaryStatus: _taskStatus(json['summary_status']),
      shopping: json['shopping'],
      shoppingStatus: _taskStatus(json['shopping_status']),
      expenses: [
        for (final e in (json['expenses'] as List?) ?? const [])
          VoiceExpense.fromJson(Map<String, dynamic>.from(e)),
      ],
      expensesStatus: _taskStatus(json['expenses_status']),
      recordedAt: DateTime.parse(json['recorded_at']),
    );
  }

  static VoiceTaskStatus? _taskStatus(Object? value) => value == null
      ? null
      : VoiceTaskStatus.values.firstWhere(
          (s) => s.name == value,
          orElse: () => VoiceTaskStatus.requested,
        );

  VoiceTaskStatus? statusOf(VoiceTask task) => switch (task) {
        VoiceTask.summary => summaryStatus,
        VoiceTask.shopping => shoppingStatus,
        VoiceTask.expenses => expensesStatus,
      };

  /// Summary lines ("- item" / "- [ ] item") as plain todo titles.
  List<String> get summaryItems => _bullets(summary);

  /// Shopping list lines as plain item names.
  List<String> get shoppingItems => _bullets(shopping);

  static List<String> _bullets(String? text) {
    final items = <String>[];
    for (final raw in (text ?? '').split('\n')) {
      var line = raw.trim();
      if (!line.startsWith('- ') && !line.startsWith('* ')) continue;
      line = line.substring(2).trim();
      if (line.startsWith('[ ] ') || line.startsWith('[x] ')) {
        line = line.substring(4).trim();
      }
      if (line.isNotEmpty) items.add(line);
    }
    return items;
  }
}

/// A recording still waiting on this device to be uploaded.
class PendingVoiceUpload {
  final String id;
  final String filePath;
  final int durationSeconds;
  final DateTime recordedAt;

  PendingVoiceUpload({
    required this.id,
    required this.filePath,
    required this.durationSeconds,
    required this.recordedAt,
  });

  factory PendingVoiceUpload.fromDb(Map<String, dynamic> row) {
    return PendingVoiceUpload(
      id: row['id'] as String,
      filePath: row['file_path'] as String,
      durationSeconds: row['duration_seconds'] as int,
      recordedAt: DateTime.parse(row['recorded_at'] as String),
    );
  }
}
