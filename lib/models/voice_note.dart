enum VoiceNoteStatus { queued, processing, done, error }

/// State of a Claude task on a note (summary, shopping list, expenses,
/// pantry),
/// each in its own `*_status` column.
enum VoiceTaskStatus { requested, processing, done, error }

/// The Claude tasks the worker runs on request, by status column.
enum VoiceTask {
  summary('summary_status'),
  shopping('shopping_status'),
  expenses('expenses_status'),
  pantry('pantry_status');

  final String statusColumn;
  const VoiceTask(this.statusColumn);
}

/// Language picked on the recorder; WhisperX and the local assistant use it.
enum VoiceLanguage {
  pt('PT', 'Português'),
  en('EN', 'English');

  final String short;
  final String label;
  const VoiceLanguage(this.short, this.label);

  static VoiceLanguage fromKey(Object? key) =>
      values.firstWhere((l) => l.name == key, orElse: () => pt);
}

/// Where the local assistant (transcriber/agent.py) is on a note.
/// requested: will run; processing: running; done: finished (see
/// [VoiceNote.agentActions]); apply: the app confirmed/undid actions and
/// the worker is carrying that out; error: e.g. the local model is down.
enum VoiceAgentStatus { requested, processing, done, apply, error }

/// One action the local assistant took (or proposes) for a note.
class VoiceAgentAction {
  final String id;
  final String tool;
  final String summary;
  final double confidence;

  /// Why it needs confirmation ("confiança 0.60; data no passado").
  final String? reason;

  /// done | pending | confirmed | discarded | undo | undone | error
  final String status;
  final String? error;

  /// The rest of the stored object (args, rows), written back untouched.
  final Map<String, dynamic> raw;

  VoiceAgentAction({
    required this.id,
    required this.tool,
    required this.summary,
    required this.confidence,
    this.reason,
    required this.status,
    this.error,
    required this.raw,
  });

  factory VoiceAgentAction.fromJson(Map<String, dynamic> json) {
    return VoiceAgentAction(
      id: json['id']?.toString() ?? '',
      tool: json['tool'] ?? '',
      summary: json['summary'] ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      reason: json['reason'],
      status: json['status'] ?? 'pending',
      error: json['error'],
      raw: json,
    );
  }

  bool get isDone => status == 'done';
  bool get isPending => status == 'pending';

  /// Waiting for the worker after the app confirmed or undid it.
  bool get isApplying => status == 'confirmed' || status == 'undo';

  Map<String, dynamic> toJsonWithStatus(String newStatus) =>
      {...raw, 'status': newStatus};
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

/// An ingredient the worker saved from a "what's in the kitchen" note
/// (also a row in pantry_items).
class PantryEntry {
  final String nome;
  final String? quantidade;

  PantryEntry({required this.nome, this.quantidade});

  factory PantryEntry.fromJson(Map<String, dynamic> json) =>
      PantryEntry(nome: json['nome'] ?? '', quantidade: json['quantidade']);
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
  final List<PantryEntry> pantry;
  final VoiceTaskStatus? pantryStatus;
  final DateTime recordedAt;
  final VoiceLanguage language;
  final VoiceAgentStatus? agentStatus;
  final List<VoiceAgentAction> agentActions;

  /// The app already showed the snackbar/dialog for the agent's result.
  final bool agentNotified;

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
    this.pantry = const [],
    this.pantryStatus,
    required this.recordedAt,
    this.language = VoiceLanguage.pt,
    this.agentStatus,
    this.agentActions = const [],
    this.agentNotified = true,
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
      pantry: [
        for (final e in (json['pantry'] as List?) ?? const [])
          PantryEntry.fromJson(Map<String, dynamic>.from(e)),
      ],
      pantryStatus: _taskStatus(json['pantry_status']),
      recordedAt: DateTime.parse(json['recorded_at']),
      // Absent before migration 046: Portuguese, no assistant.
      language: VoiceLanguage.fromKey(json['language']),
      agentStatus: json['agent_status'] == null
          ? null
          : VoiceAgentStatus.values.firstWhere(
              (s) => s.name == json['agent_status'],
              orElse: () => VoiceAgentStatus.done,
            ),
      agentActions: [
        for (final a in (json['agent_actions'] as List?) ?? const [])
          VoiceAgentAction.fromJson(Map<String, dynamic>.from(a)),
      ],
      agentNotified: json['agent_notified'] ?? true,
    );
  }

  /// The assistant finished and the app hasn't told the user yet.
  bool get agentNeedsNotice =>
      agentStatus == VoiceAgentStatus.done &&
      !agentNotified &&
      agentActions.isNotEmpty;

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
        VoiceTask.pantry => pantryStatus,
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
  final VoiceLanguage language;

  PendingVoiceUpload({
    required this.id,
    required this.filePath,
    required this.durationSeconds,
    required this.recordedAt,
    this.language = VoiceLanguage.pt,
  });

  factory PendingVoiceUpload.fromDb(Map<String, dynamic> row) {
    return PendingVoiceUpload(
      id: row['id'] as String,
      filePath: row['file_path'] as String,
      durationSeconds: row['duration_seconds'] as int,
      recordedAt: DateTime.parse(row['recorded_at'] as String),
      language: VoiceLanguage.fromKey(row['language']),
    );
  }
}
