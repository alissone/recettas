import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat.dart';
import 'supabase_service.dart';

/// The app's single subscription to the chat inbox.
///
/// One realtime stream feeds three things at once: the Chat tab's list,
/// the unread badge on the bottom nav, and the in-app banner that fires
/// when a message lands while the user is somewhere else. Keeping it
/// here rather than in the list screen matters because the tab lives in
/// an IndexedStack - the screen is alive the whole session, but the
/// banner has to work before the user has ever opened it.
class ChatNotifier {
  ChatNotifier._();

  static final ChatNotifier instance = ChatNotifier._();

  static String _readKey(String roomId) => 'chat_read_$roomId';

  /// Inbox, newest activity first. Empty while signed out.
  final ValueNotifier<List<ChatRoom>> rooms = ValueNotifier([]);

  /// Number of rooms holding messages the user hasn't opened yet - what
  /// the bottom-nav badge shows.
  final ValueNotifier<int> unreadRooms = ValueNotifier(0);

  /// Last room to receive a message the user hasn't seen, published for
  /// HomeShell to raise its banner. Cleared once shown.
  final ValueNotifier<ChatRoom?> incoming = ValueNotifier(null);

  /// Set by the open conversation so its own messages don't raise a
  /// banner over the screen already showing them.
  String? openRoomId;

  StreamSubscription<List<ChatRoom>>? _roomsSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  /// Bumped by every start and stop. A start that awaits its way past a
  /// newer one bails out instead of installing a second subscription -
  /// which is easy to hit at launch, where init() and the initialSession
  /// event both ask to start.
  int _generation = 0;

  /// Newest message time already accounted for, per room. Seeded from
  /// the first snapshot so a session start never replays the backlog as
  /// notifications.
  final Map<String, DateTime> _seen = {};
  bool _seeded = false;

  /// Persisted per room: when the user last had the conversation open.
  final Map<String, DateTime> _readAt = {};

  /// Cached display names, so a snapshot only queries `profiles` when a
  /// partner it hasn't resolved yet shows up.
  final Map<String, String> _names = {};

  Future<void> init() async {
    _authSubscription ??= SupabaseService.authDataChanges.listen(
      (state) => state.session == null ? _stop() : unawaited(_start()),
      onError: (_) {},
    );
    if (SupabaseService.currentUser != null) await _start();
  }

  Future<void> _start() async {
    final generation = ++_generation;
    await _roomsSubscription?.cancel();
    _roomsSubscription = null;
    _seen.clear();
    _seeded = false;
    await _loadReadTimes();
    if (generation != _generation) return;
    _roomsSubscription = SupabaseService.streamChatRooms().listen(
      _onRooms,
      // A dropped realtime socket or an RLS hiccup must not take the
      // rest of the app down with an unhandled stream error.
      onError: (_) {},
    );
  }

  void _stop() {
    _generation++;
    _roomsSubscription?.cancel();
    _roomsSubscription = null;
    _seen.clear();
    _readAt.clear();
    _names.clear();
    _seeded = false;
    openRoomId = null;
    rooms.value = [];
    unreadRooms.value = 0;
    incoming.value = null;
  }

  Future<void> _loadReadTimes() async {
    final prefs = await SharedPreferences.getInstance();
    _readAt.clear();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('chat_read_')) continue;
      final millis = prefs.getInt(key);
      if (millis == null) continue;
      _readAt[key.substring('chat_read_'.length)] =
          DateTime.fromMillisecondsSinceEpoch(millis);
    }
  }

  Future<void> _onRooms(List<ChatRoom> incomingRooms) async {
    final resolved = await _withPartnerNames(incomingRooms);
    rooms.value = resolved;

    final myEmail = SupabaseService.currentEmail ?? '';
    ChatRoom? banner;

    for (final room in resolved) {
      final at = room.lastMessageAt;
      if (at == null) continue;
      final previous = _seen[room.id];
      _seen[room.id] = at;
      if (!_seeded || previous == null || !at.isAfter(previous)) continue;
      final fromPartner =
          (room.lastSenderEmail ?? '').toLowerCase() != myEmail;
      if (fromPartner && room.id != openRoomId) banner = room;
    }
    _seeded = true;

    _recountUnread();
    if (banner != null) incoming.value = banner;
  }

  /// Fills in display names, querying only for partners not already
  /// cached. A partner with no account yet stays unnamed and renders as
  /// their address.
  Future<List<ChatRoom>> _withPartnerNames(List<ChatRoom> source) async {
    final myEmail = SupabaseService.currentEmail ?? '';
    final missing = <String>{};
    for (final room in source) {
      final email = room.partnerEmail(myEmail);
      if (email.isNotEmpty && !_names.containsKey(email)) missing.add(email);
    }
    if (missing.isNotEmpty) {
      try {
        final found = await SupabaseService.getChatPartnerNames(missing);
        _names.addAll(found);
      } catch (_) {
        // Names are cosmetic; the address is always available.
      }
    }
    return [
      for (final room in source)
        room.withPartnerName(_names[room.partnerEmail(myEmail)])
    ];
  }

  void _recountUnread() {
    unreadRooms.value = rooms.value.where(hasUnread).length;
  }

  /// A room counts as unread when its newest message came from the
  /// partner after the last time the user had it open.
  bool hasUnread(ChatRoom room) {
    final at = room.lastMessageAt;
    if (at == null) return false;
    final myEmail = SupabaseService.currentEmail ?? '';
    if ((room.lastSenderEmail ?? '').toLowerCase() == myEmail) return false;
    final read = _readAt[room.id];
    return read == null || at.isAfter(read);
  }

  Future<void> markRead(String roomId) async {
    final now = DateTime.now();
    _readAt[roomId] = now;
    _recountUnread();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_readKey(roomId), now.millisecondsSinceEpoch);
  }

  void dismissIncoming() => incoming.value = null;
}
