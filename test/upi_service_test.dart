import 'package:flutter_test/flutter_test.dart';
import 'package:simple_billing/features/upi/domain/services/upi_service.dart';

void main() {
  const service = UpiService();

  test('builds a UPI URI with exact amount', () {
    final uri = service.buildPaymentUri(
      upiId: 'shopname@upi',
      merchantName: 'My Shop',
      amount: 3400,
      billReference: '000123',
    );
    expect(uri, startsWith('upi://pay?'));
    expect(uri, contains('pa=shopname%40upi'));
    expect(uri, contains('pn=My+Shop'));
    expect(uri, contains('am=3400'));
    expect(uri, contains('cu=INR'));
    expect(uri, contains('tr=000123'));
  });

  test('QR payload equals the payment URI', () {
    const paymentUri = 'upi://pay?pa=shopname%40upi&am=100';
    expect(service.generateQrPayload(paymentUri: paymentUri), paymentUri);
  });
}