import 'package:flutter_test/flutter_test.dart';
import 'package:simple_billing/core/errors/app_failures.dart';
import 'package:simple_billing/features/billing/domain/services/billing_engine.dart';

void main() {
  group('price entry', () {
    test('300 -> 300 x 1', () {
      final e = BillingEngine();
      for (final d in '300'.split('')) {
        e.enterPriceDigit(d);
      }
      expect(e.current.price, 300);
      expect(e.current.effectiveQuantity, 1);
      expect(e.current.lineTotal, 300);
      expect(e.grandTotal, 300);
    });

    test('ignores non-digit input', () {
      final e = BillingEngine();
      e.enterPriceDigit('a');
      e.enterPriceDigit('+');
      expect(e.current.price, 0);
    });
  });

  group('quantity entry', () {
    test('500 x 4 -> 2000', () {
      final e = BillingEngine();
      for (final d in '500'.split('')) {
        e.enterPriceDigit(d);
      }
      e.onMultiply();
      for (final d in '4'.split('')) {
        e.enterQuantityDigit(d);
      }
      expect(e.current.price, 500);
      expect(e.current.quantity, 4);
      expect(e.current.lineTotal, 2000);
      expect(e.grandTotal, 2000);
    });
  });

  group('+ NEXT ITEM behavior', () {
    test('500 x 4 + 300 x 4 -> two items, total 3200', () {
      final e = BillingEngine();
      for (final d in '500'.split('')) {
        e.enterPriceDigit(d);
      }
      e.onMultiply();
      e.enterQuantityDigit('4');
      e.commitNextItem();

      for (final d in '300'.split('')) {
        e.enterPriceDigit(d);
      }
      e.onMultiply();
      e.enterQuantityDigit('4');

      expect(e.savedItems.length, 1);
      expect(e.savedItems.first.price, 500);
      expect(e.savedItems.first.quantity, 4);
      expect(e.savedTotal, 2000);
      expect(e.grandTotal, 3200);
      expect(e.current.price, 300);
    });

    test('+ clears current item to a blank next item', () {
      final e = BillingEngine();
      e.enterPriceDigit('5');
      e.enterPriceDigit('0');
      e.commitNextItem();
      expect(e.current.price, 0);
      expect(e.current.effectiveQuantity, 1);
      expect(e.current.hasInput, isFalse);
      expect(e.savedCount, 1);
    });

    test('50 x 3 + 100 x 2 -> two items, total 350', () {
      final e = BillingEngine();
      for (final d in '50'.split('')) {
        e.enterPriceDigit(d);
      }
      e.onMultiply();
      e.enterQuantityDigit('3');
      e.commitNextItem();

      for (final d in '100'.split('')) {
        e.enterPriceDigit(d);
      }
      e.onMultiply();
      e.enterQuantityDigit('2');
      e.commitNextItem();

      expect(e.savedCount, 2);
      expect(e.savedTotal, 350);
      expect(e.grandTotal, 350);
    });

    test('committing empty current item is a no-op', () {
      final e = BillingEngine();
      e.commitNextItem();
      expect(e.savedCount, 0);
    });
  });

  group('edit / remove', () {
    test('updateItem changes price and quantity', () {
      final e = BillingEngine();
      e.enterPriceDigit('5');
      e.enterPriceDigit('0');
      e.commitNextItem();
      e.updateItem(0, price: 100, quantity: 2);
      expect(e.savedItems.first.price, 100);
      expect(e.savedItems.first.quantity, 2);
      expect(e.savedTotal, 200);
    });

    test('updateItem rejects invalid values', () {
      final e = BillingEngine();
      e.enterPriceDigit('5');
      e.commitNextItem();
      expect(() => e.updateItem(0, price: 5, quantity: 0),
          throwsA(isA<InvalidQuantity>()));
    });

    test('removeItem renumbers the remaining rows', () {
      final e = BillingEngine();
      for (var i = 0; i < 3; i++) {
        e.enterPriceDigit('1');
        e.commitNextItem();
      }
      e.removeItem(0);
      expect(e.savedItems.length, 2);
      expect(e.savedItems[0].itemOrder, 1);
      expect(e.savedItems[1].itemOrder, 2);
    });
  });

  group('backspace / clear', () {
    test('backspace removes last price digit', () {
      final e = BillingEngine();
      for (final d in '123'.split('')) {
        e.enterPriceDigit(d);
      }
      e.backspace();
      expect(e.current.price, 12);
    });

    test('backspace removes last quantity digit when quantity > 1', () {
      final e = BillingEngine();
      e.enterPriceDigit('5');
      e.onMultiply();
      e.enterQuantityDigit('4');
      e.enterQuantityDigit('2');
      e.backspace();
      expect(e.current.quantity, 4);
      expect(e.current.price, 5);
    });

    test('clearCurrent resets to blank', () {
      final e = BillingEngine();
      e.enterPriceDigit('5');
      e.onMultiply();
      e.enterQuantityDigit('4');
      e.clearCurrent();
      expect(e.current.price, 0);
      expect(e.current.quantity, 0);
      expect(e.current.effectiveQuantity, 1);
    });

    test('clearBill removes all saved items', () {
      final e = BillingEngine();
      e.enterPriceDigit('5');
      e.commitNextItem();
      e.enterPriceDigit('3');
      e.commitNextItem();
      e.clearBill();
      expect(e.savedCount, 0);
      expect(e.grandTotal, 0);
    });
  });

  group('totals', () {
    test('current uncommitted item is not double counted', () {
      final e = BillingEngine();
      e.enterPriceDigit('1');
      e.commitNextItem();
      e.enterPriceDigit('2');
      e.enterPriceDigit('0');
      expect(e.savedTotal, 1);
      expect(e.grandTotal, 21);
    });
  });

  group('setPrice (voice / recent prices)', () {
    test('sets the price directly', () {
      final e = BillingEngine();
      e.setPrice(450);
      expect(e.current.price, 450);
      expect(e.current.quantity, 0);
      expect(e.current.effectiveQuantity, 1);
    });

    test('rejects negative and oversized values', () {
      final e = BillingEngine();
      e.setPrice(-5);
      e.setPrice(1000000000);
      expect(e.current.price, 0);
    });
  });

  group('undo last item', () {
    test('removes the last committed item and restores it', () {
      final e = BillingEngine();
      e.enterPriceDigit('5');
      e.commitNextItem();
      e.enterPriceDigit('2');
      e.commitNextItem();
      expect(e.savedCount, 2);

      e.undoLastItem();
      expect(e.savedCount, 1);
      expect(e.current.price, 2);
      expect(e.current.effectiveQuantity, 1);
    });

    test('does not clobber a partially typed item', () {
      final e = BillingEngine();
      e.enterPriceDigit('5');
      e.commitNextItem();
      e.enterPriceDigit('9');
      e.undoLastItem();
      expect(e.savedCount, 0);
      expect(e.current.price, 9);
    });

    test('is a no-op on an empty bill', () {
      final e = BillingEngine();
      e.undoLastItem();
      expect(e.savedCount, 0);
      expect(e.current.price, 0);
    });
  });
}