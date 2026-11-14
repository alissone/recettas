import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models/job_reply.dart';
import '../services/job_reply_repository.dart';
import '../utils/dates.dart';

/// "Responder recrutador": paste a job e-mail or LinkedIn message (and,
/// optionally, the job description), say what you want, and Claude writes
/// the reply. The request goes to the job_replies table and the
/// transcriber worker on the PC answers it, so the PC must be on.
class JobReplyScreen extends StatefulWidget {
  const JobReplyScreen({super.key});

  @override
  State<JobReplyScreen> createState() => _JobReplyScreenState();
}

class _JobReplyScreenState extends State<JobReplyScreen> {
  final _repo = JobReplyRepository.instance;

  final _messageCtrl = TextEditingController();
  final _jobCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  JobReplyChannel _channel = JobReplyChannel.linkedin;
  bool _sending = false;

  StreamSubscription<List<JobReply>>? _sub;
  List<JobReply> _items = [];
  Object? _streamError;
  bool _loading = true;

  /// Ids whose original message is expanded.
  final Set<String> _expanded = {};

  /// Quick instructions; tapping one appends it to the instructions field.
  static const _quickInstructions = [
    'Tenho interesse, quero marcar uma conversa',
    'Perguntar o valor/faixa salarial',
    'Recusar com educação',
    'Pedir mais detalhes sobre o cliente e o projeto',
    'Responder em português',
  ];

  @override
  void initState() {
    super.initState();
    _sub = _repo.watch().listen(
      (items) {
        if (!mounted) return;
        setState(() {
          _items = items;
          _streamError = null;
          _loading = false;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _streamError = e;
          _loading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _messageCtrl.dispose();
    _jobCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action, String errorPrefix) async {
    try {
      await action();
    } catch (e) {
      if (mounted) _toast('$errorPrefix: $e');
    }
  }

  // --- Actions ---

  Future<void> _paste(TextEditingController ctrl) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _toast('Nada copiado');
      return;
    }
    setState(() => ctrl.text = text);
  }

  void _addInstruction(String text) {
    final current = _instructionsCtrl.text.trim();
    if (current.contains(text)) return;
    setState(() => _instructionsCtrl.text =
        current.isEmpty ? text : '$current. $text');
  }

  Future<void> _submit() async {
    if (_messageCtrl.text.trim().isEmpty) {
      _toast('Cole a mensagem do recrutador');
      return;
    }
    setState(() => _sending = true);
    try {
      await _repo.request(
        channel: _channel,
        message: _messageCtrl.text,
        jobDescription: _jobCtrl.text,
        instructions: _instructionsCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _messageCtrl.clear();
        _jobCtrl.clear();
        _instructionsCtrl.clear();
      });
      FocusScope.of(context).unfocus();
      _toast('Pedido enviado ao Claude');
    } catch (e) {
      if (mounted) _toast('Erro ao enviar: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _toast('Copiado');
  }

  Future<void> _redo(JobReply item) async {
    final ctrl = TextEditingController(text: item.instructions ?? '');
    final instructions = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refazer resposta'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'O que mudar? (opcional)',
            hintText: 'Ex.: mais curta, mais formal, perguntar o valor',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Refazer')),
        ],
      ),
    );
    ctrl.dispose();
    if (instructions == null) return;
    await _run(() => _repo.redo(item.id, instructions: instructions),
        'Erro ao pedir');
  }

  Future<void> _delete(JobReply item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir esta resposta?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (ok == true) await _run(() => _repo.delete(item.id), 'Erro ao excluir');
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(title: const Text('Responder recrutador')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _buildForm(),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 20, 4, 8),
                child: Text('Respostas', style: AppTheme.sectionTitle),
              ),
              ..._buildHistory(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: child,
    );
  }

  Widget _pasteField({
    required TextEditingController ctrl,
    required String label,
    String? hint,
    int minLines = 3,
  }) {
    return TextField(
      controller: ctrl,
      minLines: minLines,
      maxLines: 12,
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: 'Colar',
          icon: const Icon(Icons.content_paste),
          onPressed: () => _paste(ctrl),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nova mensagem', style: AppTheme.sectionTitle),
          const SizedBox(height: 4),
          const Text(
              'O Claude responde pelo transcriber no PC, que precisa estar ligado.',
              style: AppTheme.caption),
          const SizedBox(height: 12),
          SegmentedButton<JobReplyChannel>(
            segments: const [
              ButtonSegment(
                  value: JobReplyChannel.linkedin,
                  icon: Icon(Icons.work_outline),
                  label: Text('LinkedIn')),
              ButtonSegment(
                  value: JobReplyChannel.email,
                  icon: Icon(Icons.mail_outline),
                  label: Text('E-mail')),
            ],
            selected: {_channel},
            onSelectionChanged: (s) => setState(() => _channel = s.first),
          ),
          const SizedBox(height: 12),
          _pasteField(
            ctrl: _messageCtrl,
            label: 'Mensagem do recrutador',
            minLines: 4,
          ),
          const SizedBox(height: 12),
          _pasteField(
            ctrl: _jobCtrl,
            label: 'Descrição da vaga (opcional)',
            hint: 'Cole aqui se a mensagem só tiver o link',
            minLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _instructionsCtrl,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'O que você quer responder? (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final q in _quickInstructions)
                ActionChip(
                  label: Text(q, style: AppTheme.caption),
                  onPressed: () => _addInstruction(q),
                ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Pedir resposta ao Claude'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHistory() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
        ),
      ];
    }
    if (_streamError != null && _items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Não foi possível carregar.\n$_streamError',
              textAlign: TextAlign.center, style: AppTheme.caption),
        ),
      ];
    }
    if (_items.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Text(
              'Nenhuma resposta ainda. Cole uma mensagem acima para começar.',
              textAlign: TextAlign.center,
              style: AppTheme.caption),
        ),
      ];
    }
    return [for (final item in _items) _buildItem(item)];
  }

  Widget _buildItem(JobReply item) {
    final expanded = _expanded.contains(item.id);
    final statusText = switch (item.status) {
      JobReplyStatus.requested => 'Aguardando o PC...',
      JobReplyStatus.processing => 'Escrevendo com Claude...',
      JobReplyStatus.error => 'Erro: ${item.errorMessage ?? 'desconhecido'}',
      JobReplyStatus.done => null,
    };

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  item.channel == JobReplyChannel.email
                      ? Icons.mail_outline
                      : Icons.work_outline,
                  size: 18,
                  color: AppTheme.primaryOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    '${item.channel.label} · ${_formatWhen(item.createdAt)}',
                    style: AppTheme.caption),
              ),
              if (item.isBusy) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primaryOrange),
                ),
                IconButton(
                  tooltip: 'Cancelar',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close, size: 20, color: Colors.red.shade300),
                  onPressed: () =>
                      _run(() => _repo.cancel(item.id), 'Erro ao cancelar'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => expanded
                ? _expanded.remove(item.id)
                : _expanded.add(item.id)),
            child: Text(
              item.message,
              maxLines: expanded ? null : 2,
              overflow: expanded ? null : TextOverflow.ellipsis,
              style: AppTheme.caption.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
          if (item.instructions != null) ...[
            const SizedBox(height: 4),
            Text('Pedido: ${item.instructions}', style: AppTheme.caption),
          ],
          if (statusText != null) ...[
            const SizedBox(height: 8),
            Text(statusText,
                style: AppTheme.caption.copyWith(
                    color: item.status == JobReplyStatus.error
                        ? Colors.red.shade400
                        : AppTheme.mediumBrown)),
          ],
          if (item.status == JobReplyStatus.done) ..._buildResult(item),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (item.status == JobReplyStatus.done && item.reply != null)
                FilledButton.icon(
                  onPressed: () => _copy(item.reply!),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copiar resposta'),
                ),
              if (!item.isBusy)
                OutlinedButton.icon(
                  onPressed: () => _redo(item),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(item.status == JobReplyStatus.error
                      ? 'Tentar de novo'
                      : 'Refazer'),
                ),
              OutlinedButton.icon(
                onPressed: () => _delete(item),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Excluir'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildResult(JobReply item) {
    return [
      if (item.subject != null) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SelectableText('Assunto: ${item.subject}',
                  style: AppTheme.valueBold),
            ),
            IconButton(
              tooltip: 'Copiar assunto',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => _copy(item.subject!),
            ),
          ],
        ),
      ],
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.creamBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusXSmall),
        ),
        child: SelectableText(item.reply ?? '', style: AppTheme.bodyText),
      ),
      if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.lightPeach,
            borderRadius: BorderRadius.circular(AppTheme.radiusXSmall),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notas para você (não enviar)',
                  style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mediumBrown)),
              const SizedBox(height: 4),
              SelectableText(item.notes!, style: AppTheme.caption),
            ],
          ),
        ),
      ],
    ];
  }
}

/// "14:05" for today, "05/03 14:05" otherwise.
String _formatWhen(DateTime t) {
  final time =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final days = today().difference(DateTime(t.year, t.month, t.day)).inDays;
  return days <= 0 ? time : '${formatDayMonth(t)} $time';
}
