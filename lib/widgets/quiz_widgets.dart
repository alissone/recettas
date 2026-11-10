import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/quiz.dart';

/// Colors and small animated pieces shared by the quiz screens. The app's
/// cream/orange/brown stays the frame; the quizzes add a brighter palette
/// on top so questions and options read at a glance.
class QuizColors {
  QuizColors._();

  /// One color per option letter, A..E.
  static const options = [
    Color(0xFF4C8BF5), // A - blue
    Color(0xFF2EB67D), // B - green
    Color(0xFF9B5DE5), // C - purple
    Color(0xFFF15BB5), // D - pink
    Color(0xFF00A6A6), // E - teal
  ];

  static const right = Color(0xFF2E9E5B);
  static const wrong = Color(0xFFE5484D);

  /// Accents quizzes cycle through when they don't set their own color.
  static const _topicPalette = [
    Color(0xFFFF8C42),
    Color(0xFF4C8BF5),
    Color(0xFF9B5DE5),
    Color(0xFF2EB67D),
    Color(0xFFF15BB5),
    Color(0xFF00A6A6),
    Color(0xFFE5484D),
    Color(0xFFF2A900),
  ];

  static Color forOption(int index) => options[index % options.length];

  /// The quiz's own "#RRGGBB" color, else a stable pick by topic/title.
  static Color forQuiz({String? color, String? topic, required String title}) {
    final parsed = _parseHex(color);
    if (parsed != null) return parsed;
    final key = (topic == null || topic.isEmpty) ? title : topic;
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _topicPalette[hash % _topicPalette.length];
  }

  static Color? _parseHex(String? hex) {
    if (hex == null) return null;
    final clean = hex.replaceFirst('#', '');
    if (clean.length != 6) return null;
    final value = int.tryParse(clean, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  /// Red -> amber -> green as the score fraction rises.
  static Color forScore(double fraction) {
    if (fraction >= 0.7) return right;
    if (fraction >= 0.5) return const Color(0xFFF2A900);
    return wrong;
  }
}

/// Emoji + phrase for a final score.
(String, String) quizVerdict(double fraction) {
  if (fraction >= 1) return ('🏆', 'Gabaritou!');
  if (fraction >= 0.8) return ('🤩', 'Mandou muito bem!');
  if (fraction >= 0.6) return ('😄', 'Bom resultado!');
  if (fraction >= 0.4) return ('🙂', 'Tá no caminho!');
  return ('💪', 'Bora tentar de novo!');
}

/// Round letter badge in the option's color.
class QuizLetterBadge extends StatelessWidget {
  final String letter;
  final Color color;
  final bool filled;
  final double size;

  const QuizLetterBadge({
    super.key,
    required this.letter,
    required this.color,
    this.filled = false,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w800,
          color: filled ? Colors.white : color,
        ),
      ),
    );
  }
}

/// Shakes its child sideways each time [trigger] changes - the "nope"
/// for a wrong answer.
class QuizShake extends StatefulWidget {
  final int trigger;
  final Widget child;

  const QuizShake({super.key, required this.trigger, required this.child});

  @override
  State<QuizShake> createState() => _QuizShakeState();
}

class _QuizShakeState extends State<QuizShake>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void didUpdateWidget(QuizShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// Pops its child (overshooting scale) each time [trigger] changes - the
/// "yes!" for a right answer.
class QuizPop extends StatefulWidget {
  final int trigger;
  final Widget child;

  const QuizPop({super.key, required this.trigger, required this.child});

  @override
  State<QuizPop> createState() => _QuizPopState();
}

class _QuizPopState extends State<QuizPop> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void didUpdateWidget(QuizPop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final scale = 1 + math.sin(t * math.pi) * 0.06;
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}

/// Confetti burst over its area, fired each time [trigger] changes (and
/// once on first build when [playOnStart]). Ignores pointers.
class QuizConfetti extends StatefulWidget {
  final int trigger;
  final bool playOnStart;
  final int pieces;

  const QuizConfetti({
    super.key,
    this.trigger = 0,
    this.playOnStart = false,
    this.pieces = 60,
  });

  @override
  State<QuizConfetti> createState() => _QuizConfettiState();
}

class _QuizConfettiState extends State<QuizConfetti>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  List<_Piece> _pieces = const [];

  @override
  void initState() {
    super.initState();
    if (widget.playOnStart) _fire();
  }

  @override
  void didUpdateWidget(QuizConfetti oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _fire();
  }

  void _fire() {
    final random = math.Random();
    const colors = [...QuizColors.options, AppTheme.primaryOrange];
    _pieces = List.generate(widget.pieces, (i) {
      final angle = -math.pi / 2 + (random.nextDouble() - 0.5) * math.pi * 0.9;
      final speed = 0.6 + random.nextDouble() * 0.7;
      return _Piece(
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed * 1.4,
        spin: (random.nextDouble() - 0.5) * 12,
        color: colors[random.nextInt(colors.length)],
        size: 5 + random.nextDouble() * 6,
        round: random.nextBool(),
      );
    });
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
            pieces: _pieces,
            t: _controller.isAnimating ? _controller.value : 1,
          ),
        ),
      ),
    );
  }
}

class _Piece {
  final double vx, vy, spin, size;
  final Color color;
  final bool round;

  const _Piece({
    required this.vx,
    required this.vy,
    required this.spin,
    required this.color,
    required this.size,
    required this.round,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;

  _ConfettiPainter({required this.pieces, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1 || pieces.isEmpty) return;
    // Launch from the bottom middle, arc up, fall back with gravity.
    final origin = Offset(size.width / 2, size.height * 0.85);
    final scale = math.min(size.width, size.height * 1.2);
    final opacity = t < 0.75 ? 1.0 : (1 - t) / 0.25;
    final paint = Paint();
    for (final p in pieces) {
      final x = origin.dx + p.vx * t * scale;
      final y = origin.dy + (p.vy * t + 1.6 * t * t) * scale * 0.7;
      paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.5,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}

/// One past attempt as a point on the progress chart.
class QuizScorePoint {
  final DateTime at;

  /// 0..1
  final double fraction;

  const QuizScorePoint(this.at, this.fraction);
}

/// Line chart of the score (0-100%) of each past attempt, in order. Point
/// colors follow [QuizColors.forScore]; the area under the line takes the
/// quiz's accent.
class QuizScoreChart extends StatelessWidget {
  final List<QuizScorePoint> points;
  final Color accent;

  const QuizScoreChart({super.key, required this.points, required this.accent});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => CustomPaint(
        size: const Size(double.infinity, 170),
        painter: _ScoreChartPainter(
          points: points,
          accent: accent,
          progress: progress,
        ),
      ),
    );
  }
}

class _ScoreChartPainter extends CustomPainter {
  final List<QuizScorePoint> points;
  final Color accent;
  final double progress;

  _ScoreChartPainter({
    required this.points,
    required this.accent,
    required this.progress,
  });

  static const _left = 34.0;
  static const _bottom = 20.0;
  static const _inset = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotW = size.width - _left;
    final plotH = size.height - _bottom;
    if (plotW <= 0 || plotH <= 0 || points.isEmpty) return;

    final labelStyle = TextStyle(
      fontSize: 10,
      color: AppTheme.mediumBrown.withValues(alpha: 0.7),
    );
    final grid = Paint()
      ..color = AppTheme.mediumBrown.withValues(alpha: 0.12)
      ..strokeWidth = 1;

    double yOf(double fraction) => 6 + (plotH - 6) * (1 - fraction);
    double xOf(int i) => points.length == 1
        ? _left + plotW / 2
        : _left + _inset + (plotW - _inset * 2) * i / (points.length - 1);

    for (final pct in [0, 50, 100]) {
      final y = yOf(pct / 100);
      canvas.drawLine(Offset(_left, y), Offset(size.width, y), grid);
      _text(canvas, '$pct%', Offset(0, y - 6), labelStyle);
    }
    // 70% "passing" line, dashed.
    final passY = yOf(0.7);
    final dash = Paint()
      ..color = QuizColors.right.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    for (var x = _left; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, passY), Offset(x + 4, passY), dash);
    }

    // Labels: attempt number, sparse when there are many.
    final every = (points.length / 8).ceil().clamp(1, 1000);
    for (var i = 0; i < points.length; i++) {
      if (i % every != 0 && i != points.length - 1) continue;
      _text(canvas, '${i + 1}ª', Offset(xOf(i) - 7, plotH + 5), labelStyle);
    }

    final offsets = [
      for (var i = 0; i < points.length; i++)
        Offset(xOf(i), yOf(points[i].fraction * progress)),
    ];

    if (offsets.length > 1) {
      final line = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final o in offsets.skip(1)) {
        line.lineTo(o.dx, o.dy);
      }
      final area = Path.from(line)
        ..lineTo(offsets.last.dx, yOf(0))
        ..lineTo(offsets.first.dx, yOf(0))
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accent.withValues(alpha: 0.30),
              accent.withValues(alpha: 0.02),
            ],
          ).createShader(Rect.fromLTWH(_left, 0, plotW, plotH)),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (var i = 0; i < offsets.length; i++) {
      final color = QuizColors.forScore(points[i].fraction);
      canvas.drawCircle(offsets[i], 6, Paint()..color = Colors.white);
      canvas.drawCircle(offsets[i], 4.5, Paint()..color = color);
    }
  }

  void _text(Canvas canvas, String text, Offset at, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_ScoreChartPainter old) =>
      old.progress != progress || old.points != points || old.accent != accent;
}

/// Image from the internet for a question, with a loading box and a
/// friendly fallback when the host refuses it.
class QuizNetworkImage extends StatelessWidget {
  final String url;
  final String? caption;

  const QuizNetworkImage({super.key, required this.url, this.caption});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            // On web, hosts without CORS headers can't be drawn by
            // CanvasKit; fall back to a plain <img> element for those.
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (context, error, stack) => Container(
              height: 120,
              color: AppTheme.lightPeach,
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    color: AppTheme.mediumBrown,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Não foi possível carregar a imagem',
                    style: AppTheme.caption,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (caption != null && caption!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            caption!,
            textAlign: TextAlign.center,
            style: AppTheme.caption.copyWith(
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

/// Small rounded label ("10 perguntas", "Tentativa 3").
class QuizChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;

  const QuizChip({
    super.key,
    this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Letter for option [index].
String quizLetter(int index) => quizLetters[index];
