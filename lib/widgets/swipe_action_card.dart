import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Drag shell shared by the todo and purchase cards: swipe left past the
/// threshold deletes, swipe right hands the (still ongoing) drag over to
/// the categorize overlay via [onCategorizeStart] / drag callbacks.
class SwipeActionCard extends StatefulWidget {
  final Widget child;

  /// Right swipe shows the categorize hint only when there is something
  /// to categorize into.
  final bool canCategorize;
  final VoidCallback onDelete;
  final VoidCallback onCategorizeStart;
  final ValueChanged<Offset> onCategorizeDragUpdate;
  final ValueChanged<Offset> onCategorizeDragEnd;
  final VoidCallback? onTap;

  const SwipeActionCard({
    super.key,
    required this.child,
    required this.canCategorize,
    required this.onDelete,
    required this.onCategorizeStart,
    required this.onCategorizeDragUpdate,
    required this.onCategorizeDragEnd,
    this.onTap,
  });

  @override
  State<SwipeActionCard> createState() => _SwipeActionCardState();
}

class _SwipeActionCardState extends State<SwipeActionCard>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _categorizeTriggered = false;
  Offset _lastGlobalPos = Offset.zero;
  late AnimationController _springController;
  late Animation<double> _springAnim;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _springAnim = _springController.drive(Tween(begin: 0.0, end: 0.0));
    _springController.addListener(() {
      setState(() => _dragOffset = _springAnim.value);
    });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _springBack() {
    _springAnim = Tween(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(
          parent: _springController, curve: Curves.easeOut),
    );
    _springController.forward(from: 0);
  }

  void _onDragStart(DragStartDetails d) {
    _springController.stop();
    _categorizeTriggered = false;
    _dragOffset = 0;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _lastGlobalPos = d.globalPosition;

    if (_categorizeTriggered) {
      widget.onCategorizeDragUpdate(d.globalPosition);
      return;
    }

    setState(() {
      _dragOffset += d.delta.dx;
      _dragOffset = _dragOffset.clamp(-160.0, 160.0);
    });

    if (_dragOffset > 80 &&
        !_categorizeTriggered &&
        widget.canCategorize) {
      _categorizeTriggered = true;
      _springBack();
      widget.onCategorizeStart();
    }
  }

  void _onDragEnd(DragEndDetails d) {
    if (_categorizeTriggered) {
      widget.onCategorizeDragEnd(_lastGlobalPos);
      _categorizeTriggered = false;
      return;
    }

    if (_dragOffset < -100) {
      widget.onDelete();
    }
    _springBack();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          // Delete background (left swipe → right side)
          if (_dragOffset < 0)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_outline,
                    color: Colors.white, size: 24),
              ),
            ),
          // Categorize hint background (right swipe → left side)
          if (_dragOffset > 0 && widget.canCategorize)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange
                      .withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                child: const Icon(Icons.category_outlined,
                    color: AppTheme.primaryOrange, size: 24),
              ),
            ),
          // Card
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: GestureDetector(
              onTap: widget.onTap,
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
