import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../app_theme.dart';
import '../services/supabase_service.dart';

/// Records a burst of 200 accelerometer samples and uploads them to the
/// database as [t_ms, x, y, z] vectors.
class AccelerometerScreen extends StatefulWidget {
  const AccelerometerScreen({super.key});

  @override
  State<AccelerometerScreen> createState() =>
      _AccelerometerScreenState();
}

enum _RecState { idle, recording, uploading }

enum RecordingCategory {
  noFall('no_fall', 'Sem queda'),
  phoneFall('phone_fall', 'Queda do celular'),
  userFall('user_fall', 'Queda do usuário');

  const RecordingCategory(this.dbValue, this.label);

  final String dbValue;
  final String label;
}

class _AccelerometerScreenState extends State<AccelerometerScreen> {
  static const _targetSamples = 200;

  _RecState _state = _RecState.idle;
  RecordingCategory _category = RecordingCategory.noFall;
  final List<List<double>> _samples = [];
  AccelerometerEvent? _lastEvent;
  String? _message;
  bool _messageIsError = false;
  StreamSubscription<AccelerometerEvent>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (SupabaseService.currentUser == null) {
      setState(() {
        _message = 'Entre na sua conta para enviar leituras.';
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _state = _RecState.recording;
      _samples.clear();
      _message = null;
    });

    final recordedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();

    _subscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(
      (event) {
        if (_samples.length >= _targetSamples) return;
        _samples.add([
          stopwatch.elapsedMilliseconds.toDouble(),
          event.x,
          event.y,
          event.z,
        ]);
        setState(() => _lastEvent = event);
        if (_samples.length >= _targetSamples) {
          _finishRecording(recordedAt);
        }
      },
      onError: (Object e) {
        _subscription?.cancel();
        _subscription = null;
        if (mounted) {
          setState(() {
            _state = _RecState.idle;
            _message = 'Acelerômetro indisponível neste aparelho.';
            _messageIsError = true;
          });
        }
      },
      cancelOnError: true,
    );
  }

  Future<void> _finishRecording(DateTime recordedAt) async {
    await _subscription?.cancel();
    _subscription = null;
    if (!mounted) return;

    setState(() => _state = _RecState.uploading);
    try {
      await SupabaseService.insertAccelRecording(
        recordedAt: recordedAt,
        samples: List.of(_samples),
        category: _category.dbValue,
      );
      if (mounted) {
        setState(() {
          _state = _RecState.idle;
          _message =
              '$_targetSamples amostras enviadas com sucesso!';
          _messageIsError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _RecState.idle;
          _message = 'Falha ao enviar: $e';
          _messageIsError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(title: const Text('Acelerômetro')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildLiveCard(),
              const SizedBox(height: 20),
              if (_message != null) _buildMessage(),
              const Spacer(),
              _buildCategoryPicker(),
              const SizedBox(height: 16),
              _buildRecordButton(),
              const SizedBox(height: 8),
              Text(
                'Cada gravação captura $_targetSamples amostras '
                'e envia para o banco de dados.',
                style: AppTheme.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveCard() {
    final e = _lastEvent;
    final progress = _samples.length / _targetSamples;

    return Container(
      width: double.infinity,
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
              _buildAxis('X', e?.x),
              _buildAxis('Y', e?.y),
              _buildAxis('Z', e?.z),
            ],
          ),
          if (_state == _RecState.recording ||
              _state == _RecState.uploading) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: AppTheme.primaryOrange,
                backgroundColor:
                    AppTheme.primaryOrange.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _state == _RecState.uploading
                  ? 'Enviando...'
                  : '${_samples.length} / $_targetSamples amostras',
              style: AppTheme.caption,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAxis(String label, double? value) {
    return Column(
      children: [
        Text(label, style: AppTheme.caption),
        const SizedBox(height: 4),
        Text(
          value != null ? value.toStringAsFixed(2) : '—',
          style: AppTheme.headingMedium.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildMessage() {
    final color = _messageIsError ? Colors.red : Colors.green;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _messageIsError
            ? Colors.red.shade50
            : const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(
            color: _messageIsError
                ? Colors.red.shade200
                : Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(
            _messageIsError
                ? Icons.error_outline
                : Icons.check_circle_outline,
            color: color.shade400,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _message!,
              style: TextStyle(color: color.shade700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPicker() {
    final busy = _state != _RecState.idle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Categoria', style: AppTheme.caption),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: IgnorePointer(
            ignoring: busy,
            child: Opacity(
              opacity: busy ? 0.5 : 1,
              child: CupertinoSlidingSegmentedControl<RecordingCategory>(
                groupValue: _category,
                backgroundColor: AppTheme.lightPeach,
                thumbColor: AppTheme.primaryOrange,
                onValueChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
                children: {
                  for (final category in RecordingCategory.values)
                    category: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      child: Text(
                        category.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _category == category
                              ? Colors.white
                              : AppTheme.darkBrown,
                        ),
                      ),
                    ),
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordButton() {
    final busy = _state != _RecState.idle;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: busy ? null : _startRecording,
        icon: Icon(busy ? Icons.hourglass_top : Icons.fiber_manual_record,
            size: 20),
        label: Text(busy ? 'Gravando...' : 'Gravar'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryOrange,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              AppTheme.primaryOrange.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
        ),
      ),
    );
  }
}
