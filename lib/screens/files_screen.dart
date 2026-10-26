import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/cloud_file.dart';
import '../services/cloud_file_repository.dart';
import '../utils/dates.dart';
import '../utils/file_types.dart';

/// "Arquivos": a mini drive for moving small files between devices.
/// Upload here, download on another device later. Files are grouped by
/// upload time the way Finder does. Shared by the app and the web build,
/// so it must not import dart:io.
///
/// With [sendToRoomId] it becomes a picker: rows get checkboxes and a
/// button sends the ticked files into that chat as attachments.
class FilesScreen extends StatefulWidget {
  final String? sendToRoomId;
  final String? sendToLabel;

  const FilesScreen({super.key, this.sendToRoomId, this.sendToLabel});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final _repo = CloudFileRepository.instance;

  List<CloudFile> _files = [];
  bool _isLoading = true;
  String? _loadError;
  bool _uploading = false;

  /// Ids with a download or delete in flight, shown as a spinner.
  final Set<String> _busy = {};

  /// The card currently expanded into its properties, if any.
  String? _selectedId;

  /// Picker mode: ids ticked to be sent to the chat.
  final Set<String> _picked = {};
  bool _sendingPicked = false;

  bool get _picking => widget.sendToRoomId != null;

  @override
  void initState() {
    super.initState();
    _repo.uploads.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    // Files shared in from other apps (Android share sheet, iOS document
    // handler) upload through the repository, which bumps `uploads`.
    _repo.uploads.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final files = await _repo.getFiles();
      if (!mounted) return;
      setState(() {
        _files = files;
        _loadError = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _isLoading = false;
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // --- Actions ---

  Future<void> _upload() async {
    final picked = await FilePicker.pickFile();
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final file = await _repo.upload(
        name: picked.name,
        bytes: bytes,
        mimeType: mimeTypeForName(picked.name),
      );
      if (!mounted) return;
      _toast('"${file.name}" enviado');
    } catch (e) {
      if (mounted) _toast('Erro ao enviar: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _download(CloudFile file) async {
    setState(() => _busy.add(file.id));
    try {
      final bytes = await _repo.download(file);
      final saved = await FilePicker.saveFile(
        fileName: file.name,
        bytes: bytes,
        mimeType: file.mimeType ?? 'application/octet-stream',
        dialogTitle: 'Salvar arquivo',
      );
      if (saved == null) return; // dialog cancelled
      await _repo.logDownload(file);
      if (mounted) _toast('"${file.name}" baixado');
    } catch (e) {
      if (mounted) _toast('Erro ao baixar: $e');
    } finally {
      if (mounted) setState(() => _busy.remove(file.id));
    }
  }

  Future<void> _rename(CloudFile file, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == file.name) return;
    try {
      await _repo.rename(file, trimmed);
      await _load();
    } catch (e) {
      if (mounted) _toast('Erro ao renomear: $e');
    }
  }

  Future<void> _delete(CloudFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir arquivo?'),
        content: Text('"${file.name}" será removido da nuvem.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy.add(file.id));
    try {
      await _repo.delete(file);
      if (mounted) {
        setState(() {
          _files.removeWhere((f) => f.id == file.id);
          if (_selectedId == file.id) _selectedId = null;
        });
      }
    } catch (e) {
      if (mounted) _toast('Erro ao excluir: $e');
    } finally {
      if (mounted) setState(() => _busy.remove(file.id));
    }
  }

  Future<void> _sendPicked() async {
    final roomId = widget.sendToRoomId!;
    final chosen = _files.where((f) => _picked.contains(f.id)).toList();
    if (chosen.isEmpty) return;
    setState(() => _sendingPicked = true);
    var sent = 0;
    try {
      // Oldest first, so the conversation reads in the list's order.
      for (final file in chosen.reversed) {
        await _repo.sendCloudFileToChat(roomId: roomId, file: file);
        sent++;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingPicked = false;
        // Keep only what failed to go, so a retry doesn't duplicate.
        for (final file in chosen.reversed.take(sent)) {
          _picked.remove(file.id);
        }
      });
      _toast('Erro ao enviar: $e');
      return;
    }
    if (mounted) Navigator.pop(context, sent);
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title: Text(_picking
            ? 'Enviar para ${widget.sendToLabel ?? 'a conversa'}'
            : 'Arquivos'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: _picking
          ? FloatingActionButton.extended(
              heroTag: 'files_send_fab',
              onPressed:
                  _picked.isEmpty || _sendingPicked ? null : _sendPicked,
              icon: _sendingPicked
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_picked.isEmpty
                  ? 'Selecione arquivos'
                  : 'Enviar (${_picked.length})'),
            )
          : FloatingActionButton.extended(
        heroTag: 'files_upload_fab',
        onPressed: _uploading ? null : _upload,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_file),
        label: Text(_uploading ? 'Enviando...' : 'Enviar'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryOrange),
      );
    }
    if (_loadError != null && _files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Não foi possível carregar os arquivos.\n$_loadError',
              textAlign: TextAlign.center, style: AppTheme.caption),
        ),
      );
    }
    if (_files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open,
                  size: 64,
                  color: AppTheme.primaryOrange.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text('Nenhum arquivo',
                  style: AppTheme.sectionTitle, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Envie um arquivo para baixá-lo em outro dispositivo',
                  style: AppTheme.caption, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final groups = CloudFileGroup.group(_files, DateTime.now());
    return RefreshIndicator(
      color: AppTheme.primaryOrange,
      onRefresh: _load,
      // Tapping outside the expanded card collapses it again.
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => setState(() => _selectedId = null),
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text(group.title, style: AppTheme.sectionTitle),
            ),
            for (final file in group.files) _buildRow(file),
          ],
        ],
        ),
      ),
    );
  }

  Widget _buildRow(CloudFile file) {
    final selected = !_picking && _selectedId == file.id;
    return _FileCard(
      key: ValueKey(file.id),
      file: file,
      picking: _picking,
      checked: _picked.contains(file.id),
      onToggleChecked: () => setState(() {
        if (!_picked.remove(file.id)) _picked.add(file.id);
      }),
      expanded: selected,
      busy: _busy.contains(file.id),
      onTap: () => setState(() => _selectedId = selected ? null : file.id),
      onDownload: () => _download(file),
      onRename: (name) => _rename(file, name),
      onDelete: () => _delete(file),
    );
  }
}

/// "14:05" for today and yesterday, "05/03" for older files (the group
/// header already says which period).
String _formatWhen(DateTime t) {
  final days = today().difference(DateTime(t.year, t.month, t.day)).inDays;
  if (days <= 1) return _formatTime(t);
  return '${formatDayMonth(t)} ${_formatTime(t)}';
}

String _formatTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _formatDateTime(DateTime t) =>
    '${formatDayMonth(t)}/${t.year} ${_formatTime(t)}';


/// A file row that expands in place into its properties (type, size,
/// upload/download history) with the download / rename / delete actions.
class _FileCard extends StatefulWidget {
  final CloudFile file;
  final bool picking;
  final bool checked;
  final VoidCallback onToggleChecked;
  final bool expanded;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final ValueChanged<String> onRename;
  final VoidCallback onDelete;

  const _FileCard({
    super.key,
    required this.file,
    required this.picking,
    required this.checked,
    required this.onToggleChecked,
    required this.expanded,
    required this.busy,
    required this.onTap,
    required this.onDownload,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<_FileCard> {
  Future<List<CloudFileEvent>>? _events;
  TextEditingController? _renameController;

  @override
  void initState() {
    super.initState();
    if (widget.expanded) _loadEvents();
  }

  @override
  void didUpdateWidget(_FileCard old) {
    super.didUpdateWidget(old);
    if (widget.expanded && !old.expanded) _loadEvents();
    if (!widget.expanded && old.expanded) _stopRenaming();
  }

  @override
  void dispose() {
    _renameController?.dispose();
    super.dispose();
  }

  void _loadEvents() {
    // Fresh on every expand: another device may have downloaded it since.
    _events = CloudFileRepository.instance.getEvents(widget.file);
  }

  void _startRenaming() {
    final name = widget.file.name;
    final dot = name.lastIndexOf('.');
    setState(() {
      _renameController = TextEditingController(text: name)
        ..selection = TextSelection(
            baseOffset: 0, extentOffset: dot > 0 ? dot : name.length);
    });
  }

  void _stopRenaming() {
    final controller = _renameController;
    if (controller == null) return;
    _renameController = null;
    // Disposed after the frame: the TextField is still listening now.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }

  void _submitRename() {
    final name = _renameController?.text ?? '';
    setState(_stopRenaming);
    widget.onRename(name);
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
        border: widget.expanded
            ? Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.5))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          // Also swallows taps inside the card so they don't reach the
          // list's "tap outside to collapse".
          onTap: widget.picking
              ? widget.onToggleChecked
              : widget.expanded
                  ? () {}
                  : widget.onTap,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(file),
                  if (widget.expanded) ..._buildDetails(file),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(CloudFile file) {
    final renaming = _renameController != null;
    return Row(
      children: [
        if (widget.picking)
          Checkbox(
            value: widget.checked,
            activeColor: AppTheme.primaryOrange,
            visualDensity: VisualDensity.compact,
            onChanged: (_) => widget.onToggleChecked(),
          )
        else
          Icon(iconForFileName(file.name), color: AppTheme.primaryOrange),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (renaming)
                TextField(
                  controller: _renameController,
                  autofocus: true,
                  decoration:
                      const InputDecoration(labelText: 'Nome', isDense: true),
                  onSubmitted: (_) => _submitRename(),
                )
              else
                Text(file.name,
                    maxLines: widget.expanded ? 3 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkBrown)),
              if (!renaming) ...[
                const SizedBox(height: 2),
                Text(
                  '${file.typeLabel} · ${CloudFile.formatSize(file.sizeBytes)} · '
                  '${_formatWhen(file.createdAt)}',
                  style: AppTheme.caption,
                ),
              ],
            ],
          ),
        ),
        if (widget.busy)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  List<Widget> _buildDetails(CloudFile file) {
    final renaming = _renameController != null;
    return [
      const SizedBox(height: 12),
      const Divider(height: 1),
      const SizedBox(height: 12),
      _infoRow('Tipo', file.mimeType ?? file.typeLabel),
      _infoRow('Tamanho', CloudFile.formatSize(file.sizeBytes)),
      _infoRow('Enviado em', _formatDateTime(file.createdAt)),
      const SizedBox(height: 12),
      const Text('Histórico', style: AppTheme.sectionTitle),
      const SizedBox(height: 8),
      FutureBuilder<List<CloudFileEvent>>(
        future: _events,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Erro: ${snapshot.error}', style: AppTheme.caption);
          }
          final events = snapshot.data;
          if (events == null) {
            return const Padding(
              padding: EdgeInsets.all(8),
              child:
                  Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (events.isEmpty) {
            return const Text('Sem registros', style: AppTheme.caption);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final e in events) _eventRow(e)],
          );
        },
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (renaming) ...[
            FilledButton(
              onPressed: _submitRename,
              child: const Text('Salvar'),
            ),
            TextButton(
              onPressed: () => setState(_stopRenaming),
              child: const Text('Cancelar'),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: widget.busy ? null : widget.onDownload,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Baixar'),
            ),
            OutlinedButton.icon(
              onPressed: widget.busy ? null : _startRenaming,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Renomear'),
            ),
            OutlinedButton.icon(
              onPressed: widget.busy ? null : widget.onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Excluir'),
            ),
          ],
        ],
      ),
    ];
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: AppTheme.caption)),
          Expanded(child: Text(value, style: AppTheme.bodyText)),
        ],
      ),
    );
  }

  Widget _eventRow(CloudFileEvent e) {
    final upload = e.kind == CloudFileEventKind.upload;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(upload ? Icons.upload : Icons.download,
              size: 18, color: AppTheme.primaryOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${upload ? 'Enviado' : 'Baixado'} por ${e.deviceName}',
                    style: AppTheme.bodyText),
                Text(_formatDateTime(e.at), style: AppTheme.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
