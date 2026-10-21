import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../services/relay_controller.dart';

/// ON/OFF switches for the ESP8266 relay board at home, one per relay
/// the firmware reports. The board is the source of truth: every switch shows what the last response
/// reported, and the screen re-polls while open so physical changes
/// (reboot, another phone) show up.
class RelaysScreen extends StatefulWidget {
  const RelaysScreen({super.key});

  @override
  State<RelaysScreen> createState() => _RelaysScreenState();
}

class _RelaysScreenState extends State<RelaysScreen> {
  List<bool>? _states; // null = never reached the controller
  List<String> _names = [];
  String _url = RelayController.defaultUrl;
  bool? _online; // null = checking
  int? _uptime;
  String? _error;
  final Set<int> _pending = {};
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _init();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_pending.isEmpty) _refresh(quiet: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final url = await RelayController.getUrl();
    if (mounted) setState(() => _url = url);
    await _refresh();
  }

  Future<void> _refresh({bool quiet = false}) async {
    if (!quiet) setState(() => _online = null);
    try {
      final states = await RelayController.getStatus();
      final uptime = await RelayController.getUptime();
      final names = await RelayController.getNames(states.length);
      if (mounted) {
        setState(() {
          _states = states;
          _names = names;
          _uptime = uptime;
          _online = true;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _online = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _setRelay(int relay, bool state) async {
    setState(() => _pending.add(relay));
    try {
      final states = await RelayController.setRelay(relay, state);
      if (mounted) {
        setState(() {
          _states = states;
          _online = true;
          _error = null;
        });
      }
    } catch (e) {
      _snack('$e');
      if (mounted) setState(() => _online = false);
    } finally {
      if (mounted) setState(() => _pending.remove(relay));
    }
  }

  Future<void> _editSettings() async {
    final token = await RelayController.getToken();
    if (!mounted) return;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _SettingsDialog(initialUrl: _url, initialToken: token),
    );
    if (result == null || result.$1.isEmpty) return;
    await RelayController.saveSettings(url: result.$1, token: result.$2);
    final url = await RelayController.getUrl();
    if (mounted) setState(() => _url = url);
    _refresh();
  }

  Future<void> _rename(int relay) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initialName: _names[relay - 1]),
    );
    if (name == null) return;
    await RelayController.setName(relay, name);
    final names = await RelayController.getNames(_states?.length ?? 0);
    if (mounted) setState(() => _names = names);
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
        title: const Text('Tomadas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          IconButton(
            tooltip: 'Configurar controlador',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _editSettings,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppTheme.primaryOrange,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            // The relay list only exists once the board has answered.
            if (_states != null) ...[
              for (var relay = 1; relay <= _states!.length; relay++)
                _buildRelayTile(relay),
              const SizedBox(height: 8),
              Text(
                'Toque e segure um relé para renomear.',
                style: AppTheme.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final Color color;
    final String label;
    switch (_online) {
      case null:
        color = AppTheme.mediumBrown;
        label = 'Verificando…';
      case true:
        color = Colors.green.shade600;
        label = _uptime == null
            ? 'Online'
            : 'Online · ligado há ${_formatUptime(_uptime!)}';
      case false:
        color = Colors.red.shade600;
        label = _error ?? 'Offline';
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.valueBold),
                const SizedBox(height: 2),
                Text(_url, style: AppTheme.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelayTile(int relay) {
    final on = _states![relay - 1];
    final pending = _pending.contains(relay);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onLongPress: () => _rename(relay),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (on ? AppTheme.primaryOrange : AppTheme.mediumBrown)
                        .withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusXSmall),
                  ),
                  child: Icon(Icons.power_settings_new,
                      color: on
                          ? AppTheme.primaryOrange
                          : AppTheme.mediumBrown,
                      size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_names[relay - 1], style: AppTheme.valueBold),
                      const SizedBox(height: 2),
                      Text(
                        'Relé $relay · ${on ? 'ligado' : 'desligado'}',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
                if (pending)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primaryOrange),
                    ),
                  ),
                Switch(
                  value: on,
                  activeThumbColor: AppTheme.primaryOrange,
                  onChanged: pending ? null : (v) => _setRelay(relay, v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatUptime(int seconds) {
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (d > 0) return '${d}d ${h}h';
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }
}

/// URL + bearer token of the ESP8266. Owns its controllers so they are
/// disposed only after the dialog route is gone; pops (url, token).
class _SettingsDialog extends StatefulWidget {
  final String initialUrl;
  final String initialToken;

  const _SettingsDialog(
      {required this.initialUrl, required this.initialToken});

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final TextEditingController _url;
  late final TextEditingController _token;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.initialUrl);
    _token = TextEditingController(text: widget.initialToken);
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.creamBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: const Text('Controlador', style: AppTheme.sectionTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Endereço',
              hintText: RelayController.defaultUrl,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Token da API'),
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
          onPressed: () =>
              Navigator.pop(context, (_url.text.trim(), _token.text.trim())),
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

class _RenameDialog extends StatefulWidget {
  final String initialName;

  const _RenameDialog({required this.initialName});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
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
      title: const Text('Renomear', style: AppTheme.sectionTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar',
              style: TextStyle(color: AppTheme.mediumBrown)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
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
