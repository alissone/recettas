import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import '../models/chat.dart';
import '../services/chat_notifier.dart';
import '../services/supabase_service.dart';
import '../utils/dates.dart';
import 'chat_list_screen.dart' show ChatAvatar, formatChatTime;

/// How much history the conversation shows. The messages are never
/// deleted - this only narrows what's on screen, so a phone handed to
/// someone else doesn't show a backlog.
class ChatWindow {
  final String label;
  final int minutes;

  const ChatWindow(this.label, this.minutes);

  static const all = ChatWindow('Tudo', 0);

  static const options = [
    all,
    ChatWindow('Último 1 minuto', 1),
    ChatWindow('Últimos 5 minutos', 5),
    ChatWindow('Últimos 15 minutos', 15),
    ChatWindow('Última 1 hora', 60),
    ChatWindow('Últimas 24 horas', 1440),
    ChatWindow('Últimos 7 dias', 10080),
  ];

  static ChatWindow fromMinutes(int minutes) => options.firstWhere(
        (w) => w.minutes == minutes,
        orElse: () => all,
      );
}

/// One conversation, live. Messages stream in over Supabase realtime;
/// sending is a plain insert, and the row comes back through the same
/// stream, so there is no optimistic copy to reconcile.
class ChatRoomScreen extends StatefulWidget {
  final ChatRoom room;

  const ChatRoomScreen({super.key, required this.room});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  static String _windowKey(String roomId) => 'chat_window_$roomId';

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  StreamSubscription<List<ChatMessage>>? _subscription;
  List<ChatMessage> _messages = [];
  bool _loading = true;
  String? _error;
  bool _sending = false;

  /// Messages that showed up while this screen was open - only those
  /// slide in. Everything already on screen when it opened renders at
  /// rest, so returning to a chat isn't a wall of animation.
  final Set<String> _arrived = {};
  bool _firstSnapshot = true;

  ChatWindow _window = ChatWindow.all;

  /// Ages messages out of an active window without waiting for the next
  /// message to trigger a rebuild.
  Timer? _windowTicker;

  String get _myEmail => SupabaseService.currentEmail ?? '';

  @override
  void initState() {
    super.initState();
    ChatNotifier.instance.openRoomId = widget.room.id;
    ChatNotifier.instance.markRead(widget.room.id);
    _loadWindow();
    _subscribe();
  }

  @override
  void dispose() {
    if (ChatNotifier.instance.openRoomId == widget.room.id) {
      ChatNotifier.instance.openRoomId = null;
    }
    _windowTicker?.cancel();
    _subscription?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _subscribe() {
    _subscription =
        SupabaseService.streamChatMessages(widget.room.id).listen(
      (messages) {
        if (!mounted) return;
        if (!_firstSnapshot) {
          final known = _messages.map((m) => m.id).toSet();
          for (final message in messages) {
            if (!known.contains(message.id)) _arrived.add(message.id);
          }
        }
        _firstSnapshot = false;
        setState(() {
          _messages = messages;
          _loading = false;
          _error = null;
        });
        // Reading the newest message is what clears the badge; the
        // stream fires while the screen is open, so mark it here too.
        ChatNotifier.instance.markRead(widget.room.id);
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = '$error';
        });
      },
    );
  }

  // --- Visibility window ---

  Future<void> _loadWindow() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_windowKey(widget.room.id)) ?? 0;
    if (!mounted) return;
    setState(() => _window = ChatWindow.fromMinutes(minutes));
    _syncTicker();
  }

  Future<void> _setWindow(ChatWindow window) async {
    setState(() => _window = window);
    _syncTicker();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_windowKey(widget.room.id), window.minutes);
  }

  void _syncTicker() {
    _windowTicker?.cancel();
    if (_window.minutes == 0) {
      _windowTicker = null;
      return;
    }
    // Fine enough for a one-minute window without waking the app up
    // constantly on a seven-day one.
    final period = _window.minutes <= 5
        ? const Duration(seconds: 5)
        : const Duration(seconds: 30);
    _windowTicker = Timer.periodic(period, (_) {
      if (mounted) setState(() {});
    });
  }

  /// The messages the window lets through, oldest first.
  List<ChatMessage> get _visible {
    if (_window.minutes == 0) return _messages;
    final cutoff =
        DateTime.now().subtract(Duration(minutes: _window.minutes));
    return _messages.where((m) => m.createdAt.isAfter(cutoff)).toList();
  }

  // --- Sending ---

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await SupabaseService.sendChatMessage(widget.room.id, text);
      _controller.clear();
      _focusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Não foi possível enviar: $e'),
          backgroundColor: AppTheme.darkBrown,
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final label = widget.room.partnerLabel(_myEmail);
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            ChatAvatar(label: label, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppTheme.sectionTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<ChatWindow>(
            tooltip: 'Mostrar mensagens de',
            icon: Icon(
              _window.minutes == 0
                  ? Icons.history_toggle_off
                  : Icons.timelapse,
              color: _window.minutes == 0
                  ? AppTheme.darkBrown
                  : AppTheme.primaryOrange,
            ),
            color: AppTheme.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            onSelected: _setWindow,
            itemBuilder: (context) => [
              const PopupMenuItem<ChatWindow>(
                enabled: false,
                height: 34,
                child: Text('Mostrar mensagens de',
                    style: AppTheme.caption),
              ),
              for (final option in ChatWindow.options)
                PopupMenuItem<ChatWindow>(
                  value: option,
                  child: Row(
                    children: [
                      Icon(
                        option.minutes == _window.minutes
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: option.minutes == _window.minutes
                            ? AppTheme.primaryOrange
                            : AppTheme.mediumBrown,
                      ),
                      const SizedBox(width: 10),
                      Text(option.label,
                          style: AppTheme.bodyText
                              .copyWith(fontSize: 14)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_window.minutes != 0) _buildWindowNotice(),
            Expanded(child: _buildMessages()),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowNotice() {
    final hidden = _messages.length - _visible.length;
    return Container(
      width: double.infinity,
      color: AppTheme.lightPeach,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.visibility_off_outlined,
              size: 16, color: AppTheme.mediumBrown),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hidden > 0
                  ? '${_window.label.toLowerCase()} · '
                      '$hidden ${hidden == 1 ? "mensagem oculta" : "mensagens ocultas"}'
                  : _window.label.toLowerCase(),
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: () => _setWindow(ChatWindow.all),
            behavior: HitTestBehavior.opaque,
            child: Text(
              'Mostrar tudo',
              style: AppTheme.caption
                  .copyWith(color: AppTheme.primaryOrange),
            ),
          ),
        ],
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
      return _buildPlaceholder(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível carregar',
        body: _error!,
      );
    }

    final visible = _visible;
    if (visible.isEmpty) {
      return _buildPlaceholder(
        icon: Icons.chat_bubble_outline,
        title: _messages.isEmpty
            ? 'Comece a conversa'
            : 'Nada nesta janela de tempo',
        body: _messages.isEmpty
            ? 'Diga oi para ${widget.room.partnerLabel(_myEmail)}.'
            : 'As mensagens continuam salvas — só não estão à vista.',
      );
    }

    // Built oldest-first so a day pill precedes its own day, then shown
    // reversed: with reverse: true the list opens pinned to the newest
    // message and stays there as more arrive.
    final items = _chatItems(visible).reversed.toList();
    final showStart = _window.minutes == 0;

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: items.length + (showStart ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return _ConversationStartBanner(
            label: widget.room.partnerLabel(_myEmail),
          );
        }
        final item = items[index];
        if (item is DateTime) return _ChatDateBanner(date: item);
        final message = item as ChatMessage;
        return _MessageBubble(
          key: ValueKey(message.id),
          message: message,
          isMine: message.isMine(_myEmail),
          animate: _arrived.contains(message.id),
          onAnimated: () => _arrived.remove(message.id),
        );
      },
    );
  }

  /// Messages with a [DateTime] marker inserted before the first one of
  /// each calendar day.
  List<Object> _chatItems(List<ChatMessage> messages) {
    final items = <Object>[];
    DateTime? currentDay;
    for (final message in messages) {
      final at = message.createdAt;
      final day = DateTime(at.year, at.month, at.day);
      if (currentDay == null || day != currentDay) {
        items.add(day);
        currentDay = day;
      }
      items.add(message);
    }
    return items;
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryOrange.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              style: AppTheme.bodyText.copyWith(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Escreva uma mensagem...',
                hintStyle:
                    AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
                filled: true,
                fillColor: AppTheme.creamBackground,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppTheme.borderOrange),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                      color: AppTheme.primaryOrange, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppTheme.accentShadow,
            ),
            child: IconButton(
              tooltip: 'Enviar',
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 64,
                color: AppTheme.primaryOrange.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(title, style: AppTheme.sectionTitle,
                textAlign: TextAlign.center),
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

/// Pill marking where the conversation begins.
class _ConversationStartBanner extends StatelessWidget {
  final String label;

  const _ConversationStartBanner({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.lightPeach,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Text(
            'Este é o começo da sua conversa com $label.',
            textAlign: TextAlign.center,
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
          ),
        ),
      ),
    );
  }
}

/// Date pill between messages from different calendar days.
class _ChatDateBanner extends StatelessWidget {
  final DateTime date;

  const _ChatDateBanner({required this.date});

  /// "Hoje", "Ontem", "05/03" this year, "05/03/2024" before that.
  String get _label {
    final todayStart = today();
    if (date == todayStart) return 'Hoje';
    if (date == todayStart.subtract(const Duration(days: 1))) {
      return 'Ontem';
    }
    if (date.year == todayStart.year) return formatDayMonth(date);
    return '${formatDayMonth(date)}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.lightPeach,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _label,
            style: AppTheme.caption.copyWith(fontSize: 11),
          ),
        ),
      ),
    );
  }
}

/// A message, sliding in from its own side the first time it appears.
class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMine;
  final bool animate;
  final VoidCallback onAnimated;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.animate,
    required this.onAnimated,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 320),
    vsync: this,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: Offset(widget.isMine ? 0.25 : -0.25, 0),
    end: Offset.zero,
  ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.7, curve: Curves.easeOut),
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.9,
    end: 1.0,
  ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    if (!widget.animate) {
      // Settled straight away: no controller left ticking behind the
      // messages that were already on screen.
      _controller.value = 1;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward().then((_) => widget.onAnimated());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
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
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.message.content,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: mine ? Colors.white : AppTheme.darkBrown,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatChatTime(widget.message.createdAt),
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
            ),
          ),
        ),
      ),
    );
  }
}
