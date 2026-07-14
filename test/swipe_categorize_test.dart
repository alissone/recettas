import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/models/category_base.dart';
import 'package:recettas/models/purchase_category.dart';
import 'package:recettas/widgets/categorize_overlay.dart';
import 'package:recettas/widgets/swipe_action_card.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Stack(children: [child])));

void main() {
  group('SwipeActionCard', () {
    testWidgets('swipe left past threshold deletes', (tester) async {
      var deleted = false;
      await tester.pumpWidget(_wrap(SwipeActionCard(
        canCategorize: true,
        onDelete: () => deleted = true,
        onCategorizeStart: () {},
        onCategorizeDragUpdate: (_) {},
        onCategorizeDragEnd: (_) {},
        child: const SizedBox(height: 60, child: Text('item')),
      )));

      await tester.drag(find.text('item'), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });

    testWidgets('swipe right past threshold starts categorizing',
        (tester) async {
      var started = false;
      await tester.pumpWidget(_wrap(SwipeActionCard(
        canCategorize: true,
        onDelete: () {},
        onCategorizeStart: () => started = true,
        onCategorizeDragUpdate: (_) {},
        onCategorizeDragEnd: (_) {},
        child: const SizedBox(height: 60, child: Text('item')),
      )));

      await tester.drag(find.text('item'), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(started, isTrue);
    });

    testWidgets('swipe right does nothing without categories',
        (tester) async {
      var started = false;
      await tester.pumpWidget(_wrap(SwipeActionCard(
        canCategorize: false,
        onDelete: () {},
        onCategorizeStart: () => started = true,
        onCategorizeDragUpdate: (_) {},
        onCategorizeDragEnd: (_) {},
        child: const SizedBox(height: 60, child: Text('item')),
      )));

      await tester.drag(find.text('item'), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(started, isFalse);
    });

    testWidgets('tap opens edit', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(SwipeActionCard(
        canCategorize: true,
        onDelete: () {},
        onCategorizeStart: () {},
        onCategorizeDragUpdate: (_) {},
        onCategorizeDragEnd: (_) {},
        onTap: () => tapped = true,
        child: const SizedBox(height: 60, child: Text('item')),
      )));

      await tester.tap(find.text('item'));
      expect(tapped, isTrue);
    });
  });

  group('CategorizeOverlay', () {
    const categories = [
      PurchaseCategory(
          id: 'c1', userId: 'u', name: 'Alimentacao', colorValue: 0xFF10B981),
      PurchaseCategory(
          id: 'c2', userId: 'u', name: 'Casa', colorValue: 0xFFF59E0B),
    ];

    testWidgets('tapping a squircle assigns that category',
        (tester) async {
      CategoryBase? assigned;
      var assignCalled = false;
      await tester.pumpWidget(_wrap(CategorizeOverlay(
        categories: categories,
        itemLabel: 'Arroz',
        onAssign: (c) {
          assignCalled = true;
          assigned = c;
        },
        onDismiss: () {},
      )));

      await tester.tap(find.text('Casa'));
      expect(assignCalled, isTrue);
      expect(assigned?.id, 'c2');
    });

    testWidgets('tapping "Nenhuma" assigns null', (tester) async {
      CategoryBase? assigned = categories.first;
      await tester.pumpWidget(_wrap(CategorizeOverlay(
        categories: categories,
        itemLabel: 'Arroz',
        onAssign: (c) => assigned = c,
        onDismiss: () {},
      )));

      await tester.tap(find.text('Nenhuma'));
      expect(assigned, isNull);
    });

    testWidgets('ending a drag outside any squircle dismisses',
        (tester) async {
      var dismissed = false;
      final key = GlobalKey<CategorizeOverlayState>();
      await tester.pumpWidget(_wrap(CategorizeOverlay(
        key: key,
        categories: categories,
        itemLabel: 'Arroz',
        onAssign: (_) {},
        onDismiss: () => dismissed = true,
      )));

      key.currentState!.endDrag(Offset.zero);
      expect(dismissed, isTrue);
    });

    testWidgets('ending a drag over a squircle assigns it',
        (tester) async {
      CategoryBase? assigned;
      final key = GlobalKey<CategorizeOverlayState>();
      await tester.pumpWidget(_wrap(CategorizeOverlay(
        key: key,
        categories: categories,
        itemLabel: 'Arroz',
        onAssign: (c) => assigned = c,
        onDismiss: () {},
      )));

      final pos = tester.getCenter(find.text('A'));
      key.currentState!.updateDrag(pos);
      await tester.pump();
      key.currentState!.endDrag(pos);
      expect(assigned?.id, 'c1');
    });
  });
}
