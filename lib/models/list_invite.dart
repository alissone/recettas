enum ListInviteStatus { pending, accepted, declined }

/// Invite giving another user (by email) access to the inviter's
/// Gastos + Compras lists. Managed like the receipt_jobs queue: one
/// row per invite, the invitee flips the status when responding.
class ListInvite {
  final String id;
  final String inviterId;
  final String inviteeEmail;

  /// Filled once the invitee responds.
  final String? inviteeId;
  final ListInviteStatus status;
  final DateTime? createdAt;

  /// Inviter's display name (embedded profile), present on received
  /// invites.
  final String? inviterName;

  ListInvite({
    required this.id,
    required this.inviterId,
    required this.inviteeEmail,
    this.inviteeId,
    required this.status,
    this.createdAt,
    this.inviterName,
  });

  factory ListInvite.fromJson(Map<String, dynamic> json) {
    final inviter = json['inviter'] as Map<String, dynamic>?;
    return ListInvite(
      id: json['id'],
      inviterId: json['inviter_id'],
      inviteeEmail: json['invitee_email'] ?? '',
      inviteeId: json['invitee_id'],
      status: ListInviteStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ListInviteStatus.pending,
      ),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      inviterName: inviter?['display_name'] ?? inviter?['email'],
    );
  }
}

/// A Gastos/Compras list the signed-in user can use: their own, or one
/// shared with them through an accepted invite.
class ListOwner {
  final String id;
  final String name;
  final bool isMine;

  const ListOwner({
    required this.id,
    required this.name,
    required this.isMine,
  });
}
