import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/models/contact.dart';
import 'package:recettas/models/todo_tags.dart';

Contact _contact(String nickname, {String? userId}) => Contact(
      id: nickname,
      ownerId: 'me',
      email: '$nickname@example.com',
      nickname: nickname,
      contactUserId: userId,
    );

void main() {
  test('handles skips e-mails, @today and trailing punctuation', () {
    expect(
      TodoTags.handles('Ligar @ana e @Mãe. mail me@foo.com @today @Ana'),
      ['ana', 'Mãe'],
    );
  });

  test('assigneeIds only includes tagged contacts with an account', () {
    final contacts = [
      _contact('Ana', userId: 'u-ana'),
      _contact('Pedro'),
      _contact('Bia', userId: 'u-bia'),
    ];
    expect(TodoTags.assigneeIds('Lavar a louça @ana @Pedro', contacts),
        ['u-ana']);
  });

  test('stripToday removes the pin wherever it is', () {
    expect(TodoTags.stripToday('@hoje comprar pão'), 'comprar pão');
    expect(TodoTags.stripToday('comprar @TODAY pão'), 'comprar pão');
    expect(TodoTags.stripToday('comprar pão @today'), 'comprar pão');
    expect(TodoTags.stripToday('comprar @todayish'), 'comprar @todayish');
    expect(TodoTags.hasToday('x @hoje.'), isTrue);
    expect(TodoTags.hasToday('x @todayish'), isFalse);
  });

  test('withToday appends the pin to the first body line', () {
    expect(TodoTags.withToday('Comprar pão\n- [ ] leite'),
        'Comprar pão @today\n- [ ] leite');
    expect(TodoTags.withToday('---\ntype: event\ntitle: X\n---\nnotas'),
        '---\ntype: event\ntitle: X\n---\nnotas @today');
  });

  test('nicknamePattern accepts one word', () {
    expect(TodoTags.nicknamePattern.hasMatch('João_2'), isTrue);
    expect(TodoTags.nicknamePattern.hasMatch('a b'), isFalse);
    expect(TodoTags.nicknamePattern.hasMatch('ana.'), isFalse);
  });
}
