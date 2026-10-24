import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app_theme.dart';
import '../models/voice_note.dart';
import '../services/supabase_service.dart';
import '../services/todo_repository.dart';
import '../services/voice_note_repository.dart';
import '../utils/brl.dart';
import '../utils/dates.dart';

/// Voice notes queue: recordings still on the phone, notes waiting for
/// the WhisperX worker, and finished transcripts that can be copied,
/// shared, turned into todos, or handed to Claude (summary -> todos,
/// shopping list -> Compras, spoken purchases -> Gastos).
class VoiceNotesScreen extends StatefulWidget {
  const VoiceNotesScreen({super.key});

  @override
  State<VoiceNotesScreen> createState() => _VoiceNotesScreenState();
}

class _VoiceNotesScreenState extends State<VoiceNotesScreen> {
  static const _pollInterval = Duration(seconds: 5);

  final _repo = VoiceNoteRepository.instance;

  List<PendingVoiceUpload> _uploads = [];
  List<VoiceNote> _notes = [];
  bool _isLoading = true;
  String? _loadError;
  final Set<String> _expanded = {};
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _repo.pendingCount.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _repo.pendingCount.removeListener(_load);
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final uploads = await _repo.getPendingUploads();
    List<VoiceNote>? notes;
    String? error;
    try {
      notes = await _repo.getNotes();
    } catch (e) {
      error = 'Sem conexão - mostrando só as gravações locais';
    }
    if (!mounted) return;
    setState(() {
      _uploads = uploads;
      if (notes != null) _notes = notes;
      _loadError = error;
      _isLoading = false;
    });
    _schedulePoll();
  }

  /// Keep refreshing while the worker still has something to do, so the
  /// transcript/summary shows up without pulling to refresh.
  void _schedulePoll() {
    _pollTimer?.cancel();
    final busy = _uploads.isNotEmpty ||
        _notes.any((n) =>
            n.status == VoiceNoteStatus.queued ||
            n.status == VoiceNoteStatus.processing ||
            VoiceTask.values.any((t) =>
                n.statusOf(t) == VoiceTaskStatus.requested ||
                n.statusOf(t) == VoiceTaskStatus.processing));
    if (busy) _pollTimer = Timer(_pollInterval, _load);
  }

  Future<void> _run(Future<void> Function() action, String errorPrefix) async {
    try {
      await action();
    } catch (e) {
      _snack('$errorPrefix: $e');
    }
    _load();
  }

  void _snack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? Colors.green.shade600 : AppTheme.darkBrown,
    ));
  }

  // --- Actions ---

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _snack('Texto copiado', success: true);
  }

  void _share(String text) {
    SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _addAsTodo(String text) async {
    await TodoRepository.instance.addTodo(text);
    _snack('Afazer criado', success: true);
  }

  Future<void> _addSummaryItems(VoiceNote note) async {
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (_) => _PickItemsDialog(
          title: 'Adicionar aos afazeres', items: note.summaryItems),
    );
    if (selected == null || selected.isEmpty) return;
    for (final item in selected) {
      await TodoRepository.instance.addTodo(item);
    }
    _snack(
        '${selected.length} ${selected.length == 1 ? 'afazer criado' : 'afazeres criados'}',
        success: true);
  }

  Future<void> _addShoppingItems(VoiceNote note) async {
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (_) => _PickItemsDialog(
          title: 'Adicionar às compras', items: note.shoppingItems),
    );
    if (selected == null || selected.isEmpty) return;
    try {
      // Same rule as the worker's Gastos: a list shared with the user wins
      // over their own, since that's the one they keep.
      final owners = await SupabaseService.getListOwners();
      final target = owners.firstWhere((o) => !o.isMine,
          orElse: () => owners.first);
      for (final item in selected) {
        await SupabaseService.addShoppingItem(item, ownerId: target.id);
      }
      _snack(
          '${selected.length} ${selected.length == 1 ? 'item adicionado' : 'itens adicionados'}'
          ' às compras${target.isMine ? '' : ' (${target.name})'}',
          success: true);
    } catch (e) {
      _snack('Erro ao adicionar às compras: $e');
    }
  }

  Future<void> _confirmDelete(VoiceNote note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        title: const Text('Excluir nota?', style: AppTheme.sectionTitle),
        content: const Text('A transcrição e os resultados do Claude serão '
            'apagados. Gastos e itens já adicionados continuam nas listas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: TextStyle(color: AppTheme.mediumBrown)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Excluir',
                style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
    if (ok == true) {
      _run(() => _repo.deleteNote(note), 'Erro ao excluir');
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final empty = _uploads.isEmpty && _notes.isEmpty;
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title: const Text('Notas de voz'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _repo.uploadPending();
              _load();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange))
          : RefreshIndicator(
              color: AppTheme.primaryOrange,
              onRefresh: () async {
                _repo.uploadPending();
                await _load();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  if (_loadError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_loadError!,
                          style: AppTheme.caption
                              .copyWith(color: Colors.red.shade400)),
                    ),
                  if (empty) _buildEmptyState(),
                  for (final u in _uploads) _buildUploadCard(u),
                  for (final n in _notes) _buildNoteCard(n),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        children: [
          Icon(Icons.mic_none,
              size: 64, color: AppTheme.primaryOrange.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('Nenhuma nota de voz', style: AppTheme.sectionTitle),
          const SizedBox(height: 8),
          const Text('Grave uma pelo botão de microfone em Afazeres',
              style: AppTheme.caption),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: child,
    );
  }

  Widget _header({
    required Widget icon,
    required DateTime recordedAt,
    required int? durationSeconds,
    required String status,
    Color? statusColor,
    required List<Widget> trailing,
  }) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nota ${_formatDate(recordedAt)}'
                '${durationSeconds != null ? ' • ${_formatDuration(durationSeconds)}' : ''}',
                style: AppTheme.valueBold.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(status,
                  style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w400,
                      color: statusColor ?? AppTheme.mediumBrown),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        ...trailing,
      ],
    );
  }

  Widget _buildUploadCard(PendingVoiceUpload upload) {
    return _card(
      child: _header(
        icon: Icon(Icons.cloud_upload_outlined,
            color: AppTheme.mediumBrown.withValues(alpha: 0.6), size: 24),
        recordedAt: upload.recordedAt,
        durationSeconds: upload.durationSeconds,
        status: 'No celular, aguardando conexão para enviar',
        trailing: [
          IconButton(
            tooltip: 'Descartar',
            icon: Icon(Icons.delete_outline,
                color: Colors.red.shade300, size: 22),
            onPressed: () => _run(() => _repo.discardPendingUpload(upload),
                'Erro ao descartar'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(VoiceNote note) {
    final done = note.status == VoiceNoteStatus.done;
    final transcript = note.transcript ?? '';
    final (icon, color, status) = switch (note.status) {
      VoiceNoteStatus.queued => (
          Icons.schedule,
          AppTheme.mediumBrown.withValues(alpha: 0.6),
          'Na fila, aguardando o transcritor no PC'
        ),
      VoiceNoteStatus.processing => (
          Icons.hourglass_top,
          AppTheme.primaryOrange,
          'Transcrevendo...'
        ),
      VoiceNoteStatus.done => (
          Icons.check_circle,
          Colors.green.shade600,
          transcript.isEmpty ? 'Nenhuma fala detectada' : 'Transcrita'
        ),
      VoiceNoteStatus.error => (
          Icons.error,
          Colors.red.shade400,
          'Erro: ${note.errorMessage ?? 'desconhecido'}'
        ),
    };

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(
            icon: Icon(icon, color: color, size: 24),
            recordedAt: note.recordedAt,
            durationSeconds: note.durationSeconds,
            status: status,
            statusColor:
                note.status == VoiceNoteStatus.error ? Colors.red.shade400 : null,
            trailing: [
              if (note.status == VoiceNoteStatus.error && note.audioPath != null)
                IconButton(
                  tooltip: 'Tentar de novo',
                  icon: const Icon(Icons.replay,
                      color: AppTheme.primaryOrange, size: 24),
                  onPressed: () => _run(
                      () => _repo.retryTranscription(note.id),
                      'Erro ao reenviar'),
                ),
              IconButton(
                tooltip: 'Excluir',
                icon: Icon(Icons.delete_outline,
                    color: Colors.red.shade300, size: 22),
                onPressed: () => _confirmDelete(note),
              ),
            ],
          ),
          if (done && transcript.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _expanded.contains(note.id)
                  ? _expanded.remove(note.id)
                  : _expanded.add(note.id)),
              child: Text(
                transcript,
                style: AppTheme.bodyText,
                maxLines: _expanded.contains(note.id) ? null : 4,
                overflow: _expanded.contains(note.id)
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
            _actionGroup([
              _actionTile(Icons.copy, 'Copiar texto',
                  onTap: () => _copy(transcript)),
              _actionTile(Icons.share_outlined, 'Compartilhar',
                  onTap: () => _share(transcript)),
              _actionTile(Icons.add_task, 'Criar afazer com o texto',
                  onTap: () => _addAsTodo(transcript)),
            ]),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text('Com Claude',
                  style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mediumBrown)),
            ),
            _actionGroup([
              for (final task in VoiceTask.values) _taskTile(note, task),
            ]),
          ],
        ],
      ),
    );
  }

  // --- Claude tasks ---

  static const _taskInfo = {
    VoiceTask.summary: (Icons.checklist, 'Resumir em afazeres',
        'Tópicos que viram itens em Afazeres'),
    VoiceTask.shopping: (Icons.shopping_cart_outlined, 'Lista de compras',
        'O que comprar, para adicionar em Compras'),
    VoiceTask.expenses: (Icons.receipt_long_outlined, 'Lançar em Gastos',
        'Compras ditas com valor são lançadas direto'),
  };

  /// One task row plus, when done, its result right below it.
  Widget _taskTile(VoiceNote note, VoiceTask task) {
    final (icon, title, hint) = _taskInfo[task]!;
    final status = note.statusOf(task);
    final busy = status == VoiceTaskStatus.requested ||
        status == VoiceTaskStatus.processing;
    final subtitle = switch (status) {
      null => hint,
      VoiceTaskStatus.requested => 'Pedido, aguardando o PC...',
      VoiceTaskStatus.processing => 'Processando com Claude...',
      VoiceTaskStatus.error => 'Erro: ${note.errorMessage ?? 'desconhecido'}'
          ' - toque para tentar de novo',
      VoiceTaskStatus.done => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _actionTile(
          icon,
          title,
          subtitle: subtitle,
          subtitleColor:
              status == VoiceTaskStatus.error ? Colors.red.shade400 : null,
          // Done: the row itself does nothing and "Refazer" is the trailing
          // button, so a stray tap can't redo (for Gastos, replace) it.
          onTap: busy || status == VoiceTaskStatus.done
              ? null
              : () => _requestTask(note, task),
          trailing: busy
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primaryOrange),
                    ),
                    IconButton(
                      tooltip: 'Cancelar',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close,
                          size: 20, color: Colors.red.shade300),
                      onPressed: () => _run(
                          () => _repo.cancelTask(note.id, task),
                          'Erro ao cancelar'),
                    ),
                  ],
                )
              : status == VoiceTaskStatus.done
                  ? IconButton(
                      tooltip: 'Refazer',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.refresh,
                          size: 20, color: AppTheme.primaryOrange),
                      onPressed: () => _redoTask(note, task),
                    )
                  : null,
        ),
        if (status == VoiceTaskStatus.done)
          switch (task) {
            VoiceTask.summary => _bulletResult(
                items: note.summaryItems,
                rawText: note.summary,
                addLabel: 'Adicionar aos afazeres',
                onAdd: () => _addSummaryItems(note),
              ),
            VoiceTask.shopping => _bulletResult(
                items: note.shoppingItems,
                rawText: note.shopping,
                addLabel: 'Adicionar às compras',
                onAdd: () => _addShoppingItems(note),
              ),
            VoiceTask.expenses => _expensesResult(note),
          },
      ],
    );
  }

  void _requestTask(VoiceNote note, VoiceTask task) {
    _run(() => _repo.requestTask(note.id, task), 'Erro ao pedir');
  }

  Future<void> _redoTask(VoiceNote note, VoiceTask task) async {
    if (task == VoiceTask.expenses && note.expenses.isNotEmpty) {
      final n = note.expenses.length;
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.creamBackground,
          title: const Text('Refazer gastos?', style: AppTheme.sectionTitle),
          content: Text(n == 1
              ? 'O gasto lançado por esta nota será substituído, inclusive '
                  'se você o editou em Gastos.'
              : 'Os $n gastos lançados por esta nota serão substituídos, '
                  'inclusive os que você editou em Gastos.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar',
                  style: TextStyle(color: AppTheme.mediumBrown)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Refazer',
                  style: TextStyle(color: AppTheme.primaryOrange)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    _requestTask(note, task);
  }

  Widget _resultBox(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.lightPeach.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _bulletResult({
    required List<String> items,
    required String? rawText,
    required String addLabel,
    required VoidCallback onAdd,
  }) {
    return _resultBox([
      if (items.isEmpty)
        Text(rawText ?? '', style: AppTheme.bodyText)
      else
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('•  $item', style: AppTheme.bodyText),
          ),
      Wrap(
        spacing: 4,
        children: [
          if (items.isNotEmpty) _action(Icons.playlist_add, addLabel, onAdd),
          _action(Icons.copy, 'Copiar', () => _copy(rawText ?? '')),
        ],
      ),
    ]);
  }

  Widget _expensesResult(VoiceNote note) {
    final expenses = note.expenses;
    if (expenses.isEmpty) {
      return _resultBox([
        const Text('Nenhuma compra com valor encontrada na nota.',
            style: AppTheme.bodyText),
      ]);
    }
    final total = expenses.fold<double>(0, (sum, e) => sum + e.valor);
    final recordedDay = isoDate(note.recordedAt.toLocal());
    return _resultBox([
      for (final e in expenses)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.item, style: AppTheme.bodyText),
                    if (_expenseDetails(e, recordedDay).isNotEmpty)
                      Text(_expenseDetails(e, recordedDay),
                          style: AppTheme.caption),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(formatBrl(e.valor),
                  style: AppTheme.valueBold.copyWith(fontSize: 14)),
            ],
          ),
        ),
      Text(
        '${expenses.length} ${expenses.length == 1 ? 'gasto lançado' : 'gastos lançados'}'
        ' em Gastos • total ${formatBrl(total)}',
        style: AppTheme.caption.copyWith(color: Colors.green.shade700),
      ),
    ]);
  }

  /// "Mello • 22/10 • Comida"; the date only when it isn't the note's day.
  String _expenseDetails(VoiceExpense e, String recordedDay) {
    final date = DateTime.tryParse(e.data);
    return [
      if (e.local != null) e.local!,
      if (date != null && e.data != recordedDay) formatDayMonth(date),
      if (e.categoria != null) e.categoria!,
    ].join(' • ');
  }

  // --- Action list ---

  /// Rows stacked in one rounded box with hairline dividers.
  Widget _actionGroup(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.lightPeach),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppTheme.lightPeach),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _actionTile(
    IconData icon,
    String title, {
    String? subtitle,
    Color? subtitleColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.primaryOrange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTheme.bodyText
                          .copyWith(fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: AppTheme.caption.copyWith(
                            color: subtitleColor ?? AppTheme.mediumBrown),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.primaryOrange,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m${s.toString().padLeft(2, '0')}s' : '${s}s';
  }
}

/// Checkbox list of items, all selected by default; pops the chosen ones.
class _PickItemsDialog extends StatefulWidget {
  final String title;
  final List<String> items;

  const _PickItemsDialog({required this.title, required this.items});

  @override
  State<_PickItemsDialog> createState() => _PickItemsDialogState();
}

class _PickItemsDialogState extends State<_PickItemsDialog> {
  late final List<bool> _checked =
      List.filled(widget.items.length, true);

  @override
  Widget build(BuildContext context) {
    final count = _checked.where((c) => c).length;
    return AlertDialog(
      backgroundColor: AppTheme.creamBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: Text(widget.title, style: AppTheme.sectionTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.items.length,
          itemBuilder: (_, i) => CheckboxListTile(
            value: _checked[i],
            activeColor: AppTheme.primaryOrange,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(widget.items[i], style: AppTheme.bodyText),
            onChanged: (v) => setState(() => _checked[i] = v ?? false),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text('Cancelar', style: TextStyle(color: AppTheme.mediumBrown)),
        ),
        ElevatedButton(
          onPressed: count == 0
              ? null
              : () => Navigator.pop(context, [
                    for (var i = 0; i < widget.items.length; i++)
                      if (_checked[i]) widget.items[i]
                  ]),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryOrange,
            foregroundColor: Colors.white,
          ),
          child: Text('Adicionar ($count)'),
        ),
      ],
    );
  }
}
