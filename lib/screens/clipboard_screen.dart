import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/cloud_file.dart';
import '../models/clipboard_item.dart';
import '../services/clipboard_repository.dart';
import '../utils/dates.dart';

/// "Área de transferência": a clipboard shared by all the user's devices.
/// The top card sends what this device has copied; below it the last few
/// items sent from any device show up live, each with a Copy button.
/// Shared by the app and the web build, so it must not import dart:io.
class ClipboardScreen extends StatefulWidget {
  const ClipboardScreen({super.key});

  @override
  State<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends State<ClipboardScreen>
    with WidgetsBindingObserver {
  final _repo = ClipboardRepository.instance;

  StreamSubscription<List<ClipboardItem>>? _sub;
  List<ClipboardItem> _items = [];
  Object? _streamError;
  bool _loading = true;

  /// What this device's clipboard holds right now (best effort: browsers
  /// only allow the read with focus and permission).
  String? _localText;
  Uint8List? _localImage;
  bool _sending = false;

  /// Ids with a copy or delete in flight.
  final Set<String> _busy = {};

  /// Image bytes by item id, so a rebuild doesn't download again.
  final Map<String, Future<Uint8List>> _imageCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribe();
    _readLocal();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Copying in another app and coming back is the usual flow.
    if (state == AppLifecycleState.resumed) _readLocal();
  }

  void _subscribe() {
    _sub?.cancel();
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

  Future<void> _readLocal() async {
    final text = await _repo.readText();
    final image = text == null ? await _repo.readImage() : null;
    if (!mounted) return;
    setState(() {
      _localText = text;
      _localImage = image;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // --- Actions ---

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      // Read on tap: browsers only allow it from a user gesture.
      await _readLocal();
      final text = _localText;
      final image = _localImage;
      if (text != null) {
        await _repo.sendText(text);
      } else if (image != null) {
        await _repo.sendImage(image);
      } else {
        if (mounted) {
          _toast('Nada copiado neste dispositivo '
              '(ou o navegador bloqueou a leitura)');
        }
        return;
      }
      if (mounted) _toast('Enviado');
    } catch (e) {
      if (mounted) _toast('Erro ao enviar: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _copy(ClipboardItem item) async {
    setState(() => _busy.add(item.id));
    try {
      if (item.isImage) {
        await _repo.writeImage(await _imageFor(item));
      } else {
        await _repo.writeText(item.content ?? '');
      }
      if (mounted) _toast('Copiado');
    } catch (e) {
      if (mounted) _toast('Erro ao copiar: $e');
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  Future<void> _delete(ClipboardItem item) async {
    setState(() => _busy.add(item.id));
    try {
      await _repo.delete(item);
    } catch (e) {
      if (mounted) _toast('Erro ao excluir: $e');
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  Future<Uint8List> _imageFor(ClipboardItem item) =>
      _imageCache.putIfAbsent(item.id, () => _repo.downloadImage(item));

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title: const Text('Área de transferência'),
        actions: [
          IconButton(
            tooltip: 'Reler a área de transferência',
            icon: const Icon(Icons.refresh),
            onPressed: _readLocal,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _buildLocalCard(),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 20, 4, 8),
                child: Text('Enviados', style: AppTheme.sectionTitle),
              ),
              ..._buildHistory(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child, bool highlight = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
        border: highlight
            ? Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.5))
            : null,
      ),
      child: child,
    );
  }

  Widget _buildLocalCard() {
    final Widget preview;
    if (_localText != null) {
      preview = Text(_localText!,
          maxLines: 4, overflow: TextOverflow.ellipsis, style: AppTheme.bodyText);
    } else if (_localImage != null) {
      preview = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 140),
        child: Image.memory(_localImage!, fit: BoxFit.contain),
      );
    } else {
      preview = const Text(
          'Nada lido. Copie algo e toque em Enviar (no navegador, '
          'permita o acesso à área de transferência).',
          style: AppTheme.caption);
    }
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Neste dispositivo', style: AppTheme.sectionTitle),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: preview),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send, size: 18),
            label: Text(kIsWeb ? 'Enviar para o celular' : 'Enviar para a web'),
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
            child: CircularProgressIndicator(color: AppTheme.primaryOrange),
          ),
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
          child: Text('Nada enviado ainda',
              textAlign: TextAlign.center, style: AppTheme.caption),
        ),
      ];
    }
    return [
      for (var i = 0; i < _items.length; i++) _buildItem(_items[i], i == 0),
    ];
  }

  Widget _buildItem(ClipboardItem item, bool latest) {
    final busy = _busy.contains(item.id);
    return _card(
      highlight: latest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.isImage ? Icons.image_outlined : Icons.notes,
                  size: 18, color: AppTheme.primaryOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${latest ? 'Mais recente · ' : ''}${_formatWhen(item.createdAt)}'
                  '${item.sizeBytes != null ? ' · ${CloudFile.formatSize(item.sizeBytes!)}' : ''}',
                  style: AppTheme.caption,
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (item.isImage)
            FutureBuilder<Uint8List>(
              future: _imageFor(item),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Erro: ${snapshot.error}',
                      style: AppTheme.caption);
                }
                final bytes = snapshot.data;
                if (bytes == null) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                );
              },
            )
          else
            SelectableText(item.content ?? '', style: AppTheme.bodyText),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : () => _copy(item),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copiar'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _delete(item),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Excluir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "14:05" for today, "05/03 14:05" otherwise.
String _formatWhen(DateTime t) {
  final time =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final days = today().difference(DateTime(t.year, t.month, t.day)).inDays;
  return days <= 0 ? time : '${formatDayMonth(t)} $time';
}
