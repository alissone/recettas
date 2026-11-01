import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_theme.dart';
import '../models/contact.dart';
import '../models/todo_tags.dart';
import '../services/supabase_service.dart';
import '../services/todo_repository.dart';

/// "Pessoas": the people the user can tag on a todo with "@nickname".
/// Each one is an email plus a nickname that only exists on this side —
/// it's the shortcut typed after "@", not the other person's real name.
/// A tagged todo also shows up in that person's list.
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  List<Contact> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final contacts = await SupabaseService.getContacts();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _snack('Erro ao carregar: $e');
    }
  }

  /// Opens the dialog for a new contact, or to edit [contact].
  Future<void> _edit([Contact? contact]) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _ContactDialog(contact: contact),
    );
    if (result == null) return;
    final (nickname, email) = result;
    try {
      if (contact == null) {
        await SupabaseService.addContact(nickname: nickname, email: email);
      } else {
        await SupabaseService.updateContact(contact.id,
            nickname: nickname, email: email);
      }
    } on PostgrestException catch (e) {
      _snack(e.code == '23505'
          ? 'Já existe alguém com esse apelido ou e-mail'
          : 'Erro ao salvar: ${e.message}');
    } catch (e) {
      _snack('Erro ao salvar: $e');
    }
    _afterChange();
  }

  Future<void> _delete(Contact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        title: Text('Remover @${contact.nickname}?',
            style: AppTheme.sectionTitle),
        content: const Text(
          'Tarefas já marcadas continuam compartilhadas até serem '
          'editadas; o "@" no texto deixa de ser reconhecido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: TextStyle(color: AppTheme.mediumBrown)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remover',
                style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.deleteContact(contact.id);
    } catch (e) {
      _snack('Erro ao remover: $e');
    }
    _afterChange();
  }

  /// Reloads this list and pulls the contacts into the todo cache, which
  /// is what "@" tags resolve against.
  void _afterChange() {
    _load();
    TodoRepository.instance.sync();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.darkBrown,
    ));
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title: const Text('Pessoas'),
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
        heroTag: 'people_fab',
        onPressed: () => _edit(),
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primaryOrange))
          : _contacts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppTheme.primaryOrange,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
                    children: [
                      for (final contact in _contacts) _buildCard(contact),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.alternate_email,
                size: 64,
                color: AppTheme.primaryOrange.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('Ninguém ainda', style: AppTheme.sectionTitle),
            const SizedBox(height: 8),
            const Text(
              'Toque em + para adicionar alguém pelo e-mail e dar um '
              'apelido.\nEscreva @apelido numa tarefa para marcar a '
              'pessoa — a tarefa aparece na lista dela também.',
              style: AppTheme.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Contact contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: () => _edit(contact),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    AppTheme.primaryOrange.withValues(alpha: 0.15),
                child: Text(
                  contact.nickname.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${contact.nickname}',
                      style: AppTheme.valueBold.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.email,
                      style: AppTheme.caption
                          .copyWith(fontWeight: FontWeight.w400),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!contact.hasAccount) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Sem conta no app — as tarefas não chegam até '
                        'essa pessoa',
                        style: AppTheme.caption.copyWith(
                          fontWeight: FontWeight.w400,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remover',
                icon: Icon(Icons.delete_outline,
                    color: Colors.red.shade300, size: 22),
                onPressed: () => _delete(contact),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nickname + email form. Owns its controllers so they're disposed only
/// after the dialog route is gone; pops `(nickname, email)` on save.
class _ContactDialog extends StatefulWidget {
  final Contact? contact;

  const _ContactDialog({this.contact});

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  late final _nickname =
      TextEditingController(text: widget.contact?.nickname ?? '');
  late final _email =
      TextEditingController(text: widget.contact?.email ?? '');
  String? _error;

  @override
  void dispose() {
    _nickname.dispose();
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    final nickname = _nickname.text.trim().replaceFirst(RegExp('^@'), '');
    final email = _email.text.trim();
    String? error;
    if (!TodoTags.nicknamePattern.hasMatch(nickname)) {
      error = 'Apelido: uma palavra só, sem espaços '
          '(letras, números, _ . -)';
    } else if (TodoTags.isTodayWord(nickname)) {
      error = '"$nickname" é reservado para @today';
    } else if (!email.contains('@')) {
      error = 'E-mail inválido';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, (nickname, email));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.creamBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: Text(
        widget.contact == null ? 'Adicionar pessoa' : 'Editar pessoa',
        style: AppTheme.sectionTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nickname,
            autofocus: widget.contact == null,
            decoration: const InputDecoration(
              labelText: 'Apelido',
              prefixText: '@',
              hintText: 'Ana',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              hintText: 'email@exemplo.com',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Text(
            _error ??
                'O apelido só existe para você: é o que você escreve '
                    'depois do @ para marcar a pessoa numa tarefa.',
            style: AppTheme.caption.copyWith(
              fontWeight: FontWeight.w400,
              color: _error != null ? Colors.red.shade400 : null,
            ),
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
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
