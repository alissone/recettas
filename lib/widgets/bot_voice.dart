import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_theme.dart';

/// "1:07".
String formatVoiceDuration(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

// --- Composer ---

enum _RecState { idle, holding, locked }

/// The assistant chat's input row, WhatsApp style: with text typed the
/// round button sends it; with the field empty it is a mic.
///
/// Hold the mic to record and let go to send. While holding, slide left
/// to cancel or up to lock; locked, the row offers delete and send.
class BotComposer extends StatefulWidget {
  final bool busy;
  final Future<bool> Function(String text) onSendText;
  final Future<void> Function(Uint8List bytes, double seconds) onSendVoice;

  const BotComposer({
    super.key,
    required this.busy,
    required this.onSendText,
    required this.onSendVoice,
  });

  @override
  State<BotComposer> createState() => _BotComposerState();
}

class _BotComposerState extends State<BotComposer>
    with SingleTickerProviderStateMixin {
  // Same as the voice-note recorder: iOS's AAC encoder writes an empty
  // file at 64 kbps / 16 kHz, so record at 44.1 kHz.
  static const _config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 64000,
    sampleRate: 44100,
    numChannels: 1,
  );
  static const _cancelDx = -110.0;
  static const _lockDy = -80.0;
  static const _minDuration = Duration(milliseconds: 700);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _recorder = AudioRecorder();
  final _stopwatch = Stopwatch();
  Timer? _ticker;
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  _RecState _rec = _RecState.idle;
  Offset _drag = Offset.zero;
  bool _starting = false;

  /// Finger on the mic, and where it went down. Raw pointer events rather
  /// than a long-press gesture: recording starts on touch (like WhatsApp)
  /// and nothing else (tooltips, scroll views) can win the gesture.
  bool _pointerDown = false;
  Offset _origin = Offset.zero;
  bool _sendingVoice = false;

  bool get _canRecord => !kIsWeb;
  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _blink.dispose();
    WakelockPlus.disable();
    _recorder.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.busy) return;
    if (await widget.onSendText(text)) _controller.clear();
  }

  // --- Recording ---

  Future<void> _start() async {
    if (_starting || _rec != _RecState.idle || widget.busy || _sendingVoice) {
      return;
    }
    _starting = true;
    try {
      // The first time, iOS asks for the mic here; the finger is usually
      // lifted by the time the answer comes, so nothing is recorded yet.
      if (!await _recorder.hasPermission()) {
        _snack(
          'Sem permissão para o microfone: libere em Ajustes > '
          'Recettas > Microfone',
        );
        return;
      }
      if (!_pointerDown) {
        _snack('Segure o microfone enquanto fala');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/bot_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(_config, path: path);
      if (!_pointerDown) {
        // A tap, not a hold: let go before the recorder was even up.
        await _recorder.cancel();
        _snack('Segure o microfone enquanto fala');
        return;
      }
      HapticFeedback.mediumImpact();
      WakelockPlus.enable();
      _stopwatch
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() {});
      });
      _blink.repeat(reverse: true);
      if (mounted) {
        setState(() {
          _rec = _RecState.holding;
          _drag = Offset.zero;
        });
      }
    } catch (e) {
      _snack('Não foi possível gravar: $e');
    } finally {
      _starting = false;
    }
  }

  /// Stops the recorder; returns the file unless [keep] is false or the
  /// recording is too short to be anything.
  Future<(File, double)?> _stop({required bool keep}) async {
    _ticker?.cancel();
    _blink.stop();
    _stopwatch.stop();
    WakelockPlus.disable();
    final elapsed = _stopwatch.elapsed;
    setState(() {
      _rec = _RecState.idle;
      _drag = Offset.zero;
    });
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (path == null) return null;
    final file = File(path);
    if (!keep || elapsed < _minDuration) {
      if (keep) _snack('Segure o microfone enquanto fala');
      try {
        await file.delete();
      } catch (_) {}
      return null;
    }
    return (file, elapsed.inMilliseconds / 1000);
  }

  Future<void> _finish() async {
    final result = await _stop(keep: true);
    if (result == null) return;
    final (file, seconds) = result;
    setState(() => _sendingVoice = true);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length < 1024) throw 'a gravação ficou vazia';
      await widget.onSendVoice(bytes, seconds);
    } catch (e) {
      _snack('Não foi possível enviar o áudio: $e');
    } finally {
      try {
        await file.delete();
      } catch (_) {}
      if (mounted) setState(() => _sendingVoice = false);
    }
  }

  Future<void> _cancel() async {
    HapticFeedback.lightImpact();
    await _stop(keep: false);
  }

  void _onDown(PointerDownEvent e) {
    _pointerDown = true;
    _origin = e.position;
    _start();
  }

  void _onMove(PointerMoveEvent e) {
    if (_rec != _RecState.holding) return;
    final o = e.position - _origin;
    if (o.dx < _cancelDx) {
      _cancel();
      return;
    }
    if (o.dy < _lockDy) {
      HapticFeedback.mediumImpact();
      setState(() {
        _rec = _RecState.locked;
        _drag = Offset.zero;
      });
      return;
    }
    setState(() => _drag = Offset(o.dx.clamp(-200, 0), o.dy.clamp(-120, 0)));
  }

  void _onUp(PointerUpEvent e) {
    _pointerDown = false;
    // Locked keeps recording until delete/send; cancelled already stopped.
    if (_rec == _RecState.holding) _finish();
  }

  void _onCancel(PointerCancelEvent e) {
    _pointerDown = false;
    if (_rec == _RecState.holding) _cancel();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.darkBrown),
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryOrange.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: switch (_rec) {
              _RecState.idle => _textField(),
              _RecState.holding => _holdingRow(),
              _RecState.locked => _lockedRow(),
            },
          ),
          const SizedBox(width: 8),
          _rec == _RecState.locked
              ? _roundButton(
                  icon: Icons.send,
                  tooltip: 'Enviar áudio',
                  onPressed: _finish,
                )
              : _actionButton(),
        ],
      ),
    );
  }

  Widget _textField() {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      minLines: 1,
      maxLines: 5,
      textCapitalization: TextCapitalization.sentences,
      style: AppTheme.bodyText.copyWith(fontSize: 15),
      decoration: InputDecoration(
        hintText: _sendingVoice
            ? 'Enviando áudio...'
            : 'Pergunte ao assistente...',
        hintStyle: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
        filled: true,
        fillColor: AppTheme.creamBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppTheme.lightPeach),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: AppTheme.primaryOrange,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _timer() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _blink,
          child: const Icon(Icons.mic, color: Colors.red, size: 22),
        ),
        const SizedBox(width: 6),
        Text(
          formatVoiceDuration(_stopwatch.elapsed),
          style: AppTheme.bodyText.copyWith(
            fontSize: 15,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _holdingRow() {
    // Fades out as the finger approaches the cancel point.
    final progress = (_drag.dx / _cancelDx).clamp(0.0, 1.0);
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          const SizedBox(width: 8),
          _timer(),
          const Spacer(),
          Opacity(
            opacity: 1 - progress * 0.8,
            child: Transform.translate(
              offset: Offset(_drag.dx * 0.5, 0),
              child: Text(
                '‹  Deslize para cancelar',
                style: AppTheme.caption.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _lockedRow() {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Apagar',
            icon: const Icon(Icons.delete_outline, color: AppTheme.mediumBrown),
            onPressed: _cancel,
          ),
          _timer(),
          const Spacer(),
          Text(
            'Gravando',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// Send (text typed) or mic (hold to record).
  Widget _actionButton() {
    if (_hasText || !_canRecord) {
      return _roundButton(
        icon: Icons.send,
        tooltip: 'Enviar',
        onPressed: widget.busy ? null : _sendText,
        loading: widget.busy,
      );
    }
    final holding = _rec == _RecState.holding;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          if (holding)
            Positioned(
              bottom: 64 - _drag.dy * 0.4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _drag.dy < _lockDy / 2
                          ? Icons.lock
                          : Icons.lock_open_rounded,
                      size: 20,
                      color: AppTheme.mediumBrown,
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.keyboard_arrow_up,
                      size: 18,
                      color: AppTheme.mediumBrown,
                    ),
                  ],
                ),
              ),
            ),
          Transform.translate(
            offset: holding
                ? Offset(_drag.dx * 0.3, _drag.dy * 0.3)
                : Offset.zero,
            child: AnimatedScale(
              scale: holding ? 1.35 : 1,
              duration: const Duration(milliseconds: 150),
              child: _roundButton(
                icon: Icons.mic,
                tooltip: 'Segure para gravar',
                onPressed: null,
                loading: _sendingVoice || widget.busy,
                active: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool loading = false,
    bool active = false,
  }) {
    final child = loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Icon(icon, color: Colors.white, size: 22);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: AppTheme.accentShadow,
      ),
      // The mic is driven by the Listener around it, so it is a plain
      // icon: an IconButton or a Tooltip would take the long press.
      child: active
          ? Center(child: child)
          : IconButton(tooltip: tooltip, onPressed: onPressed, icon: child),
    );
  }
}

// --- Playback ---

/// Play/pause + progress for a voice message, streamed from Storage.
/// Starting one stops whichever was playing.
class VoicePlayer extends StatefulWidget {
  final String path;
  final double? seconds;
  final bool mine;
  final Future<String> Function(String path) resolveUrl;

  const VoicePlayer({
    super.key,
    required this.path,
    required this.seconds,
    required this.mine,
    required this.resolveUrl,
  });

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  static _VoicePlayerState? _current;

  AudioPlayer? _player;
  final List<StreamSubscription<Object?>> _subs = [];
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _playing = false;
  bool _loading = false;
  bool _failed = false;

  Duration get _total =>
      _duration ??
      Duration(milliseconds: ((widget.seconds ?? 0) * 1000).round());

  @override
  void dispose() {
    if (_current == this) _current = null;
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  Future<AudioPlayer> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _subs.addAll([
      player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      }),
      player.onDurationChanged.listen((d) {
        if (mounted && d > Duration.zero) setState(() => _duration = d);
      }),
      player.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _playing = s == PlayerState.playing);
      }),
      player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _playing = false;
            _position = Duration.zero;
          });
        }
      }),
    ]);
    final url = await widget.resolveUrl(widget.path);
    await player.setSourceUrl(url);
    _player = player;
    return player;
  }

  Future<void> _toggle() async {
    if (_loading) return;
    if (_playing) {
      await _player?.pause();
      return;
    }
    if (_current != this) await _current?._player?.pause();
    _current = this;
    setState(() {
      _loading = _player == null;
      _failed = false;
    });
    try {
      final player = await _ensurePlayer();
      // After a recording iOS is left in playAndRecord; play as media so
      // it comes out of the loudspeaker at full volume.
      await player.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
        ),
      );
      await player.resume();
    } catch (e) {
      debugPrint('Voice playback failed: $e');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _seek(double fraction) async {
    final player = _player;
    if (player == null) return;
    final target = _total * fraction;
    setState(() => _position = target);
    await player.seek(target);
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.mine ? Colors.white : AppTheme.primaryOrange;
    final muted = widget.mine
        ? Colors.white.withValues(alpha: 0.8)
        : AppTheme.mediumBrown;
    final total = _total;
    final fraction = total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return SizedBox(
      width: 230,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: _loading
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: _failed
                        ? 'Não foi possível tocar (sem internet?)'
                        : _playing
                        ? 'Pausar'
                        : 'Ouvir',
                    icon: Icon(
                      _failed
                          ? Icons.error_outline
                          : _playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 32,
                      color: fg,
                    ),
                    onPressed: _toggle,
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    activeTrackColor: fg,
                    inactiveTrackColor: muted.withValues(alpha: 0.35),
                    thumbColor: fg,
                    disabledActiveTrackColor: fg,
                    disabledInactiveTrackColor: muted.withValues(alpha: 0.35),
                    disabledThumbColor: fg,
                  ),
                  child: Slider(
                    value: fraction,
                    onChanged: _player == null ? null : _seek,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    formatVoiceDuration(
                      _playing || _position > Duration.zero ? _position : total,
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
