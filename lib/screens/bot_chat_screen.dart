import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../app_theme.dart';
import '../models/bot_chat.dart';
import '../services/bot_chat_repository.dart';
import '../utils/dates.dart';
import '../widgets/bot_voice.dart';
import 'chat_list_screen.dart' show formatChatTime;

/// A one-tap question that attaches the todo list for the model.
class _QuickAction {
  final String label;
  final IconData icon;
  final String prompt;

  const _QuickAction(this.label, this.icon, this.prompt);
}

const _quickActions = [
  _QuickAction(
    'Resumir afazeres de hoje',
    Icons.summarize_outlined,
    'Faça um resumo rápido dos meus afazeres para hoje.',
  ),
  _QuickAction(
    'Quais são minhas prioridades?',
    Icons.flag_outlined,
    'Quais são minhas prioridades agora? Me diga por onde começar.',
  ),
];

/// One conversation with the local assistant. Like ChatRoomScreen, the
/// messages stream in from Supabase: sending is an insert, and the reply
/// shows up when the PC worker writes it - even if the app was closed in
/// the meantime.
class BotChatScreen extends StatefulWidget {
  final BotChat chat;

  const BotChatScreen({super.key, required this.chat});

  @override
  State<BotChatScreen> createState() => _BotChatScreenState();
}

class _BotChatScreenState extends State<BotChatScreen> {
  final _repo = BotChatRepository.instance;

  StreamSubscription<List<BotMessage>>? _subscription;
  List<BotMessage> _messages = [];
  bool _loading = true;
  String? _error;
  bool _sending = false;
  late String _title = widget.chat.title;
  late SttEngine _stt = widget.chat.stt;
  late String _voice = widget.chat.ttsVoice;

  @override
  void initState() {
    super.initState();
    _subscription = _repo
        .streamMessages(widget.chat.id)
        .listen(
          (messages) {
            if (!mounted) return;
            setState(() {
              _messages = messages;
              _loading = false;
              _error = null;
            });
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = '$e';
            });
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // --- Actions ---

  Future<void> _sendVoice(Uint8List bytes, double seconds) async {
    await _repo.sendVoice(widget.chat.id, bytes, seconds);
  }

  Future<void> _pickStt() async {
    final picked = await showModalBottomSheet<SttEngine>(
      context: context,
      backgroundColor: AppTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'Transcrição dos seus áudios',
                style: AppTheme.sectionTitle,
              ),
            ),
            for (final e in SttEngine.values)
              ListTile(
                leading: Icon(
                  e == _stt
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: e == _stt
                      ? AppTheme.primaryOrange
                      : AppTheme.mediumBrown,
                ),
                title: Text(e.label),
                subtitle: Text(e.hint),
                onTap: () => Navigator.pop(context, e),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || picked == _stt) return;
    final before = _stt;
    setState(() => _stt = picked);
    try {
      await _repo.setStt(widget.chat.id, picked);
    } catch (e) {
      if (mounted) setState(() => _stt = before);
      _snack('Não foi possível mudar (rodou a migração 048?): $e');
    }
  }

  Future<void> _pickVoice() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.creamBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scroll) => ListView(
          controller: scroll,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'Voz do assistente (Kokoro)',
                style: AppTheme.sectionTitle,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Usada quando você manda um áudio: a resposta volta falada. '
                'Escolha uma voz do idioma em que você conversa.',
                style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
              ),
            ),
            for (final v in KokoroVoice.all)
              ListTile(
                leading: Icon(
                  v.id == _voice
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: v.id == _voice
                      ? AppTheme.primaryOrange
                      : AppTheme.mediumBrown,
                ),
                title: Text(v.name),
                subtitle: Text(
                  '${v.language} · ${v.female ? 'feminina' : 'masculina'}',
                ),
                onTap: () => Navigator.pop(context, v.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || picked == _voice) return;
    final before = _voice;
    setState(() => _voice = picked);
    try {
      await _repo.setVoice(widget.chat.id, picked);
    } catch (e) {
      if (mounted) setState(() => _voice = before);
      _snack('Não foi possível mudar (rodou a migração 048?): $e');
    }
  }

  Future<void> _quick(_QuickAction action) async {
    if (_sending) return;
    setState(() => _sending = true);
    String snapshot;
    try {
      snapshot = await _repo.todoSnapshot();
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      _snack('Não foi possível ler os afazeres: $e');
      return;
    }
    if (mounted) setState(() => _sending = false);
    await _post(action.prompt, context: snapshot);
  }

  Future<bool> _post(String text, {String? context}) async {
    if (_sending) return false;
    setState(() => _sending = true);
    try {
      await _repo.send(widget.chat.id, text, context: context);
      return true;
    } catch (e) {
      _snack('Não foi possível enviar: $e');
      return false;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        title: const Text('Nome da conversa', style: AppTheme.sectionTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty || title == _title) return;
    try {
      await _repo.renameChat(widget.chat.id, title);
      if (mounted) setState(() => _title = title);
    } catch (e) {
      _snack('Não foi possível renomear: $e');
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDeleteBotChat(context, _title);
    if (!ok) return;
    try {
      await _repo.deleteChat(widget.chat.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Não foi possível apagar: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.darkBrown),
    );
  }

  void _showContext(BotMessage message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.creamBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Enviado junto para o assistente',
              style: AppTheme.sectionTitle,
            ),
            const SizedBox(height: 12),
            SelectableText(
              message.context ?? '',
              style: AppTheme.bodyText.copyWith(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const BotAvatar(size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _title,
                style: AppTheme.sectionTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            color: AppTheme.white,
            onSelected: (v) => switch (v) {
              'stt' => _pickStt(),
              'voice' => _pickVoice(),
              'rename' => _rename(),
              _ => _delete(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'stt',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.hearing_outlined),
                  title: const Text('Transcrição'),
                  subtitle: Text(_stt.label),
                ),
              ),
              PopupMenuItem(
                value: 'voice',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.record_voice_over_outlined),
                  title: const Text('Voz do assistente'),
                  subtitle: Text(KokoroVoice.byId(_voice).name),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'rename', child: Text('Renomear')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Apagar conversa'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessages()),
            _buildQuickActions(),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryOrange),
      );
    }
    if (_error != null) {
      return _placeholder(
        Icons.cloud_off_outlined,
        'Não foi possível carregar',
        _error!,
      );
    }
    if (_messages.isEmpty) {
      return _placeholder(
        Icons.smart_toy_outlined,
        'Pergunte qualquer coisa',
        'Quem responde é o modelo local no seu PC. Se ele estiver '
            'desligado, a pergunta espera aqui e é respondida quando ele '
            'ligar — a conversa fica salva.',
      );
    }

    // Oldest first with day markers, then reversed so the list sticks to
    // the newest message.
    final items = <Object>[];
    DateTime? day;
    for (final m in _messages) {
      final d = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (day != d) items.add(day = d);
      items.add(m);
    }
    // The newest question still waiting gets a "typing" bubble.
    final waiting = _messages.where((m) => m.isMine && m.isWaiting);
    if (waiting.isNotEmpty) {
      final last = waiting.last;
      items.add(
        last.isTranscribing && last.status == 'processing'
            ? 'transcribing'
            : last.status!,
      );
    }

    final reversed = items.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: reversed.length,
      itemBuilder: (context, i) {
        final item = reversed[i];
        if (item is DateTime) return _DayPill(date: item);
        if (item is String) return _Typing(status: item);
        final m = item as BotMessage;
        return _BotBubble(
          key: ValueKey(m.id),
          message: m,
          resolveUrl: _repo.audioUrl,
          onShowContext: () => _showContext(m),
          onRetry: () => _repo
              .retry(m.id)
              .catchError(
                (Object e) => _snack('Não foi possível tentar de novo: $e'),
              ),
          onCancel: () => _repo
              .cancel(m.id)
              .catchError(
                (Object e) => _snack('Não foi possível cancelar: $e'),
              ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        children: [
          for (final a in _quickActions)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: Icon(a.icon, size: 18, color: AppTheme.primaryOrange),
                label: Text(a.label),
                labelStyle: AppTheme.caption.copyWith(
                  color: AppTheme.darkBrown,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: AppTheme.white,
                side: const BorderSide(color: AppTheme.lightPeach),
                shape: const StadiumBorder(),
                onPressed: _sending ? null : () => _quick(a),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return BotComposer(
      busy: _sending,
      onSendText: (text) => _post(text),
      onSendVoice: _sendVoice,
    );
  }

  Widget _placeholder(IconData icon, String title, String body) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppTheme.primaryOrange.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTheme.sectionTitle),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks before deleting a bot chat; true to go ahead.
Future<bool> confirmDeleteBotChat(BuildContext context, String title) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.creamBackground,
      title: const Text('Apagar conversa?', style: AppTheme.sectionTitle),
      content: Text('"$title" e todas as mensagens dela serão apagadas.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Apagar', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Round robot badge, the bot's counterpart to ChatAvatar.
class BotAvatar extends StatelessWidget {
  final double size;

  const BotAvatar({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.smart_toy_outlined,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  final DateTime date;

  const _DayPill({required this.date});

  @override
  Widget build(BuildContext context) {
    final t = today();
    final label = date == t
        ? 'Hoje'
        : date == t.subtract(const Duration(days: 1))
        ? 'Ontem'
        : date.year == t.year
        ? formatDayMonth(date)
        : '${formatDayMonth(date)}/${date.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.lightPeach,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label, style: AppTheme.caption.copyWith(fontSize: 11)),
        ),
      ),
    );
  }
}

/// Left-side bubble while the PC works on the newest question.
class _Typing extends StatelessWidget {
  final String status;

  const _Typing({required this.status});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryOrange,
              ),
            ),
            const SizedBox(width: 10),
            Text(switch (status) {
              'transcribing' => 'Transcrevendo seu áudio...',
              'processing' => 'Pensando...',
              _ => 'Aguardando o PC responder...',
            }, style: AppTheme.caption.copyWith(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _BotBubble extends StatelessWidget {
  final BotMessage message;
  final VoidCallback onShowContext;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final Future<String> Function(String path) resolveUrl;

  const _BotBubble({
    super.key,
    required this.message,
    required this.resolveUrl,
    required this.onShowContext,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final textColor = mine ? Colors.white : AppTheme.darkBrown;
    final style = TextStyle(fontSize: 15, height: 1.35, color: textColor);

    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * (mine ? 0.75 : 0.85),
      ),
      decoration: BoxDecoration(
        gradient: mine ? AppTheme.primaryGradient : null,
        color: mine ? null : AppTheme.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.hasContext)
            GestureDetector(
              onTap: onShowContext,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.checklist_rounded,
                      size: 15,
                      color: textColor.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Afazeres anexados',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: textColor.withValues(alpha: 0.6),
                        color: textColor.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (message.hasAudio) ...[
            VoicePlayer(
              path: message.audioPath!,
              seconds: message.audioSeconds,
              mine: mine,
              resolveUrl: resolveUrl,
            ),
            const SizedBox(height: 4),
          ],
          if (mine && message.hasAudio)
            // The transcript under the audio, as soon as the PC has it.
            Text(
              message.isTranscribing
                  ? (message.status == 'error' ? '' : 'Transcrevendo...')
                  : message.content,
              style: style.copyWith(
                fontSize: 13,
                fontStyle: message.isTranscribing
                    ? FontStyle.italic
                    : FontStyle.normal,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            )
          else if (mine)
            Text(message.content, style: style)
          else
            MarkdownBody(
              data: message.content,
              selectable: true,
              softLineBreak: true,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                    p: style,
                    listBullet: style,
                    strong: style.copyWith(fontWeight: FontWeight.w700),
                    code: style.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      backgroundColor: AppTheme.creamBackground,
                    ),
                  ),
            ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!mine)
                InkResponse(
                  radius: 14,
                  onTap: () =>
                      Clipboard.setData(ClipboardData(text: message.content)),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: AppTheme.mediumBrown,
                    ),
                  ),
                ),
              Text(
                formatChatTime(message.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: mine
                      ? Colors.white.withValues(alpha: 0.85)
                      : AppTheme.mediumBrown,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          bubble,
          if (mine && message.status == 'error') _errorLine(),
          if (mine && message.isWaiting) _waitingLine(),
        ],
      ),
    );
  }

  Widget _errorLine() {
    final cancelled = message.errorMessage == 'Cancelado';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              cancelled
                  ? 'Cancelado'
                  : 'Sem resposta: ${message.errorMessage ?? 'erro'}',
              style: AppTheme.caption.copyWith(
                fontSize: 11,
                color: cancelled ? AppTheme.mediumBrown : Colors.red.shade700,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppTheme.primaryOrange,
            ),
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
    );
  }

  Widget _waitingLine() {
    return TextButton(
      onPressed: onCancel,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: AppTheme.mediumBrown,
      ),
      child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
    );
  }
}
