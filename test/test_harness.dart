import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:simple_billing/core/theme/app_theme.dart';
import 'package:simple_billing/features/billing/data/repositories/bill_repository.dart';
import 'package:simple_billing/features/billing/domain/entities/bill_entities.dart';
import 'package:simple_billing/features/billing/presentation/controllers/billing_controller.dart';
import 'package:simple_billing/features/printer/domain/thermal_printer_service.dart';
import 'package:simple_billing/features/settings/domain/shop_settings.dart';
import 'package:simple_billing/features/settings/presentation/controllers/settings_controller.dart';
import 'package:simple_billing/shared/services/voice_service.dart';

class FakeBillRepository implements BillRepository {
  final List<Bill> bills = [];
  int _nextId = 1;

  @override
  Future<Bill> saveBill({
    required int billNumber,
    required List<BillItem> items,
    required int discountAmount,
    required PaymentMethod paymentMethod,
    required PaymentStatus paymentStatus,
    String? notes,
  }) async {
    final subtotal = items.fold<int>(0, (s, i) => s + i.lineTotal);
    final bill = Bill(
      id: _nextId++,
      billNumber: billNumber,
      createdAt: DateTime.now(),
      subtotal: subtotal,
      discountAmount: discountAmount,
      total: subtotal - discountAmount,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      notes: notes,
      items: List.of(items),
    );
    bills.add(bill);
    return bill;
  }

  @override
  Future<int> getNextBillNumber() async => bills.isEmpty ? 1 : bills.length + 1;

  @override
  Future<Bill?> getBillById(int id) async {
    for (final b in bills) {
      if (b.id == id) return b;
    }
    return null;
  }

  @override
  Future<List<Bill>> getBills({DateTime? from, DateTime? to}) async =>
      List.of(bills.reversed);

  @override
  Future<void> deleteBill(int id) async => bills.removeWhere((b) => b.id == id);

  @override
  Future<void> clearAllBills() async => bills.clear();

  @override
  Future<SalesSummary> getSalesSummary({DateTime? from, DateTime? to}) async {
    final total = bills.fold<int>(0, (s, b) => s + b.total);
    return SalesSummary(
      totalSales: total,
      billCount: bills.length,
      averageBill: bills.isEmpty ? 0 : total ~/ bills.length,
    );
  }

  final List<int> recentPrices = [];

  @override
  Future<List<int>> getRecentPrices() async => List.of(recentPrices);

  @override
  Future<void> addRecentPrice(int price) async {
    recentPrices.remove(price);
    recentPrices.insert(0, price);
  }
}

class FakeSettingsRepository implements SettingsRepository {
  ShopSettings settings = const ShopSettings();

  @override
  Future<ShopSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(ShopSettings settings) async {
    this.settings = settings;
  }

  @override
  Future<void> backupBills() async {}

  @override
  Future<void> restoreBills() async {}
}

class FakePrinterService extends ChangeNotifier
    implements ThermalPrinterService {
  PrinterConnectionState _state = PrinterConnectionState.disconnected;

  @override
  PrinterConnectionState get state => _state;

  @override
  PrinterDevice? get connectedDevice => null;

  void setState(PrinterConnectionState next) {
    _state = next;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<List<PrinterDevice>> detect() async => const [];

  @override
  Future<void> connect(PrinterDevice device) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> print(Uint8List bytes) async {}

  @override
  Future<void> testPrint(Uint8List bytes) async {}
}

Widget wrapWithProviders({
  required Widget child,
  BillingController? billing,
  FakeBillRepository? bills,
  FakePrinterService? printer,
  bool includeVoice = true,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<BillingController>.value(
        value: billing ?? BillingController(),
      ),
      Provider<BillRepository>.value(value: bills ?? FakeBillRepository()),
      ChangeNotifierProvider<SettingsController>.value(
        value: SettingsController(FakeSettingsRepository()),
      ),
      ChangeNotifierProvider<ThermalPrinterService>.value(
        value: printer ?? FakePrinterService(),
      ),
      if (includeVoice)
        ChangeNotifierProvider<VoiceService>(create: (_) => VoiceService()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}

void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}
