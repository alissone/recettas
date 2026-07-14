import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_theme.dart';
import '../models/gps_point.dart';
import '../models/gps_recording.dart';
import '../services/gpx_export.dart';
import '../services/location_repository.dart';
import '../widgets/route_preview.dart';

enum _RecState { idle, recording }

/// Interval presets (seconds, label) offered before starting a recording.
const _intervalOptions = <(int, String)>[
  (5, '5 segundos'),
  (15, '15 segundos'),
  (30, '30 segundos'),
  (60, '1 minuto'),
  (120, '2 minutos'),
  (300, '5 minutos'),
];

String _intervalLabel(int seconds) {
  for (final option in _intervalOptions) {
    if (option.$1 == seconds) return option.$2;
  }
  return '${seconds}s';
}

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}m';
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String _formatDistance(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
  return '${meters.toStringAsFixed(0)} m';
}

String _formatDateTime(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

/// Records the device's GPS position at a chosen interval (up to ~1h),
/// stores the track locally in SQLite, and lets the user browse, delete
/// or export past recordings as GPX. Recording only works while this
/// screen's app is in the foreground — a wakelock keeps the screen on
/// so a long recording isn't cut short by the device sleeping.
class GpsTrackerScreen extends StatefulWidget {
  const GpsTrackerScreen({super.key});

  @override
  State<GpsTrackerScreen> createState() => _GpsTrackerScreenState();
}

class _GpsTrackerScreenState extends State<GpsTrackerScreen> {
  _RecState _state = _RecState.idle;
  int _intervalSeconds = 30;
  bool _isLoadingHistory = true;
  List<GpsRecording> _recordings = [];
  String? _error;

  String? _recordingId;
  DateTime? _startedAt;
  final List<GpsPoint> _points = [];
  double _distanceMeters = 0;
  Timer? _sampleTimer;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  @override
  void dispose() {
    _sampleTimer?.cancel();
    _tickTimer?.cancel();
    if (_state == _RecState.recording) {
      WakelockPlus.disable();
    }
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    setState(() => _isLoadingHistory = true);
    await LocationRepository.instance.cleanupIncomplete();
    final recordings = await LocationRepository.instance.getRecordings();
    if (mounted) {
      setState(() {
        _recordings = recordings;
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _startRecording() async {
    setState(() => _error = null);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _error = 'Ative o GPS do aparelho para gravar.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Permissão de localização negada.');
        return;
      }
    } catch (e) {
      setState(() => _error = 'Não foi possível acessar o GPS: $e');
      return;
    }

    final id = await LocationRepository.instance.startRecording(_intervalSeconds);
    await WakelockPlus.enable();
    if (!mounted) return;
    setState(() {
      _state = _RecState.recording;
      _recordingId = id;
      _startedAt = DateTime.now();
      _points.clear();
      _distanceMeters = 0;
    });

    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    await _captureFix();
    if (_state != _RecState.recording) return;
    _sampleTimer =
        Timer.periodic(Duration(seconds: _intervalSeconds), (_) => _captureFix());
  }

  Future<void> _captureFix() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (_state != _RecState.recording || _recordingId == null) return;
      final point = GpsPoint(
        lat: position.latitude,
        lng: position.longitude,
        altitude: position.altitude,
        timestamp: DateTime.now(),
      );
      if (_points.isNotEmpty) {
        _distanceMeters += Geolocator.distanceBetween(
          _points.last.lat,
          _points.last.lng,
          point.lat,
          point.lng,
        );
      }
      final sequence = _points.length;
      _points.add(point);
      await LocationRepository.instance.addPoint(_recordingId!, sequence, point);
      if (mounted) setState(() {});
    } catch (_) {
      // Missed fix (timeout, temporary signal loss): skip this sample
      // and keep recording, the next tick will try again.
    }
  }

  Future<void> _stopRecording() async {
    _sampleTimer?.cancel();
    _tickTimer?.cancel();
    await WakelockPlus.disable();
    final id = _recordingId!;
    if (_points.length < 2) {
      await LocationRepository.instance.deleteRecording(id);
    } else {
      await LocationRepository.instance.finishRecording(
        id,
        endedAt: DateTime.now(),
        distanceMeters: _distanceMeters,
        points: List.of(_points),
      );
    }
    setState(() {
      _state = _RecState.idle;
      _recordingId = null;
      _points.clear();
    });
    await _loadRecordings();
  }

  Future<void> _openDetail(GpsRecording recording) async {
    final points = await LocationRepository.instance.getPoints(recording.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _RecordingDetailDialog(
        recording: recording,
        points: points,
        onDeleted: () {
          Navigator.pop(context);
          _loadRecordings();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(title: const Text('Rastreador GPS')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRecordings,
          color: AppTheme.primaryOrange,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _state == _RecState.recording ? _buildLiveCard() : _buildStartCard(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _buildErrorBanner(),
              ],
              const SizedBox(height: 24),
              const Text('Gravações salvas', style: AppTheme.sectionTitle),
              const SizedBox(height: 12),
              if (_isLoadingHistory)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryOrange),
                  ),
                )
              else if (_recordings.isEmpty)
                _buildEmptyHistory()
              else
                for (final r in _recordings) _buildRecordingCard(r),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nova gravação', style: AppTheme.sectionTitle),
          const SizedBox(height: 4),
          Text(
            'Mantenha o app aberto durante a gravação.',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _intervalSeconds,
            decoration: InputDecoration(
              labelText: 'Intervalo entre pontos',
              filled: true,
              fillColor: AppTheme.creamBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: [
              for (final option in _intervalOptions)
                DropdownMenuItem(value: option.$1, child: Text(option.$2)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _intervalSeconds = v);
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startRecording,
              icon: const Icon(Icons.fiber_manual_record, size: 20),
              label: const Text('Iniciar gravação'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCard() {
    final elapsed = DateTime.now().difference(_startedAt!);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLiveStat('Tempo', _formatDuration(elapsed)),
              _buildLiveStat('Distância', _formatDistance(_distanceMeters)),
              _buildLiveStat('Pontos', '${_points.length}'),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                'Gravando a cada ${_intervalLabel(_intervalSeconds)}',
                style: AppTheme.caption,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop, size: 20),
              label: const Text('Parar gravação'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: AppTheme.caption),
        const SizedBox(height: 4),
        Text(value, style: AppTheme.headingMedium),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Icon(Icons.map_outlined,
              size: 36, color: AppTheme.mediumBrown.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text(
            'Nenhuma gravação ainda.',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingCard(GpsRecording r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: () => _openDetail(r),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                RoutePreview(points: r.previewPoints, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatDateTime(r.startedAt), style: AppTheme.valueBold),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 14, color: AppTheme.mediumBrown),
                          const SizedBox(width: 4),
                          Text(_formatDuration(r.duration), style: AppTheme.caption),
                          const SizedBox(width: 12),
                          Icon(Icons.straighten,
                              size: 14, color: AppTheme.mediumBrown),
                          const SizedBox(width: 4),
                          Text(_formatDistance(r.distanceMeters),
                              style: AppTheme.caption),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.mediumBrown),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when a saved recording's card is tapped: a bigger route
/// preview plus stats, with actions to delete or export as GPX.
class _RecordingDetailDialog extends StatefulWidget {
  final GpsRecording recording;
  final List<GpsPoint> points;
  final VoidCallback onDeleted;

  const _RecordingDetailDialog({
    required this.recording,
    required this.points,
    required this.onDeleted,
  });

  @override
  State<_RecordingDetailDialog> createState() => _RecordingDetailDialogState();
}

class _RecordingDetailDialogState extends State<_RecordingDetailDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await GpxExport.export(widget.recording, widget.points);
    } catch (e) {
      if (mounted) setState(() => _error = 'Falha ao exportar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: const Text('Excluir gravação', style: AppTheme.sectionTitle),
        content: const Text(
          'Essa gravação será apagada permanentemente.',
          style: AppTheme.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: AppTheme.mediumBrown)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusXSmall),
              ),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    await LocationRepository.instance.deleteRecording(widget.recording.id);
    widget.onDeleted();
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.caption),
          Text(value, style: AppTheme.valueBold),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recording;
    return AlertDialog(
      backgroundColor: AppTheme.creamBackground,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
      title: Text(_formatDateTime(r.startedAt), style: AppTheme.sectionTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: RoutePreview(
                points: widget.points.map((p) => GpsLatLng(p.lat, p.lng)).toList(),
                size: 220,
              ),
            ),
            const SizedBox(height: 16),
            _statRow('Duração', _formatDuration(r.duration)),
            _statRow('Distância', _formatDistance(r.distanceMeters)),
            _statRow('Pontos gravados', '${r.pointCount}'),
            _statRow('Intervalo', _intervalLabel(r.intervalSeconds)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: _busy ? null : _confirmDelete,
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
          child: const Text('Excluir'),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: Text('Fechar', style: TextStyle(color: AppTheme.mediumBrown)),
            ),
            const SizedBox(width: 4),
            ElevatedButton.icon(
              onPressed: _busy ? null : _export,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.ios_share, size: 18),
              label: const Text('GPX'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
