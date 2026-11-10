import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/quiz.dart';
import '../services/quiz_repository.dart';
import '../widgets/quiz_widgets.dart';
import 'quiz_list_screen.dart' show quizMaxWidth;

/// Plays a quiz one question at a time. Answering locks the question,
/// marks the right option and shows why every option is right or wrong;
/// at the end the attempt is saved and the result screen takes over.
class QuizPlayScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizPlayScreen({super.key, required this.quiz});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  final _started = DateTime.now();
  final _scroll = ScrollController();
  late final List<String> _answers = List.filled(
    widget.quiz.questions.length,
    quizBlank,
  );
  int _index = 0;

  /// Bumped on each answer so the pop/shake/confetti widgets fire.
  int _feedbackTick = 0;
  bool _saving = false;

  Quiz get _quiz => widget.quiz;
  QuizQuestion get _question => _quiz.questions[_index];
  String get _answer => _answers[_index];
  bool get _answered => _answer != quizBlank;
  bool get _isLast => _index == _quiz.questions.length - 1;
  int get _rightSoFar => _quiz.score(_answers.join());

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _choose(int option) {
    if (_answered) return;
    setState(() {
      _answers[_index] = quizLetters[option];
      _feedbackTick++;
    });
  }

  Future<void> _next() async {
    if (!_isLast) {
      setState(() => _index++);
      if (_scroll.hasClients) _scroll.jumpTo(0);
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final answers = _answers.join();
    final seconds = DateTime.now().difference(_started).inSeconds;
    String? saveError;
    try {
      await QuizRepository.instance.saveAttempt(
        quizId: _quiz.id,
        answers: answers,
        durationSeconds: seconds,
      );
    } catch (e) {
      saveError = '$e';
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => QuizResultScreen(
          quiz: _quiz,
          answers: answers,
          durationSeconds: seconds,
          saveError: saveError,
        ),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmQuit() async {
    if (_answers.every((a) => a == quizBlank)) return true;
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        title: const Text('Sair do quiz?', style: AppTheme.sectionTitle),
        content: const Text(
          'Esta tentativa não será salva.',
          style: AppTheme.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sair',
              style: TextStyle(color: QuizColors.wrong),
            ),
          ),
        ],
      ),
    );
    return quit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final total = _quiz.questions.length;
    final accent = QuizColors.forQuiz(
      color: _quiz.color,
      topic: _quiz.topic,
      title: _quiz.title,
    );
    final rightChosen = _answered && _answer == _question.correct;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmQuit()) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.creamBackground,
        appBar: AppBar(
          titleSpacing: 0,
          title: Text(
            _quiz.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.valueBold,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: QuizChip(
                  icon: Icons.star_rounded,
                  label: '$_rightSoFar',
                  color: QuizColors.right,
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(30),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Text('${_index + 1}/$total', style: AppTheme.caption),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: (_index + (_answered ? 1 : 0)) / total),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 10,
                          backgroundColor: accent.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(accent),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: quizMaxWidth),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0.15, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: ListView(
                    key: ValueKey(_index),
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _buildQuestionCard(accent),
                      const SizedBox(height: 14),
                      for (var i = 0; i < _question.options.length; i++)
                        _buildOption(i),
                      if (_answered) ...[
                        const SizedBox(height: 4),
                        _buildVerdictBanner(rightChosen),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (rightChosen)
              Positioned.fill(
                child: QuizConfetti(trigger: _feedbackTick, pieces: 40),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: !_answered
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Center(
                      heightFactor: 1,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: quizMaxWidth - 32,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _next,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _isLast
                                        ? Icons.emoji_events_outlined
                                        : Icons.arrow_forward_rounded,
                                  ),
                            label: Text(_isLast ? 'Ver resultado' : 'Próxima'),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Color accent) {
    final q = _question;
    return Container(
      decoration: AppTheme.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 6, color: accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: QuizChip(
                    label: 'Pergunta ${_index + 1}',
                    color: accent,
                  ),
                ),
                if (q.contextText != null && q.contextText!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusXSmall,
                      ),
                      border: Border(left: BorderSide(color: accent, width: 4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TEXTO BASE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          q.contextText!,
                          style: AppTheme.bodyText.copyWith(
                            fontSize: 14.5,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (q.imageUrl != null && q.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  QuizNetworkImage(url: q.imageUrl!, caption: q.imageCaption),
                ],
                const SizedBox(height: 14),
                Text(
                  q.prompt,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkBrown,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(int i) {
    final q = _question;
    final option = q.options[i];
    final letter = quizLetters[i];
    final color = QuizColors.forOption(i);
    final isCorrect = i == q.correctIndex;
    final isChosen = _answer == letter;

    // Before answering every option wears its own color; afterwards only
    // the right one (green) and a wrong pick (red) stay bright.
    Color border = color.withValues(alpha: 0.35);
    Color badge = color;
    Color background = AppTheme.white;
    double opacity = 1;
    IconData? trailing;
    if (_answered) {
      if (isCorrect) {
        border = QuizColors.right;
        badge = QuizColors.right;
        background = QuizColors.right.withValues(alpha: 0.08);
        trailing = Icons.check_circle_rounded;
      } else if (isChosen) {
        border = QuizColors.wrong;
        badge = QuizColors.wrong;
        background = QuizColors.wrong.withValues(alpha: 0.07);
        trailing = Icons.cancel_rounded;
      } else {
        border = AppTheme.borderBrown.withValues(alpha: 0.2);
        opacity = 0.75;
      }
    }

    Widget tile = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: border,
          width: isChosen || (_answered && isCorrect) ? 2.2 : 1.5,
        ),
        boxShadow: _answered ? null : AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: _answered ? null : () => _choose(i),
          splashColor: color.withValues(alpha: 0.15),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    QuizLetterBadge(
                      letter: letter,
                      color: badge,
                      filled: _answered && (isCorrect || isChosen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          option.text,
                          style: const TextStyle(
                            fontSize: 15.5,
                            color: AppTheme.darkBrown,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(trailing, color: badge, size: 24),
                      ),
                    ],
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !_answered || option.explanation.isEmpty
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 10, left: 46),
                          child: Text(
                            option.explanation,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: isCorrect
                                  ? const Color(0xFF1F6B3E)
                                  : AppTheme.lightBrown,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    tile = AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: opacity,
      child: tile,
    );
    if (_answered && isChosen && !isCorrect) {
      tile = QuizShake(trigger: _feedbackTick, child: tile);
    } else if (_answered && isCorrect) {
      tile = QuizPop(trigger: _feedbackTick, child: tile);
    }
    return tile;
  }

  Widget _buildVerdictBanner(bool right) {
    final color = right ? QuizColors.right : QuizColors.wrong;
    return TweenAnimationBuilder<double>(
      key: ValueKey('verdict$_index'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(
        scale: 0.8 + 0.2 * t,
        child: Opacity(opacity: t.clamp(0, 1), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Row(
          children: [
            Text(right ? '🎉' : '🤔', style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                right
                    ? 'Acertou! Resposta ${_question.correct}.'
                    : 'Quase! A certa é a ${_question.correct}. '
                          'Veja as explicações acima.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Final score with a counting-up ring, confetti for good scores, and a
/// per-question review.
class QuizResultScreen extends StatelessWidget {
  final Quiz quiz;
  final String answers;
  final int durationSeconds;
  final String? saveError;

  const QuizResultScreen({
    super.key,
    required this.quiz,
    required this.answers,
    required this.durationSeconds,
    this.saveError,
  });

  @override
  Widget build(BuildContext context) {
    final total = quiz.questions.length;
    final right = quiz.score(answers);
    final fraction = total == 0 ? 0.0 : right / total;
    final color = QuizColors.forScore(fraction);
    final (emoji, phrase) = quizVerdict(fraction);
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;

    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(title: const Text('Resultado')),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: quizMaxWidth),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fraction),
                      duration: const Duration(milliseconds: 1400),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => SizedBox(
                        width: 180,
                        height: 180,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: value,
                              strokeWidth: 14,
                              strokeCap: StrokeCap.round,
                              backgroundColor: color.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation(
                                QuizColors.forScore(value),
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${(value * 100).round()}%',
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w900,
                                      color: QuizColors.forScore(value),
                                    ),
                                  ),
                                  Text(
                                    '$right de $total',
                                    style: AppTheme.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, t, child) =>
                        Transform.scale(scale: t, child: child),
                    child: Text(
                      emoji,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phrase,
                    textAlign: TextAlign.center,
                    style: AppTheme.headingMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tempo: ${minutes > 0 ? '${minutes}min ' : ''}${seconds}s',
                    textAlign: TextAlign.center,
                    style: AppTheme.caption,
                  ),
                  if (saveError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: QuizColors.wrong.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                      ),
                      child: Text(
                        'Não foi possível salvar esta tentativa: $saveError',
                        style: const TextStyle(
                          color: QuizColors.wrong,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text('Revisão', style: AppTheme.sectionTitle),
                  const SizedBox(height: 10),
                  for (var i = 0; i < total; i++) _reviewRow(i),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            foregroundColor: AppTheme.darkBrown,
                            side: BorderSide(color: AppTheme.borderBrown),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                          ),
                          child: const Text('Voltar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuizPlayScreen(quiz: quiz),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: AppTheme.primaryOrange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.replay),
                          label: const Text('Refazer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (fraction >= 0.6)
            const Positioned.fill(
              child: QuizConfetti(playOnStart: true, pieces: 90),
            ),
        ],
      ),
    );
  }

  Widget _reviewRow(int i) {
    final q = quiz.questions[i];
    final given = i < answers.length ? answers[i] : quizBlank;
    final ok = given == q.correct;
    final givenIndex = quizLetters.indexOf(given);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border(
          left: BorderSide(
            color: ok ? QuizColors.right : QuizColors.wrong,
            width: 4,
          ),
        ),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: ok ? QuizColors.right : QuizColors.wrong,
          ),
          title: Text(
            '${i + 1}. ${q.prompt}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkBrown,
            ),
          ),
          subtitle: Text(
            ok
                ? 'Você marcou $given'
                : 'Você marcou ${given == quizBlank ? '—' : given} · certa: ${q.correct}',
            style: AppTheme.caption,
          ),
          children: [
            if (!ok && givenIndex >= 0 && givenIndex < q.options.length)
              _explanation(given, q.options[givenIndex], QuizColors.wrong),
            if (q.correctIndex >= 0 && q.correctIndex < q.options.length)
              _explanation(
                q.correct,
                q.options[q.correctIndex],
                QuizColors.right,
              ),
          ],
        ),
      ),
    );
  }

  Widget _explanation(String letter, QuizOption option, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuizLetterBadge(letter: letter, color: color, filled: true, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.text,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkBrown,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  option.explanation,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppTheme.lightBrown,
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
