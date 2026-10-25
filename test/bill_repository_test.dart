import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:simple_billing/features/billing/data/repositories/sqflite_repositories.dart';
import 'package:simple_billing/features/billing/domain/entities/bill_entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late SqfliteBillRepository repo;

  setUp(() async {
    db = AppDatabase.instance;
    final database = await db.database;
    await database.delete('bill_items');
    await database.delete('bills');
    await database.delete('recent_prices');
  });

  tearDown(() async {
    await db.close();
  });

  test('saves a bill and reads it back with items', () async {
    repo = SqfliteBillRepository(db);
    final saved = await repo.saveBill(
      billNumber: 1,
      items: const [
        BillItem(id: null, billId: null, itemOrder: 1, price: 500, quantity: 4),
        BillItem(id: null, billId: null, itemOrder: 2, price: 300, quantity: 4),
      ],
      discountAmount: 0,
      paymentMethod: PaymentMethod.cash,
      paymentStatus: PaymentStatus.paid,
    );

    expect(saved.billNumber, 1);
    expect(saved.subtotal, 3200);
    expect(saved.total, 3200);

    final loaded = await repo.getBillById(saved.id);
    expect(loaded, isNotNull);
    expect(loaded!.items.length, 2);
    expect(loaded.items.first.price, 500);
    expect(loaded.items.first.quantity, 4);
    expect(loaded.total, 3200);
  });

  test('next bill number increments', () async {
    repo = SqfliteBillRepository(db);
    expect(await repo.getNextBillNumber(), 1);
    await repo.saveBill(
      billNumber: 1,
      items: const [
        BillItem(id: null, billId: null, itemOrder: 1, price: 10, quantity: 1),
      ],
      discountAmount: 0,
      paymentMethod: PaymentMethod.upi,
      paymentStatus: PaymentStatus.paid,
    );
    expect(await repo.getNextBillNumber(), 2);
  });

  test('sales summary aggregates totals', () async {
    repo = SqfliteBillRepository(db);
    await repo.saveBill(
      billNumber: 1,
      items: const [
        BillItem(id: null, billId: null, itemOrder: 1, price: 100, quantity: 1),
      ],
      discountAmount: 0,
      paymentMethod: PaymentMethod.cash,
      paymentStatus: PaymentStatus.paid,
    );
    await repo.saveBill(
      billNumber: 2,
      items: const [
        BillItem(id: null, billId: null, itemOrder: 1, price: 200, quantity: 1),
      ],
      discountAmount: 0,
      paymentMethod: PaymentMethod.cash,
      paymentStatus: PaymentStatus.paid,
    );

    final summary = await repo.getSalesSummary();
    expect(summary.totalSales, 300);
    expect(summary.billCount, 2);
    expect(summary.averageBill, 150);
  });

  test('recent prices are unique and newest first', () async {
    repo = SqfliteBillRepository(db);
    await repo.addRecentPrice(500);
    await repo.addRecentPrice(300);
    await repo.addRecentPrice(500);
    await repo.addRecentPrice(100);
    expect(await repo.getRecentPrices(), [100, 300, 500]);
  });
}