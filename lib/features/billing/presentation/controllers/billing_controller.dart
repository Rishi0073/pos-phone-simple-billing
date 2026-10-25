import 'package:flutter/foundation.dart';
import 'package:simple_billing/core/errors/app_failures.dart';
import 'package:simple_billing/features/billing/domain/entities/bill_entities.dart';
import 'package:simple_billing/features/billing/domain/services/billing_engine.dart';

/// UI-facing state holder for the calculator screen.
class BillingController extends ChangeNotifier {
  BillingController({BillingEngine? engine})
      : _engine = engine ?? BillingEngine();

  final BillingEngine _engine;

  String? _lastError;

  String? get lastError => _lastError;

  CurrentItem get current => _engine.current;

  List<BillItem> get savedItems => _engine.savedItems;

  int get savedCount => _engine.savedCount;

  int get savedTotal => _engine.savedTotal;

  int get grandTotal => _engine.grandTotal;

  bool get canCommit => _engine.canCommit;

  void pressDigit(String digit) {
    _clearError();
    _engine.enterPriceDigit(digit);
    notifyListeners();
  }

  void pressMultiply() {
    _clearError();
    _engine.onMultiply();
    notifyListeners();
  }

  void pressSetPrice(int value) {
    _clearError();
    _engine.setPrice(value);
    notifyListeners();
  }

  void pressNextItem() {
    _clearError();
    try {
      _engine.commitNextItem();
    } on AppFailure catch (e) {
      _lastError = e.userMessage;
    }
    notifyListeners();
  }

  void pressBackspace() {
    _clearError();
    _engine.backspace();
    notifyListeners();
  }

  void pressClear() {
    _clearError();
    _engine.clearCurrent();
    notifyListeners();
  }

  void pressUndo() {
    _clearError();
    _engine.undoLastItem();
    notifyListeners();
  }

  void editItem(int index, {required int price, required int quantity}) {
    _clearError();
    try {
      _engine.updateItem(index, price: price, quantity: quantity);
    } on AppFailure catch (e) {
      _lastError = e.userMessage;
    }
    notifyListeners();
  }

  void removeItem(int index) {
    _clearError();
    _engine.removeItem(index);
    notifyListeners();
  }

  void clearBill() {
    _clearError();
    _engine.clearBill();
    notifyListeners();
  }

  /// Commits the current item automatically when checkout is chosen,
  /// per architecture.md section 6.
  void commitPendingForCheckout() {
    _clearError();
    if (_engine.current.hasInput && _engine.current.isValid) {
      _engine.commitNextItem();
      notifyListeners();
    }
  }

  void _clearError() {
    _lastError = null;
  }
}