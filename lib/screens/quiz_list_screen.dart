import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/quiz.dart';
import '../services/quiz_repository.dart';
import '../utils/dates.dart';
import '../widgets/quiz_widgets.dart';
import 'quiz_play_screen.dart';

/// Max width of the quiz screens' content on wide (web) windows.
const quizMaxWidth = 720.0;

/// The quiz list, opened from the FAB on the Chat tab. Only titles and
/// metadata are fetched here; a quiz's questions load when it is opened.
class QuizListScreen extends StatefulWidget {
  const QuizListScreen({super.key});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  final _repo = QuizRepository.instance;
  List<QuizSummary>? _quizzes;
  Map<String, int> _attemptCounts = const {};
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_repo.list(), _repo.attemptCounts()]);
      if (!mounted) return;
      setState(() {
        _quizzes = results[0] as List<QuizSummary>;
        _attemptCounts = results[1] as Map<String, int>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(QuizSummary summary) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizDetailScreen(summary: summary)),
    );
    // An attempt may have been added.
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(title: const Text('Quizzes')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: quizMaxWidth),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _quizzes == null) {
      return _message(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível carregar',
        body: '$_error',
        action: TextButton(
          onPressed: _load,
          child: const Text('Tentar de novo'),
        ),
      );
    }
    final quizzes = _quizzes;
    if (quizzes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (quizzes.isEmpty) {
      return _message(
        icon: Icons.quiz_outlined,
        title: 'Nenhum quiz ainda',
        body:
            'Crie um com a skill /quiz do Claude e envie para o '
            'Supabase com scripts/upload_quiz.py.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        itemCount: quizzes.length,
        itemBuilder: (context, i) => _QuizTile(
          summary: quizzes[i],
          attempts: _attemptCounts[quizzes[i].id] ?? 0,
          index: i,
          onTap: () => _open(quizzes[i]),
        ),
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppTheme.primaryOrange.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTheme.sectionTitle),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
            ),
            if (action != null) ...[const SizedBox(height: 12), action],
          ],
        ),
      ),
    );
  }
}

class _QuizTile extends StatelessWidget {
  final QuizSummary summary;
  final int attempts;
  final int index;
  final VoidCallback onTap;

  const _QuizTile({
    required this.summary,
    required this.attempts,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = QuizColors.forQuiz(
      topic: summary.topic,
      title: summary.title,
    );
    // Tiles slide in one after another.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + 50 * index.clamp(0, 10)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
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
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, Color.lerp(color, Colors.white, 0.35)!],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(summary.topic ?? summary.title),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.title,
                          style: AppTheme.valueBold,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            QuizChip(
                              icon: Icons.help_outline,
                              label: '${summary.questionCount} perguntas',
                              color: color,
                            ),
                            if (attempts > 0)
                              QuizChip(
                                icon: Icons.replay,
                                label: attempts == 1
                                    ? '1 tentativa'
                                    : '$attempts tentativas',
                                color: AppTheme.mediumBrown,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppTheme.mediumBrown,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _initials(String text) {
    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 || w == w.toUpperCase())
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}

/// A quiz before starting: what it is, and how the previous attempts
/// went (chart of scores, best, last).
class QuizDetailScreen extends StatefulWidget {
  final QuizSummary summary;

  const QuizDetailScreen({super.key, required this.summary});

  @override
  State<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends State<QuizDetailScreen> {
  final _repo = QuizRepository.instance;
  Quiz? _quiz;
  List<QuizAttempt> _attempts = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final quiz = await _repo.load(widget.summary);
      List<QuizAttempt> attempts = const [];
      try {
        attempts = await _repo.attempts(quiz.id);
      } catch (e) {
        debugPrint('Quiz attempts failed: $e');
      }
      if (!mounted) return;
      setState(() {
        _quiz = quiz;
        _attempts = attempts;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _start() async {
    final quiz = _quiz;
    if (quiz == null || quiz.questions.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizPlayScreen(quiz: quiz)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final quiz = _quiz;
    final color = QuizColors.forQuiz(
      color: quiz?.color,
      topic: widget.summary.topic,
      title: widget.summary.title,
    );
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: quizMaxWidth),
          child: quiz == null
              ? Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Erro ao carregar: $_error',
                            textAlign: TextAlign.center,
                          ),
                        ),
                )
              : _buildContent(quiz, color),
        ),
      ),
      bottomNavigationBar: quiz == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: quizMaxWidth - 40,
                    ),
                    child: _StartButton(
                      color: color,
                      label: _attempts.isEmpty ? 'Começar' : 'Fazer de novo',
                      onPressed: quiz.questions.isEmpty ? null : _start,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildContent(Quiz quiz, Color color) {
    final total = quiz.questions.length;
    final fractions = [
      for (final a in _attempts)
        total == 0 ? 0.0 : quiz.score(a.answers) / total,
    ];
    final best = fractions.isEmpty
        ? null
        : fractions.reduce((a, b) => a > b ? a : b);
    final last = fractions.isEmpty ? null : fractions.last;
    final previous = fractions.length < 2
        ? null
        : fractions[fractions.length - 2];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        // Header card in the quiz's color.
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, Color.lerp(color, AppTheme.lightOrange, 0.45)!],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (quiz.topic != null)
                Text(
                  quiz.topic!.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                quiz.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              if (quiz.description != null) ...[
                const SizedBox(height: 10),
                Text(
                  quiz.description!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _whiteChip(Icons.help_outline, '$total perguntas'),
                  _whiteChip(Icons.list_alt, 'Alternativas A–E'),
                  if (quiz.source != null)
                    _whiteChip(Icons.menu_book_outlined, quiz.source!),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _StatTile(
              label: 'Tentativas',
              value: '${_attempts.length}',
              color: AppTheme.primaryOrange,
            ),
            const SizedBox(width: 10),
            _StatTile(
              label: 'Melhor',
              value: best == null ? '–' : '${(best * 100).round()}%',
              color: best == null
                  ? AppTheme.mediumBrown
                  : QuizColors.forScore(best),
            ),
            const SizedBox(width: 10),
            _StatTile(
              label: 'Última',
              value: last == null ? '–' : '${(last * 100).round()}%',
              color: last == null
                  ? AppTheme.mediumBrown
                  : QuizColors.forScore(last),
              trend: last == null || previous == null
                  ? null
                  : (last - previous),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: AppTheme.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sua evolução', style: AppTheme.sectionTitle),
              const SizedBox(height: 4),
              Text(
                _attempts.isEmpty
                    ? 'Faça o quiz para ver seu desempenho aqui.'
                    : 'Acertos em cada tentativa (linha tracejada: 70%).',
                style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 12),
              if (_attempts.isEmpty)
                SizedBox(
                  height: 120,
                  child: Center(
                    child: Icon(
                      Icons.show_chart,
                      size: 56,
                      color: color.withValues(alpha: 0.3),
                    ),
                  ),
                )
              else ...[
                QuizScoreChart(
                  accent: color,
                  points: [
                    for (var i = 0; i < _attempts.length; i++)
                      QuizScorePoint(_attempts[i].createdAt, fractions[i]),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Última tentativa: ${formatDayMonth(_attempts.last.createdAt)}'
                  ' · ${quiz.score(_attempts.last.answers)}/$total acertos',
                  style: AppTheme.caption,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _whiteChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  /// Change since the previous attempt, as a fraction; null hides it.
  final double? trend;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final t = trend;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.softShadow,
          border: Border(top: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (t != null && t != 0) ...[
                  const SizedBox(width: 2),
                  Icon(
                    t > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                    color: t > 0 ? QuizColors.right : QuizColors.wrong,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTheme.caption),
          ],
        ),
      ),
    );
  }
}

/// Big, bouncy call to action.
class _StartButton extends StatelessWidget {
  final Color color;
  final String label;
  final VoidCallback? onPressed;

  const _StartButton({
    required this.color,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 26),
        label: Text(label),
      ),
    );
  }
}
