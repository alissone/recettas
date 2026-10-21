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
}
