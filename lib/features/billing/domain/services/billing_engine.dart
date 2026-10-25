import 'package:simple_billing/core/errors/app_failures.dart';
import 'package:simple_billing/features/billing/domain/entities/bill_entities.dart';

/// Pure, widget-free billing logic.
///
/// State separation (architecture.md section 4):
///  - [current]: the item being typed right now, never automatically saved.
///  - [savedItems]: committed items added with "+ NEXT ITEM".
class BillingEngine {
  BillingEngine({
    this.current = const CurrentItem(price: 0, quantity: 0),
    List<BillItem>? savedItems,
  }) : _savedItems = List.of(savedItems ?? const []);

  CurrentItem current;
  final List<BillItem> _savedItems;

  List<BillItem> get savedItems => List.unmodifiable(_savedItems);

  int get savedCount => _savedItems.length;

  int get savedTotal =>
      _savedItems.fold(0, (sum, item) => sum + item.lineTotal);

  int get grandTotal => savedTotal + (current.hasInput ? current.lineTotal : 0);

  bool get hasSavedItems => _savedItems.isNotEmpty;

  bool get canCommit => current.hasInput && current.isValid;

  /// Appends a digit to the price while it is being typed.
  /// Digits typed after "×" go to the quantity instead.
  void enterPriceDigit(String digit) {
    if (!RegExp(r'^[0-9]$').hasMatch(digit)) return;
    if (current.quantityMode) {
      enterQuantityDigit(digit);
      return;
    }
    if (current.price.toString().length >= 9) return;
    current = CurrentItem(
      price: current.price * 10 + int.parse(digit),
      quantity: current.quantity,
    );
  }

  /// Sets the price directly (voice input, recent-price chips).
  void setPrice(int value) {
    if (value < 0 || value > 999999999) return;
    current = CurrentItem(price: value, quantity: 0);
  }

  /// "×" behavior: switch into quantity-entry mode for the current price.
  void onMultiply() {
    if (!current.hasInput) return;
    if (current.quantityTyped) return;
    current = CurrentItem(
      price: current.price,
      quantity: current.quantity,
      quantityMode: true,
    );
  }

  /// Appends a digit to the quantity.
  void enterQuantityDigit(String digit) {
    if (!RegExp(r'^[0-9]$').hasMatch(digit)) return;
    if (current.quantity.toString().length >= 4) return;
    current = CurrentItem(
      price: current.price,
      quantity: current.quantity * 10 + int.parse(digit),
      quantityMode: true,
    );
  }

  /// "+ NEXT ITEM": validate, commit the current item, start blank next.
  /// Throws [InvalidPrice] / [InvalidQuantity] if the current item is bad.
  void commitNextItem() {
    if (!current.hasInput) return;
    final item = current.toBillItem(itemOrder: _savedItems.length + 1);
    _savedItems.add(item);
    current = const CurrentItem(price: 0, quantity: 0);
  }

  /// Removes the most recently committed item, for accidental "+ NEXT ITEM".
  /// The removed item becomes the current item again so nothing is lost.
  void undoLastItem() {
    if (_savedItems.isEmpty) return;
    final removed = _savedItems.removeLast();
    _renumber();
    if (!current.hasInput) {
      current = CurrentItem(price: removed.price, quantity: removed.quantity);
    }
  }

  void backspace() {
    if (current.quantityTyped) {
      current = CurrentItem(
        price: current.price,
        quantity: current.quantity ~/ 10,
        quantityMode: current.quantity ~/ 10 > 0,
      );
    } else if (current.quantityMode) {
      current = CurrentItem(
        price: current.price,
        quantity: current.quantity,
        quantityMode: false,
      );
    } else {
      current = CurrentItem(
        price: current.price ~/ 10,
        quantity: current.quantity,
      );
    }
  }

  void clearCurrent() {
    current = const CurrentItem(price: 0, quantity: 0);
  }

  void removeItem(int index) {
    if (index < 0 || index >= _savedItems.length) return;
    _savedItems.removeAt(index);
    _renumber();
  }

  void updateItem(
    int index, {
    required int price,
    required int quantity,
  }) {
    if (index < 0 || index >= _savedItems.length) return;
    if (price < 0) throw const InvalidPrice();
    if (quantity <= 0) throw const InvalidQuantity();
    _savedItems[index] = BillItem(
      id: _savedItems[index].id,
      billId: _savedItems[index].billId,
      itemOrder: _savedItems[index].itemOrder,
      price: price,
      quantity: quantity,
    );
  }

  void clearBill() {
    _savedItems.clear();
    clearCurrent();
  }

  List<BillItem> takeSavedItems() => List.of(_savedItems);

  void _renumber() {
    for (var i = 0; i < _savedItems.length; i++) {
      final item = _savedItems[i];
      _savedItems[i] = item.copyWith(itemOrder: i + 1);
    }
  }
}

/// A running typed amount for cash-entry style inputs (customer gives).
class AmountBuilder {
  AmountBuilder();

  int _value = 0;

  int get value => _value;

  bool get isEmpty => _value == 0;

  void addDigit(String digit) {
    if (!RegExp(r'^[0-9]$').hasMatch(digit)) return;
    if (_value.toString().length >= 9) return;
    _value = _value * 10 + int.parse(digit);
  }

  void backspace() {
    _value = _value ~/ 10;
  }

  void clear() {
    _value = 0;
  }
}