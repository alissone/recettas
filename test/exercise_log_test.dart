import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/models/exercise.dart';
import 'package:recettas/models/exercise_log.dart';
import 'package:recettas/models/gym_entry.dart';

const _squat = Exercise(
  id: 'e1',
  name: 'Barbell Squat',
  namePt: 'Agachamento com Barra',
  muscleGroup: 'Pernas',
);

const _dips = Exercise(
  id: 'e2',
  name: 'Parallel Bar Dips',
  namePt: 'Paralelas',
  muscleGroup: 'Tríceps',
);

GymEntry _entry(
  Exercise exercise,
  String date, {
  int sets = 3,
  int reps = 10,
  double? weight,
}) {
  return GymEntry(
    id: '${exercise.id}-$date',
    userId: 'u1',
    entryDate: date,
    exerciseId: exercise.id,
    sets: sets,
    reps: reps,
    weight: weight,
    exercise: exercise,
  );
}

void main() {
  group('ExerciseLog.group', () {
    test('buckets by exercise, newest session first', () {
      final logs = ExerciseLog.group([
        _entry(_squat, '2026-08-01', weight: 60),
        _entry(_dips, '2026-08-10'),
        _entry(_squat, '2026-08-12', weight: 70),
      ]);

      expect(logs.length, 2);
      // Most recently trained exercise leads.
      expect(logs.first.exercise.id, 'e1');
      expect(logs.first.entries.first.entryDate, '2026-08-12');
      expect(logs.first.entries.last.entryDate, '2026-08-01');
      expect(logs.first.sessions, 2);
      expect(logs.last.exercise.id, 'e2');
    });

    test('drops rows whose exercise is missing from the catalog', () {
      final orphan = GymEntry(
        id: 'x',
        userId: 'u1',
        entryDate: '2026-08-12',
        exerciseId: 'gone',
        sets: 3,
        reps: 10,
      );
      expect(ExerciseLog.group([orphan]), isEmpty);
    });
  });

  group('aggregates', () {
    ExerciseLog squatLog(List<GymEntry> entries) =>
        ExerciseLog.group(entries).first;

    test('PR is the heaviest session, not the latest', () {
      final log = squatLog([
        _entry(_squat, '2026-08-01', weight: 60),
        _entry(_squat, '2026-08-08', weight: 80),
        _entry(_squat, '2026-08-12', weight: 70),
      ]);

      expect(log.prWeight, 80);
      expect(log.prEntry!.entryDate, '2026-08-08');
      expect(log.lastDate, DateTime(2026, 8, 12));
      expect(log.firstDate, DateTime(2026, 8, 1));
    });

    test('progress compares the first and last weighted sessions', () {
      final log = squatLog([
        _entry(_squat, '2026-08-01', weight: 60),
        _entry(_squat, '2026-08-08', weight: 80),
        _entry(_squat, '2026-08-12', weight: 70),
      ]);

      expect(log.weightProgress, 10);
      expect(log.weighted.first.entryDate, '2026-08-01');
      expect(log.weighted.last.entryDate, '2026-08-12');
    });

    test('bodyweight work has no weight aggregates', () {
      final log = ExerciseLog.group([
        _entry(_dips, '2026-08-10'),
        _entry(_dips, '2026-08-12'),
      ]).first;

      expect(log.prWeight, isNull);
      expect(log.bestOneRepMax, isNull);
      expect(log.weightProgress, isNull);
      expect(log.totalVolume, 0);
    });

    test('a single weighted session has no progress to report', () {
      final log = squatLog([_entry(_squat, '2026-08-01', weight: 60)]);
      expect(log.weightProgress, isNull);
      expect(log.prWeight, 60);
    });

    test('volume sums sets x reps x weight', () {
      final log = squatLog([
        _entry(_squat, '2026-08-01', sets: 3, reps: 10, weight: 60),
        _entry(_squat, '2026-08-12', sets: 4, reps: 8, weight: 70),
      ]);

      expect(log.totalVolume, 3 * 10 * 60 + 4 * 8 * 70);
      expect(log.bestVolume, 4 * 8 * 70);
    });

    test('estimated 1RM favours the best set, not the heaviest', () {
      // 60 kg x 12 (Epley: 84) beats 70 kg x 3 (77) despite the lighter bar.
      final log = squatLog([
        _entry(_squat, '2026-08-01', reps: 12, weight: 60),
        _entry(_squat, '2026-08-12', reps: 3, weight: 70),
      ]);

      expect(log.prWeight, 70);
      expect(log.bestOneRepMax, closeTo(84, 0.001));
    });
  });

  group('formatWeight', () {
    test('drops the trailing zero but keeps real decimals', () {
      expect(formatWeight(60), '60');
      expect(formatWeight(62.5), '62.5');
    });
  });
}
