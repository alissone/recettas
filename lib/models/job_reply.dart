enum JobReplyChannel {
  email('email', 'E-mail'),
  linkedin('linkedin', 'LinkedIn');

  final String value;
  final String label;
  const JobReplyChannel(this.value, this.label);

  static JobReplyChannel parse(String? v) =>
      v == 'email' ? JobReplyChannel.email : JobReplyChannel.linkedin;
}

enum JobReplyStatus { requested, processing, done, error }

/// A recruiter message pasted in the app and the reply Claude wrote for
/// it (table job_replies, filled by transcriber/worker.py).
class JobReply {
  final String id;
  final JobReplyChannel channel;
  final String message;
  final String? jobDescription;
  final String? instructions;
  final JobReplyStatus status;
  final String? errorMessage;
  final String? subject;
  final String? reply;
  final String? notes;
  final DateTime createdAt;

  JobReply({
    required this.id,
    required this.channel,
    required this.message,
    this.jobDescription,
    this.instructions,
    required this.status,
    this.errorMessage,
    this.subject,
    this.reply,
    this.notes,
    required this.createdAt,
  });

  bool get isBusy =>
      status == JobReplyStatus.requested ||
      status == JobReplyStatus.processing;

  factory JobReply.fromJson(Map<String, dynamic> json) {
    return JobReply(
      id: json['id'],
      channel: JobReplyChannel.parse(json['channel']),
      message: json['message'] ?? '',
      jobDescription: json['job_description'],
      instructions: json['instructions'],
      status: JobReplyStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => JobReplyStatus.error),
      errorMessage: json['error_message'],
      subject: json['subject'],
      reply: json['reply'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}
