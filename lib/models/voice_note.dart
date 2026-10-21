enum VoiceNoteStatus { queued, processing, done, error }

enum VoiceSummaryStatus { requested, processing, done, error }

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
  final VoiceSummaryStatus? summaryStatus;
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
      summaryStatus: json['summary_status'] == null
          ? null
          : VoiceSummaryStatus.values.firstWhere(
              (s) => s.name == json['summary_status'],
              orElse: () => VoiceSummaryStatus.requested,
            ),
      recordedAt: DateTime.parse(json['recorded_at']),
    );
  }

  /// Summary lines ("- item" / "- [ ] item") as plain todo titles.
  List<String> get summaryItems {
    final items = <String>[];
    for (final raw in (summary ?? '').split('\n')) {
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
