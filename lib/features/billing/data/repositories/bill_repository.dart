import 'package:simple_billing/features/billing/domain/entities/bill_entities.dart';

abstract class BillRepository {
  Future<Bill> saveBill({
    required int billNumber,
    required List<BillItem> items,
    required int discountAmount,
    required PaymentMethod paymentMethod,
    required PaymentStatus paymentStatus,
    String? notes,
  });

  Future<int> getNextBillNumber();

  Future<Bill?> getBillById(int id);

  Future<List<Bill>> getBills({DateTime? from, DateTime? to});

  Future<void> deleteBill(int id);

  Future<void> clearAllBills();

  Future<SalesSummary> getSalesSummary({DateTime? from, DateTime? to});

  Future<List<int>> getRecentPrices();

  Future<void> addRecentPrice(int price);
}

class SalesSummary {
  const SalesSummary({
    required this.totalSales,
    required this.billCount,
    required this.averageBill,
  });

  final int totalSales;
  final int billCount;
  final int averageBill;
}
