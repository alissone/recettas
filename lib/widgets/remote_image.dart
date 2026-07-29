import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/supabase_service.dart';

/// A picture stored in the "habits" bucket. The bucket is private, so the
/// URL has to be signed; SupabaseService.habitImageUrl memoizes it, which
/// also keeps Flutter's ImageCache key stable across rebuilds.
///
/// Falls back to a soft placeholder whenever [path] is null, the signing
/// call fails, or the object is missing.
class RemoteImage extends StatelessWidget {
  final String? path;
  final double width;
  final double height;
  final BoxFit fit;
  final IconData placeholder;
  final BorderRadius? borderRadius;

  const RemoteImage({
    super.key,
    required this.path,
    this.width = 56,
    this.height = 56,
    this.fit = BoxFit.cover,
    this.placeholder = Icons.image_outlined,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ??
        BorderRadius.circular(AppTheme.radiusXSmall);
    final imagePath = path;

    Widget child;
    if (imagePath == null || imagePath.isEmpty) {
      child = _buildPlaceholder();
    } else {
      child = FutureBuilder<String>(
        future: SupabaseService.habitImageUrl(imagePath),
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (url == null) return _buildPlaceholder();
          return Image.network(
            url,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) => _buildPlaceholder(),
          );
        },
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: width, height: height, child: child),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppTheme.lightPeach,
      child: Icon(
        placeholder,
        size: (width < height ? width : height) * 0.4,
        color: AppTheme.mediumBrown.withValues(alpha: 0.5),
      ),
    );
  }
}
