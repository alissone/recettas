/// One "went to sleep" or "woke up" moment.
class SleepEvent {
  final String id;
  final String userId;

  /// 'sleep' or 'wake'.
  final String eventType;
  final DateTime occurredAt;

  SleepEvent({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.occurredAt,
  });

  bool get isSleep => eventType == 'sleep';

  factory SleepEvent.fromJson(Map<String, dynamic> json) {
    return SleepEvent(
      id: json['id'],
      userId: json['user_id'],
      eventType: json['event_type'],
      occurredAt: DateTime.parse(json['occurred_at']).toLocal(),
    );
  }
}
