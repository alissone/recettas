import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/models/quiz.dart';

void main() {
  final files = Directory('assets/quizzes')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();

  test('bundled quizzes parse and are well formed', () {
    expect(files, isNotEmpty);
    final ids = <String>{};
    for (final file in files) {
      final quiz = Quiz.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      expect(ids.add(quiz.id), isTrue, reason: 'duplicate id ${quiz.id}');
      expect(quiz.questions, isNotEmpty);
      for (final q in quiz.questions) {
        expect(q.options.length, inInclusiveRange(2, 5));
        expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1));
        expect(q.options.every((o) => o.explanation.isNotEmpty), isTrue);
      }
    }
  });

  test('score compares answers by position and ignores blanks', () {
    final quiz = Quiz.fromJson(
      jsonDecode(files.first.readAsStringSync()) as Map<String, dynamic>,
    );
    final key = quiz.questions.map((q) => q.correct).join();
    expect(quiz.score(key), quiz.questions.length);
    expect(quiz.score(''), 0);
    expect(quiz.score(quizBlank * quiz.questions.length), 0);
    // Only the first answer right.
    final wrongFirst =
        key[0] +
        key.substring(1).split('').map((c) => c == 'A' ? 'B' : 'A').join();
    expect(quiz.score(wrongFirst), 1);
  });
}
