import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/supabase_service.dart';

/// A picture stored in the "habits" bucket. The bucket is private, so the
/// URL has to be signed; SupabaseService.habitImageUrl memoizes it, which
/// also keeps Flutter's ImageCache key stable across rebuilds.
///
/// Stateful on purpose: the signing Future is resolved once in initState
/// and only re-resolved when [path] changes. Building it inside build()
/// would mint a request on every rebuild - a grid of these repainting
/// would fan out into dozens of storage calls, each able to trigger a
/// token refresh.
///
/// Falls back to a soft placeholder whenever [path] is null, the signing
/// call fails, or the object is missing.
class RemoteImage extends StatefulWidget {
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
  State<RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageState extends State<RemoteImage> {
  Future<String>? _url;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(RemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _resolve();
  }

  void _resolve() {
    final path = widget.path;
    _url = (path == null || path.isEmpty)
        ? null
        : SupabaseService.habitImageUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    final radius =
        widget.borderRadius ?? BorderRadius.circular(AppTheme.radiusXSmall);
    final url = _url;

    Widget child;
    if (url == null) {
      child = _buildPlaceholder();
    } else {
      child = FutureBuilder<String>(
        future: url,
        builder: (context, snapshot) {
          final resolved = snapshot.data;
          if (resolved == null) return _buildPlaceholder();
          return Image.network(
            resolved,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (_, _, _) => _buildPlaceholder(),
          );
        },
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: child,
      ),
    );
  }

  Widget _buildPlaceholder() {
    final shorter =
        widget.width < widget.height ? widget.width : widget.height;
    return Container(
      width: widget.width,
      height: widget.height,
      color: AppTheme.lightPeach,
      child: Icon(
        widget.placeholder,
        size: shorter * 0.4,
        color: AppTheme.mediumBrown.withValues(alpha: 0.5),
      ),
    );
  }
}
