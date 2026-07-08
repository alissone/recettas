import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../app_theme.dart';

/// Pick an hh:mm on the spinner (interpreted as the device's local time,
/// today) and the list below shows that moment in each timezone.
class TimezoneScreen extends StatefulWidget {
  const TimezoneScreen({super.key});

  @override
  State<TimezoneScreen> createState() => _TimezoneScreenState();
}

class _Zone {
  final String flag;
  final String name;
  final String tzId;

  const _Zone(this.flag, this.name, this.tzId);
}

class _TimezoneScreenState extends State<TimezoneScreen> {
  static bool _tzInitialized = false;

  static const _zones = [
    _Zone('🇧🇷', 'Brasília', 'America/Sao_Paulo'),
    _Zone('🇵🇹', 'Lisboa', 'Europe/Lisbon'),
    _Zone('🇺🇸', 'Nova York (Leste)', 'America/New_York'),
    _Zone('🇺🇸', 'Chicago (Central)', 'America/Chicago'),
    _Zone('🇺🇸', 'Denver (Montanha)', 'America/Denver'),
    _Zone('🇺🇸', 'Los Angeles (Pacífico)', 'America/Los_Angeles'),
  ];

  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    if (!_tzInitialized) {
      tzdata.initializeTimeZones();
      _tzInitialized = true;
    }
    final now = DateTime.now();
    _hour = now.hour;
    _minute = now.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController =
        FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  /// The picked wall time in the device's local timezone, today.
  DateTime get _pickedLocal {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, _hour, _minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(title: const Text('Fusos horários')),
      body: SafeArea(
        child: Column(
          children: [
            _buildPicker(),
            const SizedBox(height: 4),
            Text(
              'Horário local de hoje',
              style: AppTheme.caption
                  .copyWith(color: AppTheme.mediumBrown),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                itemCount: _zones.length,
                itemBuilder: (context, index) =>
                    _buildZoneRow(_zones[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPicker() {
    return Container(
      height: 160,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 90,
            child: CupertinoPicker(
              scrollController: _hourController,
              itemExtent: 40,
              looping: true,
              onSelectedItemChanged: (v) =>
                  setState(() => _hour = v),
              children: [
                for (var h = 0; h < 24; h++)
                  Center(
                    child: Text(
                      h.toString().padLeft(2, '0'),
                      style: AppTheme.headingMedium,
                    ),
                  ),
              ],
            ),
          ),
          const Text(':', style: AppTheme.headingMedium),
          SizedBox(
            width: 90,
            child: CupertinoPicker(
              scrollController: _minuteController,
              itemExtent: 40,
              looping: true,
              onSelectedItemChanged: (v) =>
                  setState(() => _minute = v),
              children: [
                for (var m = 0; m < 60; m++)
                  Center(
                    child: Text(
                      m.toString().padLeft(2, '0'),
                      style: AppTheme.headingMedium,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneRow(_Zone zone) {
    final utc = _pickedLocal.toUtc();
    final converted =
        tz.TZDateTime.from(utc, tz.getLocation(zone.tzId));

    // Day rollover relative to the local picked date.
    final localDay = DateTime(
        _pickedLocal.year, _pickedLocal.month, _pickedLocal.day);
    final zoneDay =
        DateTime(converted.year, converted.month, converted.day);
    final dayDiff = zoneDay.difference(localDay).inDays;
    final daySuffix = dayDiff == 0
        ? ''
        : (dayDiff > 0 ? '  +${dayDiff}d' : '  ${dayDiff}d');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Text(zone.flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(zone.name, style: AppTheme.valueBold),
          ),
          Text(
            '${converted.hour.toString().padLeft(2, '0')}:'
            '${converted.minute.toString().padLeft(2, '0')}'
            '$daySuffix',
            style: AppTheme.valueBold.copyWith(
              color: AppTheme.primaryOrange,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
