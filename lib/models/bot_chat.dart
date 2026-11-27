/// A conversation with the local assistant (migration 047). Private to
/// its owner; the replies are written by the PC worker
/// (transcriber/bot_chat.py).
class BotChat {
  final String id;
  final String title;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  /// 'user' or 'assistant': who sent [lastMessage].
  final String? lastRole;
  final DateTime? updatedAt;

  /// Voice settings (migration 048): how spoken questions are transcribed
  /// and which Kokoro voice reads the answers.
  final SttEngine stt;
  final String ttsVoice;

  BotChat({
    required this.id,
    required this.title,
    this.lastMessage,
    this.lastMessageAt,
    this.lastRole,
    this.updatedAt,
    this.stt = SttEngine.parakeet,
    this.ttsVoice = KokoroVoice.defaultId,
  });

  factory BotChat.fromJson(Map<String, dynamic> json) => BotChat(
    id: json['id'],
    title: (json['title'] ?? 'Assistente').toString(),
    lastMessage: json['last_message'],
    lastMessageAt: _time(json['last_message_at']),
    lastRole: json['last_role'],
    updatedAt: _time(json['updated_at']),
    stt: SttEngine.from(json['stt_engine'], json['stt_language']),
    ttsVoice: (json['tts_voice'] ?? KokoroVoice.defaultId).toString(),
  );

  /// Same rule as ChatRoom.sortTime, so both kinds sort together.
  DateTime get sortTime =>
      lastMessageAt ?? updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

class BotMessage {
  final String id;
  final String chatId;

  /// 'user' or 'assistant'.
  final String role;
  final String content;

  /// Data the app attached for the model (e.g. the todo list); not shown
  /// in the bubble.
  final String? context;

  /// User messages only: requested -> processing -> done | error.
  final String? status;
  final String? errorMessage;
  final DateTime createdAt;

  /// Voice message (migration 048): path in the bot-audio bucket. For a
  /// user message [content] is the transcript, empty until the PC writes
  /// it; for a reply it is the text Kokoro read.
  final String? audioPath;
  final double? audioSeconds;

  BotMessage({
    required this.id,
    required this.chatId,
    required this.role,
    required this.content,
    this.context,
    this.status,
    this.errorMessage,
    required this.createdAt,
    this.audioPath,
    this.audioSeconds,
  });

  factory BotMessage.fromJson(Map<String, dynamic> json) => BotMessage(
    id: json['id'],
    chatId: json['chat_id'],
    role: (json['role'] ?? 'user').toString(),
    content: (json['content'] ?? '').toString(),
    context: json['context'],
    status: json['status'],
    errorMessage: json['error_message'],
    createdAt: _time(json['created_at']) ?? DateTime.now(),
    audioPath: json['audio_path'],
    audioSeconds: (json['audio_seconds'] as num?)?.toDouble(),
  );

  bool get isMine => role == 'user';
  bool get isWaiting => status == 'requested' || status == 'processing';
  bool get hasContext => (context ?? '').trim().isNotEmpty;
  bool get hasAudio => audioPath != null;

  /// A voice question the PC hasn't transcribed yet.
  bool get isTranscribing => hasAudio && isMine && content.trim().isEmpty;
}

/// Speech to text for a chat's voice messages. Stored as
/// (stt_engine, stt_language).
enum SttEngine {
  parakeet('parakeet', 'pt', 'Parakeet', 'Rápido · português e inglês'),
  whisperPt('whisper', 'pt', 'Whisper · português', 'Mais lento, mais preciso'),
  whisperEn('whisper', 'en', 'Whisper · inglês', 'Mais lento, mais preciso');

  final String engine;
  final String language;
  final String label;
  final String hint;

  const SttEngine(this.engine, this.language, this.label, this.hint);

  static SttEngine from(dynamic engine, dynamic language) {
    if (engine != 'whisper') return parakeet;
    return language == 'en' ? whisperEn : whisperPt;
  }
}

/// Kokoro voices offered in the app (Brazilian Portuguese and English).
class KokoroVoice {
  final String id;
  final String name;
  final String language;
  final bool female;

  const KokoroVoice(this.id, this.name, this.language, this.female);

  static const defaultId = 'pf_dora';

  static const all = [
    KokoroVoice('pf_dora', 'Dora', 'Português', true),
    KokoroVoice('pm_alex', 'Alex', 'Português', false),
    KokoroVoice('pm_santa', 'Santa', 'Português', false),
    KokoroVoice('af_heart', 'Heart', 'Inglês (EUA)', true),
    KokoroVoice('af_bella', 'Bella', 'Inglês (EUA)', true),
    KokoroVoice('af_nicole', 'Nicole', 'Inglês (EUA)', true),
    KokoroVoice('af_sarah', 'Sarah', 'Inglês (EUA)', true),
    KokoroVoice('am_michael', 'Michael', 'Inglês (EUA)', false),
    KokoroVoice('am_fenrir', 'Fenrir', 'Inglês (EUA)', false),
    KokoroVoice('am_puck', 'Puck', 'Inglês (EUA)', false),
    KokoroVoice('bf_emma', 'Emma', 'Inglês (UK)', true),
    KokoroVoice('bm_george', 'George', 'Inglês (UK)', false),
  ];

  static KokoroVoice byId(String id) =>
      all.firstWhere((v) => v.id == id, orElse: () => all.first);
}

DateTime? _time(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
