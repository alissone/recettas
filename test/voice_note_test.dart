import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/models/voice_note.dart';

VoiceNote _note(String? summary) => VoiceNote.fromJson({
      'id': 'n1',
      'status': 'done',
      'summary': summary,
      'summary_status': summary == null ? null : 'done',
      'recorded_at': '2026-10-21T12:00:00Z',
    });

void main() {
  test('summaryItems keeps bullet lines and strips markers', () {
    final note = _note('- Ligar para o dentista\n'
        '* Comprar ração\n'
        '- [ ] Pagar a luz até sexta\n'
        '\n'
        'Texto solto que não é item\n'
        '-   \n');
    expect(note.summaryItems, [
      'Ligar para o dentista',
      'Comprar ração',
      'Pagar a luz até sexta',
    ]);
  });

  test('no summary yields no items', () {
    expect(_note(null).summaryItems, isEmpty);
    expect(_note(null).summaryStatus, isNull);
  });

  test('unknown status falls back to queued', () {
    final note = VoiceNote.fromJson({
      'id': 'n2',
      'status': 'weird',
      'recorded_at': '2026-10-21T12:00:00Z',
    });
    expect(note.status, VoiceNoteStatus.queued);
  });

  test('shopping items, expenses and task statuses are parsed', () {
    final note = VoiceNote.fromJson({
      'id': 'n3',
      'status': 'done',
      'shopping': '- Leite\n- Ovos (2 dúzias)\n',
      'shopping_status': 'done',
      'expenses': [
        {
          'item': '3 linguiças',
          'valor': 10.5,
          'local': 'Mello',
          'data': '2026-10-22',
          'categoria': 'Comida',
        },
        {'item': 'sabonete', 'valor': 2, 'local': null, 'data': '2026-10-23'},
      ],
      'expenses_status': 'processing',
      'recorded_at': '2026-10-23T12:00:00Z',
    });
    expect(note.shoppingItems, ['Leite', 'Ovos (2 dúzias)']);
    expect(note.expenses.map((e) => e.valor), [10.5, 2.0]);
    expect(note.expenses.first.local, 'Mello');
    expect(note.expenses.last.local, isNull);
    expect(note.statusOf(VoiceTask.expenses), VoiceTaskStatus.processing);
    expect(note.statusOf(VoiceTask.shopping), VoiceTaskStatus.done);
    expect(note.statusOf(VoiceTask.summary), isNull);
  });

  test('rows from before migration 046 get defaults, no notice', () {
    final note = _note(null);
    expect(note.language, VoiceLanguage.pt);
    expect(note.agentStatus, isNull);
    expect(note.agentActions, isEmpty);
    expect(note.agentNeedsNotice, isFalse);
  });

  test('assistant actions are parsed and keep their raw fields', () {
    final note = VoiceNote.fromJson({
      'id': 'n4',
      'status': 'done',
      'language': 'en',
      'agent_status': 'done',
      'agent_notified': false,
      'agent_actions': [
        {
          'id': 'a1',
          'tool': 'add_shopping_items',
          'summary': 'Compras: Bread',
          'confidence': 1.0,
          'status': 'done',
          'args': {'items': ['Bread']},
          'rows': [{'table': 'shopping_items', 'id': 'r1'}],
        },
        {
          'id': 'a2',
          'tool': 'create_event',
          'summary': 'Evento: Call mom (18/11)',
          'confidence': 0.6,
          'reason': 'confiança 0.60',
          'status': 'pending',
        },
      ],
      'recorded_at': '2026-11-17T12:00:00Z',
    });
    expect(note.language, VoiceLanguage.en);
    expect(note.agentStatus, VoiceAgentStatus.done);
    expect(note.agentNeedsNotice, isTrue);
    expect(note.agentActions.map((a) => a.isDone), [true, false]);
    expect(note.agentActions.last.isPending, isTrue);
    final undo = note.agentActions.first.toJsonWithStatus('undo');
    expect(undo['status'], 'undo');
    expect(undo['rows'], [
      {'table': 'shopping_items', 'id': 'r1'}
    ]);
  });
}
