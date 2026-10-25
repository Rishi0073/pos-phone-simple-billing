import 'package:flutter_test/flutter_test.dart';
import 'package:simple_billing/features/billing/presentation/controllers/billing_controller.dart';
import 'package:simple_billing/features/billing/presentation/screens/main_billing_screen.dart';

import 'test_harness.dart';

Future<void> _pumpMain(WidgetTester tester, BillingController controller) async {
  usePhoneViewport(tester);
  await tester.pumpWidget(
    wrapWithProviders(
      billing: controller,
      child: const MainBillingScreen(shopName: 'Test Shop'),
    ),
  );
}

void main() {
  testWidgets('keypad drives the current item display', (tester) async {
    final controller = BillingController();
    await _pumpMain(tester, controller);

    expect(find.text('Test Shop'), findsOneWidget);
    expect(find.text('ITEMS: 0'), findsOneWidget);

    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('0'));
    await tester.pump();
    await tester.tap(find.text('0'));
    await tester.pump();

    expect(find.text('₹500'), findsNWidgets(3));
    expect(find.text('₹500 × 1'), findsOneWidget);

    await tester.tap(find.text('×'));
    await tester.pump();
    await tester.tap(find.text('4'));
    await tester.pump();

    expect(find.text('₹500 × 4'), findsOneWidget);
    expect(find.text('₹2,000'), findsNWidgets(2));
  });

  testWidgets('+ NEXT ITEM commits and resets display', (tester) async {
    final controller = BillingController();
    await _pumpMain(tester, controller);

    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('0'));
    await tester.pump();
    await tester.tap(find.text('0'));
    await tester.pump();
    await tester.tap(find.text('+ NEXT ITEM'));
    await tester.pump();

    expect(controller.savedCount, 1);
    expect(find.text('ITEMS: 1'), findsOneWidget);
    expect(find.text('₹0'), findsOneWidget);
    expect(find.text('₹500'), findsNWidgets(2));
  });

  testWidgets('backspace and clear behave', (tester) async {
    final controller = BillingController();
    await _pumpMain(tester, controller);

    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.text('⌫'));
    await tester.pump();

    expect(controller.current.price, 12);

    await tester.tap(find.text('C'));
    await tester.pump();
    expect(controller.current.price, 0);
  });

  testWidgets('clear with saved items asks for confirmation', (tester) async {
    final controller = BillingController();
    await _pumpMain(tester, controller);

    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('+ NEXT ITEM'));
    await tester.pump();
    expect(controller.savedCount, 1);

    await tester.tap(find.text('C'));
    await tester.pump();

    expect(find.text('CLEAR ALL ITEMS?'), findsOneWidget);
    expect(controller.savedCount, 1);

    await tester.tap(find.text('CANCEL'));
    await tester.pump();
    expect(controller.savedCount, 1);
  });

  testWidgets('recent prices appear and set the price when tapped',
      (tester) async {
    final bills = FakeBillRepository();
    await bills.addRecentPrice(450);
    usePhoneViewport(tester);
    await tester.pumpWidget(
      wrapWithProviders(
        billing: BillingController(),
        bills: bills,
        child: const MainBillingScreen(shopName: ''),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('₹450'), findsOneWidget);
    await tester.tap(find.text('₹450'));
    await tester.pump();
    expect(find.text('₹450 × 1'), findsOneWidget);
  });
}