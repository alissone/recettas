import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/category_base.dart';

/// Full-screen "drag onto a category" overlay: one squircle per category
/// plus "Nenhuma". The swipe that opened it keeps going, so the parent
/// forwards drag positions here via a `GlobalKey<CategorizeOverlayState>`;
/// squircles can also just be tapped.
class CategorizeOverlay extends StatefulWidget {
  final List<CategoryBase> categories;

  /// Shown under the title so the user knows what is being categorized.
  final String itemLabel;

  /// Called with the chosen category, or null for "Nenhuma".
  final ValueChanged<CategoryBase?> onAssign;
  final VoidCallback onDismiss;

  const CategorizeOverlay({
    super.key,
    required this.categories,
    required this.itemLabel,
    required this.onAssign,
    required this.onDismiss,
  });

  @override
  State<CategorizeOverlay> createState() => CategorizeOverlayState();
}

class CategorizeOverlayState extends State<CategorizeOverlay> {
  late List<GlobalKey> _squircleKeys;
  int? _highlighted;

  @override
  void initState() {
    super.initState();
    _makeKeys();
  }

  @override
  void didUpdateWidget(covariant CategorizeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categories.length != widget.categories.length) {
      _makeKeys();
    }
  }

  void _makeKeys() {
    // +1 for the "Nenhuma" option.
    _squircleKeys =
        List.generate(widget.categories.length + 1, (_) => GlobalKey());
  }

  /// Highlights the squircle under the finger while the drag continues.
  void updateDrag(Offset globalPos) {
    setState(() => _highlighted = _hitTest(globalPos));
  }

  /// Assigns the squircle under the release point, or dismisses.
  void endDrag(Offset globalPos) {
    final index = _hitTest(globalPos);
    if (index != null) {
      _assign(index);
    } else {
      widget.onDismiss();
    }
  }

  int? _hitTest(Offset globalPos) {
    for (var i = 0; i < _squircleKeys.length; i++) {
      final box =
          _squircleKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.attached) {
        final local = box.globalToLocal(globalPos);
        if (box.paintBounds.contains(local)) return i;
      }
    }
    return null;
  }

  void _assign(int index) {
    widget.onAssign(index < widget.categories.length
        ? widget.categories[index]
        : null);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: widget.onDismiss,
        child: AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            color: AppTheme.darkBrown.withValues(alpha: 0.7),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Arraste pra uma categoria',
                    style: AppTheme.headingMedium
                        .copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.itemLabel,
                    style: AppTheme.bodyText
                        .copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
                      children: [
                        for (int i = 0;
                            i < widget.categories.length;
                            i++)
                          _buildSquircle(
                            key: _squircleKeys[i],
                            color: widget.categories[i].color,
                            label: widget.categories[i].name,
                            highlighted: _highlighted == i,
                            onTap: () => _assign(i),
                          ),
                        _buildSquircle(
                          key: _squircleKeys.last,
                          color: AppTheme.mediumBrown
                              .withValues(alpha: 0.4),
                          label: 'Nenhuma',
                          icon: Icons.close,
                          highlighted: _highlighted ==
                              widget.categories.length,
                          onTap: () =>
                              _assign(widget.categories.length),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Solte para cancelar',
                    style: AppTheme.caption
                        .copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSquircle({
    required GlobalKey key,
    required Color color,
    required String label,
    bool highlighted = false,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: highlighted ? 1.2 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: key,
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
                border: highlighted
                    ? Border.all(color: Colors.white, width: 3)
                    : null,
                boxShadow: highlighted
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 16,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, color: Colors.white, size: 28)
                    : Text(
                        label.isNotEmpty
                            ? label[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
