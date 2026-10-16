import 'package:flutter/material.dart';

/// Which meter a reading belongs to.
enum UtilityKind {
  water('water', 'Água', 'm³', Icons.water_drop_outlined, Color(0xFF3B8EDB)),
  energy('energy', 'Energia', 'kWh', Icons.bolt_outlined, Color(0xFFFF8C42));

  final String dbValue;
  final String label;
  final String unit;
  final IconData icon;
  final Color color;

  const UtilityKind(
      this.dbValue, this.label, this.unit, this.icon, this.color);

  /// Column of `utility_prices` holding this meter's tariff.
  String get priceColumn =>
      this == water ? 'water_price_m3' : 'energy_price_kwh';

  static UtilityKind fromDb(String value) =>
      values.firstWhere((k) => k.dbValue == value);
}

/// One look at a meter: the cumulative number on its display.
class UtilityReading {
  final String id;
  final UtilityKind kind;
  final double value;
  final DateTime recordedAt;

  const UtilityReading({
    required this.id,
    required this.kind,
    required this.value,
    required this.recordedAt,
  });

  factory UtilityReading.fromJson(Map<String, dynamic> json) {
    return UtilityReading(
      id: json['id'],
      kind: UtilityKind.fromDb(json['kind']),
      value: double.parse(json['value'].toString()),
      recordedAt: DateTime.parse(json['recorded_at']).toLocal(),
    );
  }
}
