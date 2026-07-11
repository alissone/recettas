import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/screens/harpa_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  Future<void> pumpUntilLoaded(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialAppWrapper());
    // The JSON asset is decoded on a real isolate, which does not advance
    // under fake async — wait for it with runAsync, then pump the result.
    for (var i = 0; i < 50; i++) {
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      if (find.byType(TextField).evaluate().isNotEmpty) return;
    }
    fail('HarpaScreen never finished loading the hymns');
  }

  testWidgets('HarpaScreen loads and lists the hymns', (tester) async {
    await pumpUntilLoaded(tester);

    // Hymn 1 should be visible at the top of the list.
    expect(find.text('Chuvas de Graça'), findsOneWidget);

    // Searching by number filters the list.
    await tester.enterText(find.byType(TextField), '640');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum hino encontrado'), findsNothing);

    // Searching by name ignores accents.
    await tester.enterText(find.byType(TextField), 'saudosa lembranca');
    await tester.pumpAndSettle();
    expect(find.text('Saudosa Lembrança'), findsOneWidget);
  });

  testWidgets('HymnViewerScreen renders verses and chorus', (tester) async {
    await pumpUntilLoaded(tester);

    await tester.tap(find.text('Chuvas de Graça'));
    await tester.pumpAndSettle();

    expect(find.text('Hino 1'), findsOneWidget);
    expect(find.text('Coro'), findsOneWidget);
    expect(find.textContaining('Deus prometeu com certeza'), findsOneWidget);
    expect(find.text('1 de 640'), findsOneWidget);
  });
}

class MaterialAppWrapper extends StatelessWidget {
  const MaterialAppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HarpaScreen());
  }
}
