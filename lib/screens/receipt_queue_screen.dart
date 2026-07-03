import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/receipt_job.dart';
import '../services/receipt_processor.dart';
import '../services/supabase_service.dart';

/// Queue of receipt photos waiting for the local llama-server, with
/// manual processing — the server isn't always on, so each run is
/// triggered by hand and the row shows live progress.
class ReceiptQueueScreen extends StatefulWidget {
  const ReceiptQueueScreen({super.key});

  @override
  State<ReceiptQueueScreen> createState() => _ReceiptQueueScreenState();
}

class _ReceiptQueueScreenState extends State<ReceiptQueueScreen> {
  List<ReceiptJob> _jobs = [];
  bool _isLoading = true;

  String _serverUrl = ReceiptProcessor.defaultServerUrl;
  bool? _serverOnline; // null = checking
  String? _processingJobId;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _initServer();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final jobs = await SupabaseService.getReceiptJobs();
      if (mounted) {
        setState(() {
          _jobs = jobs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initServer() async {
    final url = await ReceiptProcessor.getServerUrl();
    if (mounted) setState(() => _serverUrl = url);
    _pingServer();
  }

  Future<void> _pingServer() async {
    setState(() => _serverOnline = null);
    final online = await ReceiptProcessor.isServerAvailable(_serverUrl);
    if (mounted) setState(() => _serverOnline = online);
  }

  Future<void> _editServerUrl() async {
    final newUrl = await showDialog<String>(
      context: context,
      builder: (_) => _ServerUrlDialog(initialUrl: _serverUrl),
    );
    if (newUrl != null && newUrl.isNotEmpty) {
      await ReceiptProcessor.setServerUrl(newUrl);
      final url = await ReceiptProcessor.getServerUrl();
      if (mounted) setState(() => _serverUrl = url);
      _pingServer();
    }
  }

  Future<void> _processJob(ReceiptJob job) async {
    setState(() {
      _processingJobId = job.id;
      _elapsedSeconds = 0;
    });
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    try {
      final count = await ReceiptProcessor.processJob(job);
      _snack('$count itens adicionados às compras', success: true);
    } on ServerUnavailableException catch (e) {
      _snack('$e — ligue o servidor e tente de novo');
    } catch (e) {
      _snack('Erro ao processar: $e');
    } finally {
      _elapsedTimer?.cancel();
      if (mounted) setState(() => _processingJobId = null);
      _load();
      _pingServer();
    }
  }

  Future<void> _deleteJob(ReceiptJob job) async {
    try {
      await SupabaseService.deleteReceiptJob(job);
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
        title: const Text('Fila de Cupons'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _load();
              _pingServer();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildServerCard(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryOrange))
                : _jobs.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppTheme.primaryOrange,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(20, 4, 20, 20),
                          itemCount: _jobs.length,
                          itemBuilder: (_, i) => _buildJobCard(_jobs[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerCard() {
    final (color, label) = switch (_serverOnline) {
      null => (AppTheme.mediumBrown, 'verificando...'),
      true => (Colors.green.shade600, 'online'),
      false => (Colors.red.shade400, 'offline'),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_serverUrl,
                    style: AppTheme.caption.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('Servidor $label',
                    style: AppTheme.caption.copyWith(
                        fontWeight: FontWeight.w400, color: color)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar endereço',
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: AppTheme.mediumBrown),
            onPressed: _editServerUrl,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64,
              color: AppTheme.primaryOrange.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('Fila vazia', style: AppTheme.sectionTitle),
          const SizedBox(height: 8),
          const Text('Fotografe um cupom na aba Compras',
              style: AppTheme.caption),
        ],
      ),
    );
  }

  Widget _buildJobCard(ReceiptJob job) {
    final isRunning = _processingJobId == job.id;
    final anyRunning = _processingJobId != null;

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
          _statusIcon(job, isRunning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cupom ${_formatDate(job.createdAt)}',
                  style: AppTheme.valueBold.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusLine(job, isRunning),
                  style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.w400,
                    color: job.status == ReceiptJobStatus.error &&
                            !isRunning
                        ? Colors.red.shade400
                        : AppTheme.mediumBrown,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isRunning)
            Text('${_elapsedSeconds}s',
                style: AppTheme.caption
                    .copyWith(color: AppTheme.primaryOrange))
          else ...[
            if (job.status != ReceiptJobStatus.done)
              IconButton(
                tooltip: 'Processar',
                icon: const Icon(Icons.play_circle_outline,
                    color: AppTheme.primaryOrange, size: 26),
                onPressed: anyRunning ? null : () => _processJob(job),
              ),
            IconButton(
              tooltip: 'Excluir',
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.shade300, size: 22),
              onPressed: anyRunning ? null : () => _deleteJob(job),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusIcon(ReceiptJob job, bool isRunning) {
    if (isRunning) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
            strokeWidth: 2.5, color: AppTheme.primaryOrange),
      );
    }
    final (icon, color) = switch (job.status) {
      ReceiptJobStatus.queued => (
          Icons.schedule,
          AppTheme.mediumBrown.withValues(alpha: 0.6)
        ),
      ReceiptJobStatus.processing => (
          Icons.hourglass_top,
          AppTheme.primaryOrange
        ),
      ReceiptJobStatus.done => (Icons.check_circle, Colors.green.shade600),
      ReceiptJobStatus.error => (Icons.error, Colors.red.shade400),
    };
    return Icon(icon, color: color, size: 24);
  }

  String _statusLine(ReceiptJob job, bool isRunning) {
    if (isRunning) return 'Processando no servidor...';
    switch (job.status) {
      case ReceiptJobStatus.queued:
        return 'Na fila, aguardando processamento';
      case ReceiptJobStatus.processing:
        // A previous run was interrupted before finishing.
        return 'Interrompido — toque em processar para tentar de novo';
      case ReceiptJobStatus.done:
        final n = job.itemsCount ?? 0;
        return 'Concluído • $n ${n == 1 ? 'item' : 'itens'}';
      case ReceiptJobStatus.error:
        return 'Erro: ${job.errorMessage ?? 'desconhecido'}';
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

/// Owns the URL controller so it is only disposed once the dialog's
/// route (including the close animation) is fully gone; pops the
/// trimmed URL on save.
class _ServerUrlDialog extends StatefulWidget {
  final String initialUrl;

  const _ServerUrlDialog({required this.initialUrl});

  @override
  State<_ServerUrlDialog> createState() => _ServerUrlDialogState();
}

class _ServerUrlDialogState extends State<_ServerUrlDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.creamBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: const Text('Servidor LLM', style: AppTheme.sectionTitle),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          hintText: 'http://100.68.235.8:8001',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar',
              style: TextStyle(color: AppTheme.mediumBrown)),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.pop(context, _controller.text.trim()),
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
