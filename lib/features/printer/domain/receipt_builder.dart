import 'dart:typed_data';

import 'package:simple_billing/core/constants/app_constants.dart';
import 'package:simple_billing/core/utils/formatters.dart';
import 'package:simple_billing/features/billing/domain/entities/bill_entities.dart';
import 'package:simple_billing/features/printer/domain/esc_pos_service.dart';
import 'package:simple_billing/features/printer/domain/print_encoding.dart';
import 'package:simple_billing/features/settings/domain/shop_settings.dart';

/// Builds the full receipt using the clean [EscPosService] command layer.
///
/// The UI never touches ESC/POS directly (architecture.md section 9).
/// Uses "Rs." on paper because many thermal printer fonts cannot render ₹.
class ReceiptBuilder {
  ReceiptBuilder({
    this.width = AppConstants.receiptPaperWidthChars,
    this.encoding = PrintEncoding.utf8,
    this.printLogo = true,
    this.printBarcode = true,
  });

  final int width;
  final PrintEncoding encoding;
  final bool printLogo;
  final bool printBarcode;

  Uint8List build({
    required ShopSettings shop,
    required Bill bill,
    String? upiPayload,
    bool autoCut = true,
  }) {
    final esc = EscPosService(width: width, encoding: encoding);
    esc.initialize();

    _header(esc, shop);

    esc.setAlign(EscPosAlign.left);
    if (shop.address.isNotEmpty) {
      esc.printText(shop.address);
    }
    if (shop.phone.isNotEmpty) {
      esc.printText('Phone: ${shop.phone}');
    }
    if (shop.gstin.isNotEmpty) {
      esc.printText('GSTIN: ${shop.gstin}');
    }
    esc.feed();

    esc.setBold(true);
    esc.printText('Bill No: ${formatBillNumber(bill.billNumber)}');
    esc.setBold(false);
    esc.printText(formatDateTime(bill.createdAt));
    esc.separator('-');

    esc.setBold(true);
    esc.printRow(left: 'ITEM', middle: 'QTY', right: 'AMOUNT');
    esc.setBold(false);
    for (final item in bill.items) {
      esc.printRow(
        left: _money(item.price),
        middle: '${item.quantity}',
        right: _money(item.lineTotal),
      );
    }
    esc.separator('-');
    esc.setBold(true);
    esc.printRow(left: 'TOTAL', right: _money(bill.total));
    esc.setBold(false);
    if (bill.discountAmount > 0) {
      esc.printRow(left: 'DISCOUNT', right: '-${_money(bill.discountAmount)}');
    }

    esc.feed();
    esc.printText('PAYMENT: ${bill.paymentMethod.label}');
    if (bill.notes != null && bill.notes!.trim().isNotEmpty) {
      esc.printText('Note: ${bill.notes!.trim()}');
    }
    esc.feed();

    if (upiPayload != null && upiPayload.isNotEmpty) {
      esc.setAlign(EscPosAlign.center);
      esc.printQRCode(upiPayload);
      esc.printText('Scan to pay');
      esc.setAlign(EscPosAlign.left);
      esc.feed();
    }

    if (printBarcode && bill.billNumber > 0) {
      esc.setAlign(EscPosAlign.center);
      esc.printBarcode(bill.billNumber.toString().padLeft(6, '0'));
      esc.setAlign(EscPosAlign.left);
    }

    if (shop.receiptFooter.isNotEmpty) {
      esc.setAlign(EscPosAlign.center);
      esc.printText(shop.receiptFooter);
      esc.setAlign(EscPosAlign.left);
    }
    esc.feed();
    esc.feed();
    if (autoCut) {
      esc.cut();
    }
    return esc.takeBytes();
  }

  void _header(EscPosService esc, ShopSettings shop) {
    final name = shop.shopName.isEmpty ? AppConstants.appName : shop.shopName;
    esc.setAlign(EscPosAlign.center);
    if (printLogo) {
      esc.separator('=');
    }
    esc.setBold(true);
    esc.setDoubleHeight(true);
    esc.printText(name);
    esc.setDoubleHeight(false);
    esc.setBold(false);
    if (printLogo) {
      esc.separator('=');
    }
  }

  String _money(int value) => 'Rs.${formatPlainMoney(value)}';
}

/// Text-only preview of the receipt layout, used by the printer settings UI
/// so the user can check formatting without wasting paper.
class ReceiptTextPreview {
  ReceiptTextPreview({this.width = AppConstants.receiptPaperWidthChars});

  final int width;

  String build({
    required ShopSettings shop,
    required Bill bill,
    String? upiPayload,
  }) {
    final lines = <String>[];
    final name = shop.shopName.isEmpty ? AppConstants.appName : shop.shopName;
    lines.add(_center(name));
    lines.add(_center('-' * width));
    if (shop.address.isNotEmpty) lines.add(shop.address);
    if (shop.phone.isNotEmpty) lines.add('Phone: ${shop.phone}');
    if (shop.gstin.isNotEmpty) lines.add('GSTIN: ${shop.gstin}');
    lines.add('');
    lines.add('Bill No: ${formatBillNumber(bill.billNumber)}');
    lines.add(formatDateTime(bill.createdAt));
    lines.add('-' * width);
    lines.add(_row('ITEM', 'QTY', 'AMOUNT'));
    for (final item in bill.items) {
      lines.add(_row(_money(item.price), '${item.quantity}', _money(item.lineTotal)));
    }
    lines.add('-' * width);
    lines.add(_row('TOTAL', '', _money(bill.total)));
    if (bill.discountAmount > 0) {
      lines.add(_row('DISCOUNT', '', '-${_money(bill.discountAmount)}'));
    }
    lines.add('');
    lines.add('PAYMENT: ${bill.paymentMethod.label}');
    if (bill.notes != null && bill.notes!.trim().isNotEmpty) {
      lines.add('Note: ${bill.notes!.trim()}');
    }
    if (upiPayload != null && upiPayload.isNotEmpty) {
      lines.add(_center('[ UPI QR CODE ]'));
      lines.add(_center('Scan to pay'));
    }
    lines.add(_center('[ BARCODE ]'));
    if (shop.receiptFooter.isNotEmpty) {
      lines.add(_center(shop.receiptFooter));
    }
    return lines.join('\n');
  }

  String _money(int value) => 'Rs.${formatPlainMoney(value)}';

  String _center(String text) {
    if (text.length >= width) return text;
    final pad = width - text.length;
    return ' ' * (pad ~/ 2) + text;
  }

  String _row(String left, String middle, String right) {
    final leftWidth = (width * 0.4).floor();
    final rightWidth = (width * 0.32).floor();
    final midWidth = width - leftWidth - rightWidth;
    return _fit(left, leftWidth) +
        _fit(middle, midWidth, center: true) +
        _fit(right, rightWidth, right: true);
  }

  String _fit(String text, int target, {bool right = false, bool center = false}) {
    if (text.length > target) {
      return text.substring(0, target);
    }
    final pad = target - text.length;
    if (right) return ' ' * pad + text;
    if (center) return ' ' * (pad ~/ 2) + text + ' ' * (pad - pad ~/ 2);
    return text + ' ' * pad;
  }
}