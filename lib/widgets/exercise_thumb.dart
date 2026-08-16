import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/exercise.dart';
import 'remote_image.dart';

/// 'assets/exercises/Foo.mp4' -> 'assets/exercise_posters/Foo.jpg'. The
/// posters are generated from the videos themselves (see
/// scripts/generate_exercise_posters.*), so deriving the path keeps them
/// in sync without a second database column.
String? exercisePosterPath(String? videoPath) {
  if (videoPath == null || !videoPath.endsWith('.mp4')) return null;
  final name = videoPath.split('/').last;
  final base = name.substring(0, name.length - 4);
  return 'assets/exercise_posters/$base.jpg';
}

/// Square thumbnail for one exercise: the poster frame pulled from its
/// video, falling back to the hand-uploaded photo in the "habits" bucket
/// and then to a placeholder icon. The seeded catalog has videos but no
/// image_path, so without the poster these all render as bare icons.
class ExerciseThumb extends StatelessWidget {
  final Exercise? exercise;
  final double size;

  const ExerciseThumb({
    super.key,
    required this.exercise,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = RemoteImage(
      path: exercise?.imagePath,
      width: size,
      height: size,
      placeholder: Icons.fitness_center,
    );
    final poster = exercisePosterPath(exercise?.videoPath);
    if (poster == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusXSmall),
      child: Image.asset(
        poster,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
