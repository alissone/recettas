import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_theme.dart';
import '../services/voice_note_repository.dart';

/// Records a voice note: starts as soon as it opens, can be paused and
/// resumed, and on save hands the file to [VoiceNoteRepository] (which
/// uploads it when there's a connection). Pops true when saved.
///
/// Can't be swiped or backed out of - losing a long recording to a stray
/// gesture would be worse than one extra tap on "Descartar".
class VoiceRecorderSheet extends StatefulWidget {
  const VoiceRecorderSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (_) => const VoiceRecorderSheet(),
    );
  }

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet> {
  // Mono AAC at 64 kbps, ~0.5 MB/minute. 44.1 kHz rather than the 16 kHz
  // WhisperX resamples to: iOS's AAC encoder rejects 64 kbps at 16 kHz,
  // and AVAudioRecorder then silently writes a header-only (28 byte) file.
  static const _config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 64000,
    sampleRate: 44100,
    numChannels: 1,
  );

  /// Anything this small is just a container header with no audio.
  static const _minFileBytes = 1024;

  final _recorder = AudioRecorder();
  final _stopwatch = Stopwatch();
  Timer? _ticker;

  String? _id;
  String? _path;
  bool _recording = false;
  bool _paused = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WakelockPlus.disable();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = 'Permissão de microfone negada');
        return;
      }
      final target = await VoiceNoteRepository.instance.newRecordingPath();
      await _recorder.start(_config, path: target.path);
      // Recording stops if the phone sleeps; keep the screen on.
      WakelockPlus.enable();
      _stopwatch.start();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
      if (mounted) {
        setState(() {
          _id = target.id;
          _path = target.path;
          _recording = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Não foi possível gravar: $e');
    }
  }

  Future<void> _togglePause() async {
    if (_paused) {
      await _recorder.resume();
      _stopwatch.start();
    } else {
      await _recorder.pause();
      _stopwatch.stop();
    }
    setState(() => _paused = !_paused);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    _stopwatch.stop();
    _ticker?.cancel();
    try {
      final path = await _recorder.stop() ?? _path;
      if (path == null || _id == null) throw 'arquivo não encontrado';
      final size = await File(path).length();
      if (size < _minFileBytes) {
        await File(path).delete();
        throw 'o arquivo saiu vazio ($size bytes) - o gravador não capturou áudio';
      }
      await VoiceNoteRepository.instance.addRecording(
        id: _id!,
        filePath: path,
        durationSeconds: _stopwatch.elapsed.inSeconds,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          // The recorder is already stopped; only "Descartar" remains.
          _recording = false;
          _saving = false;
          _error = 'Erro ao salvar: $e';
        });
      }
    }
  }

  Future<void> _discard() async {
    _ticker?.cancel();
    if (_recording) {
      try {
        await _recorder.cancel(); // also deletes the file
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context, false);
  }

  String _formatElapsed() {
    final d = _stopwatch.elapsed;
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = two(d.inMinutes.remainder(60));
    final seconds = two(d.inSeconds.remainder(60));
    return d.inHours > 0 ? '${d.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nota de voz', style: AppTheme.sectionTitle),
              const SizedBox(height: 20),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!,
                      textAlign: TextAlign.center,
                      style: AppTheme.caption
                          .copyWith(color: Colors.red.shade400)),
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fiber_manual_record,
                        size: 16,
                        color: _paused || !_recording
                            ? AppTheme.mediumBrown.withValues(alpha: 0.4)
                            : Colors.red.shade400),
                    const SizedBox(width: 8),
                    Text(_formatElapsed(),
                        style: AppTheme.headingLarge.copyWith(
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  !_recording
                      ? 'Iniciando...'
                      : _paused
                          ? 'Pausado'
                          : 'Gravando',
                  style: AppTheme.caption,
                ),
                const SizedBox(height: 24),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: _saving ? null : _discard,
                    icon: Icon(Icons.delete_outline,
                        color: Colors.red.shade300),
                    label: Text('Descartar',
                        style: TextStyle(color: Colors.red.shade300)),
                  ),
                  if (_recording)
                    IconButton.filledTonal(
                      iconSize: 32,
                      tooltip: _paused ? 'Continuar' : 'Pausar',
                      onPressed: _saving ? null : _togglePause,
                      icon: Icon(_paused ? Icons.mic : Icons.pause),
                    ),
                  if (_recording)
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        foregroundColor: Colors.white,
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check),
                      label: const Text('Salvar'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
