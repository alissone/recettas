import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/list_invite.dart';

/// Pill tabs shown at the top of Gastos and Compras when more than one
/// accessible list has items: the user's own list plus the people who
/// shared theirs.
class ListOwnerTabs extends StatelessWidget {
  final List<ListOwner> owners;
  final String activeOwnerId;
  final ValueChanged<ListOwner> onSelect;

  const ListOwnerTabs({
    super.key,
    required this.owners,
    required this.activeOwnerId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final owner in owners) ...[
              _buildTab(owner),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTab(ListOwner owner) {
    final active = owner.id == activeOwnerId;
    return GestureDetector(
      onTap: () => onSelect(owner),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryOrange : AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              owner.isMine ? Icons.person_outline : Icons.people_outline,
              size: 16,
              color: active ? Colors.white : AppTheme.mediumBrown,
            ),
            const SizedBox(width: 6),
            Text(
              owner.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppTheme.darkBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
