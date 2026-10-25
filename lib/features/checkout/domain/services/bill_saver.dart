import 'package:simple_billing/features/billing/data/repositories/bill_repository.dart';
import 'package:simple_billing/features/billing/domain/entities/bill_entities.dart';

/// Saves a completed bill and returns it.
class BillSaver {
  BillSaver(this._repository);

  final BillRepository _repository;

  Future<int> nextBillNumber() => _repository.getNextBillNumber();

  Future<Bill> save({
    required List<BillItem> items,
    required int discountAmount,
    required PaymentMethod paymentMethod,
    required PaymentStatus paymentStatus,
    String? notes,
  }) async {
    final billNumber = await _repository.getNextBillNumber();
    return _repository.saveBill(
      billNumber: billNumber,
      items: items,
      discountAmount: discountAmount,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      notes: notes,
    );
  }
}

class CashChangeCalculator {
  const CashChangeCalculator();

  int change({required int total, required int customerGives}) {
    if (customerGives < total) return 0;
    return customerGives - total;
  }
}