import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_theme.dart';
import '../models/chat.dart';
import '../services/chat_notifier.dart';
import '../services/supabase_service.dart';
import '../utils/dates.dart';
import 'chat_room_screen.dart';

/// "Chat" tab: the inbox. Rows are styled like the utility tiles on the
/// "Mais" tab - a white card with a leading badge, title, subtitle and
/// chevron - so the two lists read as the same kind of list.
///
/// The rooms themselves come from [ChatNotifier], which holds the one
/// realtime subscription for the whole app; this screen only renders
/// what it publishes.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  /// Index of this screen in the bottom navigation bar.
  static const tabIndex = 3;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _opening = false;
  StreamSubscription<AuthState>? _authSubscription;

  bool get _isAuthenticated => SupabaseService.currentUser != null;

  @override
  void initState() {
    super.initState();
    // The IndexedStack builds this tab at app start, so signing in
    // later has to swap the placeholder for the inbox from here.
    _authSubscription = SupabaseService.authDataChanges.listen(
      (_) {
        if (mounted) setState(() {});
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _newChat() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => const _NewChatDialog(),
    );
    if (email == null || email.isEmpty) return;
    await _open(email);
  }

  /// Opening by address is the only step that needs the address: from
  /// here on the room is in the list for good.
  Future<void> _open(String email) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final room = await SupabaseService.openChatRoom(email);
      if (!mounted) return;
      _push(room);
    } on ArgumentError catch (e) {
      _snack(e.message.toString());
    } catch (e) {
      _snack('Não foi possível abrir a conversa: $e');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _push(ChatRoom room) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatRoomScreen(room: room)),
    );
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
      floatingActionButton: _isAuthenticated
          ? FloatingActionButton(
              heroTag: 'chat_fab',
              onPressed: _opening ? null : _newChat,
              tooltip: 'Nova conversa',
              child: _opening
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_comment_outlined),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('Conversas', style: AppTheme.headingLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'Mensagens em tempo real',
                style:
                    AppTheme.bodyText.copyWith(color: AppTheme.mediumBrown),
              ),
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (!_isAuthenticated) {
      return _buildPlaceholder(
        icon: Icons.lock_outline,
        title: 'Entre na sua conta',
        body: 'As conversas ficam vinculadas ao seu e-mail.',
      );
    }
    // Both notifiers matter: `rooms` for the content, `unreadRooms` so
    // opening a conversation clears its bold preview and dot on the way
    // back without waiting for the next message.
    return ListenableBuilder(
      listenable: Listenable.merge([
        ChatNotifier.instance.rooms,
        ChatNotifier.instance.unreadRooms,
      ]),
      builder: (context, _) {
        final rooms = ChatNotifier.instance.rooms.value;
        if (rooms.isEmpty) {
          return _buildPlaceholder(
            icon: Icons.forum_outlined,
            title: 'Nenhuma conversa ainda',
            body: 'Toque em + e informe o e-mail de quem você quer '
                'conversar. Depois disso a conversa fica aqui para '
                'sempre.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
          itemCount: rooms.length,
          itemBuilder: (context, index) => _buildRoomTile(rooms[index]),
        );
      },
    );
  }

  Widget _buildRoomTile(ChatRoom room) {
    final myEmail = SupabaseService.currentEmail ?? '';
    final label = room.partnerLabel(myEmail);
    final unread = ChatNotifier.instance.hasUnread(room);
    final preview = room.lastMessage?.trim();
    final sentByMe = (room.lastSenderEmail ?? '').toLowerCase() == myEmail;

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
          onTap: () => _push(room),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ChatAvatar(label: label, size: 44),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTheme.valueBold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preview == null || preview.isEmpty
                            ? 'Nenhuma mensagem ainda'
                            : sentByMe
                                ? 'Você: $preview'
                                : preview,
                        style: AppTheme.caption.copyWith(
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w400,
                          color: unread
                              ? AppTheme.darkBrown
                              : AppTheme.mediumBrown,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatChatStamp(room.lastMessageAt),
                      style: AppTheme.caption.copyWith(
                        fontWeight: FontWeight.w500,
                        color: unread
                            ? AppTheme.primaryOrange
                            : AppTheme.mediumBrown,
                      ),
                    ),
                    const SizedBox(height: 6),
                    unread
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryOrange,
                              shape: BoxShape.circle,
                            ),
                          )
                        : const Icon(Icons.chevron_right,
                            size: 18, color: AppTheme.mediumBrown),
                  ],
                ),
              ],
            ),
          ),
        ),
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

/// Circular initial badge standing in for a photo, in the same orange
/// as the icon tiles on "Mais".
class ChatAvatar extends StatelessWidget {
  final String label;
  final double size;

  const ChatAvatar({super.key, required this.label, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final initial =
        label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryOrange,
          ),
        ),
      ),
    );
  }
}

/// "14:32" today, "Ontem" yesterday, "05/03" this year, "05/03/24"
/// before that - the compact stamp on an inbox row.
String formatChatStamp(DateTime? at) {
  if (at == null) return '';
  final now = DateTime.now();
  final day = DateTime(at.year, at.month, at.day);
  final todayStart = DateTime(now.year, now.month, now.day);
  if (day == todayStart) return formatChatTime(at);
  if (day == todayStart.subtract(const Duration(days: 1))) return 'Ontem';
  if (at.year == now.year) return formatDayMonth(at);
  return '${formatDayMonth(at)}/${at.year.toString().substring(2)}';
}

/// "09:41".
String formatChatTime(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:'
    '${at.minute.toString().padLeft(2, '0')}';

class _NewChatDialog extends StatefulWidget {
  const _NewChatDialog();

  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
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
      title: const Text('Nova conversa', style: AppTheme.sectionTitle),
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
            'O e-mail só é preciso desta vez: a conversa fica na lista '
            'a partir de agora. A outra pessoa a vê assim que entrar '
            'com esse endereço.',
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
          child: const Text('Conversar'),
        ),
      ],
    );
  }
}
