import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bot_chat.dart';
import '../models/todo.dart';
import '../models/todo_card.dart';
import '../models/todo_category.dart';
import '../models/todo_daily.dart';
import 'supabase_service.dart';

/// Chats with the local assistant (migration 047). Online only, like the
/// person-to-person chat: the app writes the user's messages and the PC
/// worker (transcriber/bot_chat.py) writes the replies, so everything is
/// stored and comes back when the app is reopened.
class BotChatRepository {
  BotChatRepository._();

  static final BotChatRepository instance = BotChatRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Where the todo snapshot comes from. Defaults to Supabase (what the
  /// web build has); the app swaps in its local cache in main.dart, which
  /// is exactly what the Afazeres tab shows.
  static Future<(List<Todo>, List<TodoCategory>)> Function() loadTodos =
      _loadTodosFromServer;

  static Future<(List<Todo>, List<TodoCategory>)>
      _loadTodosFromServer() async {
    final results = await Future.wait([
      SupabaseService.getOpenTodos(),
      SupabaseService.getTodoCategories(),
    ]);
    final todos = results[0] as List<Todo>;
    // Same as the app: "@today" pins first, then the manual order.
    return (
      [...todos.where((t) => t.isToday), ...todos.where((t) => !t.isToday)],
      results[1] as List<TodoCategory>,
    );
  }

  // --- Chats ---

  Stream<List<BotChat>> streamChats() {
    final uid = _client.auth.currentUser!.id;
    return _client
        .from('bot_chats')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .map((rows) => rows.map(BotChat.fromJson).toList()
          ..sort((a, b) => b.sortTime.compareTo(a.sortTime)));
  }

  Future<BotChat> createChat({String title = 'Assistente'}) async {
    final row = await _client
        .from('bot_chats')
        .insert({'user_id': _client.auth.currentUser!.id, 'title': title})
        .select()
        .single();
    return BotChat.fromJson(row);
  }

  Future<void> renameChat(String chatId, String title) =>
      _client.from('bot_chats').update({'title': title}).eq('id', chatId);

  Future<void> deleteChat(String chatId) =>
      _client.from('bot_chats').delete().eq('id', chatId);

  // --- Messages ---

  Stream<List<BotMessage>> streamMessages(String chatId) {
    return _client
        .from('bot_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(BotMessage.fromJson).toList()
          ..sort((a, b) {
            final byTime = a.createdAt.compareTo(b.createdAt);
            return byTime != 0 ? byTime : a.id.compareTo(b.id);
          }));
  }

  /// Queues [content] for the assistant; the worker answers it.
  Future<void> send(String chatId, String content, {String? context}) async {
    await _client.from('bot_messages').insert({
      'chat_id': chatId,
      'user_id': _client.auth.currentUser!.id,
      'role': 'user',
      'content': content,
      if (context != null) 'context': context,
      'status': 'requested',
    });
  }

  Future<void> retry(String messageId) => _client.from('bot_messages').update({
        'status': 'requested',
        'error_message': null,
      }).eq('id', messageId);

  /// Stops waiting for an answer; the worker drops it if it was thinking.
  Future<void> cancel(String messageId) => _client.from('bot_messages').update({
        'status': 'error',
        'error_message': 'Cancelado',
      }).eq('id', messageId);

  // --- Todo snapshot ---

  /// Most open todos sent to the model; the rest are only counted.
  static const maxTodos = 40;

  /// The todo list as plain text, in the order the app shows it, for the
  /// "Resumir meus afazeres" / "Prioridades" buttons.
  Future<String> todoSnapshot() async {
    final (todos, categories) = await loadTodos();
    final names = {for (final c in categories) c.id: c.name};
    final listed = todos.where((t) => TodoDaily.isListed(t)).toList();
    final open = listed.where((t) => !t.isCompleted).toList();
    final done = listed.where((t) => t.isCompleted).toList();

    final now = DateTime.now();
    final buffer = StringBuffer(
      'Afazeres em aberto, na ordem em que aparecem no app '
      '(hoje é ${TodoCard.formatDate(now)}):\n',
    );
    if (open.isEmpty) buffer.writeln('(nenhum)');
    for (var i = 0; i < open.length && i < maxTodos; i++) {
      buffer.writeln('${i + 1}. ${_describe(open[i], names)}');
    }
    if (open.length > maxTodos) {
      buffer.writeln('... e mais ${open.length - maxTodos} itens abaixo.');
    }
    if (done.isNotEmpty) {
      buffer.writeln('\nJá concluídos hoje:');
      for (final t in done.take(20)) {
        buffer.writeln('- ${TodoCard.parse(t.title).summary}');
      }
    }
    return buffer.toString().trim();
  }

  static String _describe(Todo todo, Map<String, String> categoryNames) {
    final card = TodoCard.parse(todo.title);
    final tags = <String>[
      if (todo.isToday) 'fixado para hoje',
      if (card.isDaily) 'diário',
      if (card.isMonthly) 'mensal',
      if (categoryNames[todo.categoryId] != null)
        'categoria: ${categoryNames[todo.categoryId]}',
    ];

    final String head;
    switch (card.kind) {
      case TodoKind.event:
        final when = [
          if (card.date != null) TodoCard.formatDate(card.date!),
          if (card.start != null) TodoCard.formatTime(card.start!),
        ].join(' ');
        head = 'Evento: ${card.eventDisplayTitle}'
            '${when.isEmpty ? '' : ' ($when)'}';
      case TodoKind.move:
        head = 'Levar de ${card.from.isEmpty ? '?' : card.from} '
            'para ${card.to.isEmpty ? '?' : card.to}';
      case TodoKind.todo:
        head = card.summary.trim();
    }

    // Checklist lines and notes under the first line, kept short.
    final lines = card.body
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final extra = (card.kind == TodoKind.todo ? lines.skip(1) : lines)
        .where((l) => l != head)
        .take(6)
        .map((l) => '\n   $l');

    return '$head${tags.isEmpty ? '' : ' [${tags.join(', ')}]'}'
        '${extra.join()}';
  }
}
