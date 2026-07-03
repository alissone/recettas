import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/todo_repository.dart';

/// Tiny status dot for the header: spinner while fetching/uploading,
/// cloud-off while offline with queued changes, subtle check when synced.
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: TodoRepository.instance.syncState,
      builder: (context, state, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: SizedBox(
            key: ValueKey(state),
            width: 24,
            height: 24,
            child: Center(child: _icon(state)),
          ),
        );
      },
    );
  }

  Widget _icon(SyncState state) {
    switch (state) {
      case SyncState.syncing:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primaryOrange,
          ),
        );
      case SyncState.offline:
        return Icon(
          Icons.cloud_off_outlined,
          size: 18,
          color: AppTheme.mediumBrown.withValues(alpha: 0.7),
        );
      case SyncState.synced:
        return Icon(
          Icons.cloud_done_outlined,
          size: 18,
          color: AppTheme.mediumBrown.withValues(alpha: 0.35),
        );
    }
  }
}
