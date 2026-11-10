/// Multiple-choice quizzes. The JSON format is documented in
/// docs/quiz-format.md; these classes mirror it one to one.
library;

const quizLetters = ['A', 'B', 'C', 'D', 'E'];

/// Marker for a question left blank in [QuizAttempt.answers].
const quizBlank = '-';

/// What the quiz list needs: everything except the questions, so the
/// list query stays small (the full content loads on tap).
class QuizSummary {
  final String id;
  final String title;
  final String? topic;
  final String? description;
  final int questionCount;
  final DateTime? createdAt;

  /// True for quizzes shipped in assets/quizzes/ rather than read from
  /// Supabase.
  final bool bundled;

  const QuizSummary({
    required this.id,
    required this.title,
    this.topic,
    this.description,
    required this.questionCount,
    this.createdAt,
    this.bundled = false,
  });

  factory QuizSummary.fromRow(Map<String, dynamic> row) => QuizSummary(
    id: row['id'] as String,
    title: (row['title'] as String?) ?? 'Sem título',
    topic: row['topic'] as String?,
    description: row['description'] as String?,
    questionCount: (row['question_count'] as num?)?.toInt() ?? 0,
    createdAt: row['created_at'] == null
        ? null
        : DateTime.tryParse(row['created_at'] as String)?.toLocal(),
  );
}

class Quiz {
  final String id;
  final String title;
  final String? topic;
  final String? description;
  final String? source;

  /// Optional "#RRGGBB" accent; otherwise one is derived from the topic.
  final String? color;
  final List<QuizQuestion> questions;

  const Quiz({
    required this.id,
    required this.title,
    this.topic,
    this.description,
    this.source,
    this.color,
    required this.questions,
  });

  /// [id] wins over `json['id']` - the table row's id is the real one.
  factory Quiz.fromJson(Map<String, dynamic> json, {String? id}) => Quiz(
    id: id ?? json['id'] as String,
    title: (json['title'] as String?) ?? 'Sem título',
    topic: json['topic'] as String?,
    description: json['description'] as String?,
    source: json['source'] as String?,
    color: json['color'] as String?,
    questions: ((json['questions'] as List?) ?? const [])
        .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
        .toList(),
  );

  QuizSummary get summary => QuizSummary(
    id: id,
    title: title,
    topic: topic,
    description: description,
    questionCount: questions.length,
  );

  /// Correct answers in [answers] (one letter per question). Answers past
  /// the end, or for questions that no longer exist, are ignored.
  int score(String answers) {
    var right = 0;
    for (var i = 0; i < questions.length && i < answers.length; i++) {
      if (answers[i] == questions[i].correct) right++;
    }
    return right;
  }
}

class QuizQuestion {
  final String prompt;

  /// Base text the question is about (a passage, a law article...).
  final String? contextText;

  /// Image the question is about, from the internet.
  final String? imageUrl;
  final String? imageCaption;
  final List<QuizOption> options;

  /// Letter of the right option, "A".."E".
  final String correct;

  const QuizQuestion({
    required this.prompt,
    this.contextText,
    this.imageUrl,
    this.imageCaption,
    required this.options,
    required this.correct,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final context = json['context'] as Map<String, dynamic>?;
    return QuizQuestion(
      prompt: json['prompt'] as String,
      contextText: context?['text'] as String?,
      imageUrl: context?['image_url'] as String?,
      imageCaption: context?['image_caption'] as String?,
      options: (json['options'] as List)
          .map((o) => QuizOption.fromJson(o as Map<String, dynamic>))
          .toList(),
      correct: (json['correct'] as String).trim().toUpperCase(),
    );
  }

  int get correctIndex => quizLetters.indexOf(correct);
}

class QuizOption {
  final String text;

  /// Why this option is right - or why it is wrong.
  final String explanation;

  const QuizOption({required this.text, required this.explanation});

  factory QuizOption.fromJson(Map<String, dynamic> json) => QuizOption(
    text: json['text'] as String,
    explanation: (json['explanation'] as String?) ?? '',
  );
}

class QuizAttempt {
  final String quizId;
  final String answers;
  final int? durationSeconds;
  final DateTime createdAt;

  const QuizAttempt({
    required this.quizId,
    required this.answers,
    this.durationSeconds,
    required this.createdAt,
  });

  factory QuizAttempt.fromRow(Map<String, dynamic> row) => QuizAttempt(
    quizId: row['quiz_id'] as String,
    answers: row['answers'] as String,
    durationSeconds: (row['duration_seconds'] as num?)?.toInt(),
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
  );
}
