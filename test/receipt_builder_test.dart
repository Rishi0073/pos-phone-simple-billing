import 'package:flutter_test/flutter_test.dart';
import 'package:simple_billing/features/billing/domain/entities/bill_entities.dart';
import 'package:simple_billing/features/printer/domain/receipt_builder.dart';
import 'package:simple_billing/features/settings/domain/shop_settings.dart';

void main() {
  const shop = ShopSettings(
    shopName: 'Test Shop',
    address: 'Main Road',
    phone: '1234567890',
    gstin: 'GST123',
    receiptFooter: 'Thank you!',
  );

  final bill = Bill(
    id: 1,
    billNumber: 123,
    createdAt: DateTime(2026, 8, 17, 10, 30),
    subtotal: 3400,
    discountAmount: 0,
    total: 3400,
    paymentMethod: PaymentMethod.upi,
    paymentStatus: PaymentStatus.paid,
    items: const [
      BillItem(id: 1, billId: 1, itemOrder: 1, price: 500, quantity: 4),
      BillItem(id: 2, billId: 1, itemOrder: 2, price: 300, quantity: 4),
      BillItem(id: 3, billId: 1, itemOrder: 3, price: 100, quantity: 2),
    ],
  );

  test('starts with ESC/POS init and ends with a cut command', () {
    final bytes = ReceiptBuilder().build(shop: shop, bill: bill);
    expect(bytes.sublist(0, 2), [0x1B, 0x40]);
    expect(bytes.sublist(bytes.length - 3), [0x1D, 0x56, 0x00]);
  });

  test('contains shop name, bill number, total and payment method', () {
    final raw = String.fromCharCodes(
      ReceiptBuilder().build(shop: shop, bill: bill),
    );
    expect(raw, contains('Test Shop'));
    expect(raw, contains('Bill No: 000123'));
    expect(raw, contains('Rs.3,400'));
    expect(raw, contains('UPI'));
  });

  test('rows never exceed the 32-column width', () {
    final bytes = ReceiptBuilder().build(shop: shop, bill: bill);
    final tooLong = <String>[];
    var line = StringBuffer();
    var inCommand = false;
    for (final b in bytes) {
      if (b == 0x1B || b == 0x1D) {
        inCommand = true;
        continue;
      }
      if (inCommand) {
        if (b == 0x0A) inCommand = false;
        continue;
      }
      if (b == 0x0A) {
        if (line.length > 32) tooLong.add(line.toString());
        line = StringBuffer();
        continue;
      }
      line.writeCharCode(b);
    }
    expect(tooLong, isEmpty, reason: 'Too long: $tooLong');
  });

  test('no cut command when autoCut is disabled', () {
    final bytes = ReceiptBuilder()
        .build(shop: shop, bill: bill, autoCut: false)
        ;
    expect(bytes, isNot(contains([0x1D, 0x56, 0x00])));
  });

  test('embeds QR payload bytes when provided', () {
    final bytes = ReceiptBuilder()
        .build(shop: shop, bill: bill, upiPayload: 'upi://pay?am=3400')
        ;
    const model = [0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00];
    var found = false;
    for (var i = 0; i <= bytes.length - model.length; i++) {
      if (bytes.sublist(i, i + model.length).join(',') == model.join(',')) {
        found = true;
        break;
      }
    }
    expect(found, isTrue, reason: 'QR model sequence missing');
  });
}
