import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_theme.dart';
import '../models/list_invite.dart';
import '../services/supabase_service.dart';

/// Invites that share the Gastos + Compras lists, managed like the
/// receipt queue: sent invites wait for the other person to respond,
/// received invites are accepted or declined here.
class ListInvitesScreen extends StatefulWidget {
  const ListInvitesScreen({super.key});

  @override
  State<ListInvitesScreen> createState() => _ListInvitesScreenState();
}

class _ListInvitesScreenState extends State<ListInvitesScreen> {
  List<ListInvite> _sent = [];
  List<ListInvite> _received = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SupabaseService.getSentInvites(),
        SupabaseService.getReceivedInvites(),
      ]);
      if (mounted) {
        setState(() {
          _sent = results[0];
          _received = results[1];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _invite() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => const _InviteDialog(),
    );
    if (email == null || email.isEmpty) return;
    try {
      await SupabaseService.sendListInvite(email);
      _snack('Convite enviado para $email', success: true);
    } on PostgrestException catch (e) {
      _snack(e.code == '23505'
          ? 'Você já convidou este e-mail'
          : 'Erro ao convidar: ${e.message}');
    } catch (e) {
      _snack('Erro ao convidar: $e');
    }
    _load();
  }

  Future<void> _respond(ListInvite invite, bool accept) async {
    try {
      await SupabaseService.respondToListInvite(invite.id,
          accept: accept);
      if (accept) {
        _snack(
          'Convite aceito — a lista de '
          '${invite.inviterName ?? 'outra pessoa'} aparece em '
          'Gastos e Compras',
          success: true,
        );
      }
    } catch (e) {
      _snack('Erro ao responder: $e');
    }
    _load();
  }

  Future<void> _delete(ListInvite invite) async {
    try {
      await SupabaseService.deleteListInvite(invite.id);
    } catch (e) {
      _snack('Erro ao excluir: $e');
    }
    _load();
  }

  void _snack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor:
          success ? Colors.green.shade600 : AppTheme.darkBrown,
    ));
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title: const Text('Listas Compartilhadas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'invites_fab',
        onPressed: _invite,
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primaryOrange))
          : _sent.isEmpty && _received.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppTheme.primaryOrange,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
                    children: [
                      if (_received.isNotEmpty) ...[
                        _sectionTitle('Convites recebidos'),
                        for (final invite in _received)
                          _buildReceivedCard(invite),
                        const SizedBox(height: 12),
                      ],
                      if (_sent.isNotEmpty) ...[
                        _sectionTitle('Convites enviados'),
                        for (final invite in _sent)
                          _buildSentCard(invite),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(text, style: AppTheme.sectionTitle),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add_outlined,
                size: 64,
                color: AppTheme.primaryOrange.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('Nenhum convite', style: AppTheme.sectionTitle),
            const SizedBox(height: 8),
            const Text(
              'Toque em + para convidar alguém por e-mail.\n'
              'Quem aceitar passa a ver e editar suas listas de '
              'Gastos e Compras.',
              style: AppTheme.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedCard(ListInvite invite) {
    final pending = invite.status == ListInviteStatus.pending;
    final accepted = invite.status == ListInviteStatus.accepted;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Icon(
            accepted ? Icons.people : Icons.mail_outline,
            color: accepted
                ? Colors.green.shade600
                : AppTheme.primaryOrange,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.inviterName ?? 'Convite',
                  style: AppTheme.valueBold.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  pending
                      ? 'Convidou você para as listas de Gastos e Compras'
                      : accepted
                          ? 'Você participa das listas desta pessoa'
                          : 'Convite recusado',
                  style: AppTheme.caption
                      .copyWith(fontWeight: FontWeight.w400),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (accepted)
            IconButton(
              tooltip: 'Sair da lista',
              icon: Icon(Icons.exit_to_app,
                  color: Colors.red.shade300, size: 22),
              onPressed: () => _respond(invite, false),
            )
          else ...[
            IconButton(
              tooltip: 'Aceitar',
              icon: Icon(Icons.check_circle_outline,
                  color: Colors.green.shade600, size: 26),
              onPressed: () => _respond(invite, true),
            ),
            if (pending)
              IconButton(
                tooltip: 'Recusar',
                icon: Icon(Icons.cancel_outlined,
                    color: Colors.red.shade300, size: 24),
                onPressed: () => _respond(invite, false),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSentCard(ListInvite invite) {
    final (icon, color, label) = switch (invite.status) {
      ListInviteStatus.pending => (
          Icons.schedule,
          AppTheme.mediumBrown,
          'Aguardando resposta',
        ),
      ListInviteStatus.accepted => (
          Icons.check_circle,
          Colors.green.shade600,
          'Aceito — a pessoa vê e edita suas listas',
        ),
      ListInviteStatus.declined => (
          Icons.cancel,
          Colors.red.shade400,
          'Recusado',
        ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.inviteeEmail,
                  style: AppTheme.valueBold.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w400, color: color),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Revogar convite',
            icon: Icon(Icons.delete_outline,
                color: Colors.red.shade300, size: 22),
            onPressed: () => _delete(invite),
          ),
        ],
      ),
    );
  }
}

/// Owns the email controller so it is only disposed once the dialog's
/// route (including the close animation) is fully gone; pops the
/// trimmed e-mail on send.
class _InviteDialog extends StatefulWidget {
  const _InviteDialog();

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _controller.text.trim();
    if (!email.contains('@')) return;
    Navigator.pop(context, email);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.creamBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title:
          const Text('Convidar por e-mail', style: AppTheme.sectionTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration:
                const InputDecoration(hintText: 'email@exemplo.com'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Text(
            'Quem aceitar o convite vê e edita suas listas de Gastos '
            'e Compras.',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar',
              style: TextStyle(color: AppTheme.mediumBrown)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryOrange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Convidar'),
        ),
      ],
    );
  }
}
