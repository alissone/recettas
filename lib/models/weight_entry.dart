/// One body-weight check-in.
class WeightEntry {
  final String id;
  final double weightKg;
  final DateTime recordedAt;

  WeightEntry({
    required this.id,
    required this.weightKg,
    required this.recordedAt,
  });

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      id: json['id'],
      weightKg: double.parse(json['weight_kg'].toString()),
      recordedAt: DateTime.parse(json['recorded_at']).toLocal(),
    );
  }
}
