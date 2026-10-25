import 'dart:convert';

import 'package:simple_billing/features/billing/domain/entities/bill_entities.dart';

class UpiService {
  const UpiService();

  /// Builds a UPI deep-link payment URI carrying the exact amount.
  /// https://www.npci.org.in/what-we-do/upi/deep-link/docs
  String buildPaymentUri({
    required String upiId,
    required String merchantName,
    required int amount,
    required String billReference,
    String? note,
  }) {
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upiId,
        'pn': merchantName,
        'am': amount.toString(),
        'tn': note ?? 'Bill $billReference',
        'cu': 'INR',
        'tr': billReference,
      },
    );
    return uri.toString();
  }

  /// Payload expected inside the QR. Keep it a plain UPI URI.
  String generateQrPayload({required String paymentUri}) => paymentUri;
}

class UpiQrCode {
  const UpiQrCode({required this.payload, required this.amount});

  final String payload;
  final int amount;

  Map<String, dynamic> toJson() => {'payload': payload, 'amount': amount};
}

Bill billFromJson(Map<String, dynamic> json) {
  return Bill(
    id: json['id'] as int,
    billNumber: json['billNumber'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    subtotal: json['subtotal'] as int,
    discountAmount: json['discountAmount'] as int? ?? 0,
    total: json['total'] as int,
    paymentMethod: PaymentMethod.values.byName(json['paymentMethod'] as String),
    paymentStatus: PaymentStatus.values.byName(json['paymentStatus'] as String),
    notes: json['notes'] as String?,
    items: (json['items'] as List<dynamic>? ?? const [])
        .map((e) => BillItem(
              id: e['id'] as int?,
              billId: e['billId'] as int?,
              itemOrder: e['itemOrder'] as int,
              price: e['price'] as int,
              quantity: e['quantity'] as int,
            ))
        .toList(),
  );
}

String encodeBill(Bill bill) => jsonEncode({
      'id': bill.id,
      'billNumber': bill.billNumber,
      'createdAt': bill.createdAt.toIso8601String(),
      'subtotal': bill.subtotal,
      'discountAmount': bill.discountAmount,
      'total': bill.total,
      'paymentMethod': bill.paymentMethod.name,
      'paymentStatus': bill.paymentStatus.name,
      'notes': bill.notes,
      'items': bill.items
          .map((i) => {
                'id': i.id,
                'billId': i.billId,
                'itemOrder': i.itemOrder,
                'price': i.price,
                'quantity': i.quantity,
              })
          .toList(),
    });