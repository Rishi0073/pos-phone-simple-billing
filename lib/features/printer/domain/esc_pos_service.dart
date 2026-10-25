import 'dart:typed_data';

import 'package:simple_billing/features/printer/domain/print_encoding.dart';

enum EscPosAlign { left, center, right }

/// Clean ESC/POS command layer for 80 mm thermal printers.
///
/// Builds raw printer bytes through named commands; the billing/UI code never
/// touches ESC/POS directly (architecture.md section 9).
class EscPosService {
  EscPosService({this.width = 32, this.encoding = PrintEncoding.utf8});

  /// Column width in characters (80 mm printers use 32 at the default font).
  final int width;
  final PrintEncoding encoding;

  final BytesBuilder _b = BytesBuilder(copy: false);

  static const _init = [0x1B, 0x40];
  static const _alignLeft = [0x1B, 0x61, 0x00];
  static const _alignCenter = [0x1B, 0x61, 0x01];
  static const _alignRight = [0x1B, 0x61, 0x02];
  static const _boldOn = [0x1B, 0x45, 0x01];
  static const _boldOff = [0x1B, 0x45, 0x00];
  static const _doubleOn = [0x1D, 0x21, 0x11];
  static const _doubleOff = [0x1D, 0x21, 0x00];
  static const _feedLine = [0x0A];
  static const _cut = [0x1D, 0x56, 0x00];
  static const _barcodeHeight = [0x1D, 0x68, 0x3C];
  static const _barcodeWidth = [0x1D, 0x77, 0x02];
  static const _qrModel = [0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00];
  static const _qrError = [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x48];

  void initialize() => _push(_init);

  void setAlign(EscPosAlign align) {
    _push(switch (align) {
      EscPosAlign.left => _alignLeft,
      EscPosAlign.center => _alignCenter,
      EscPosAlign.right => _alignRight,
    });
  }

  void setBold(bool on) => _push(on ? _boldOn : _boldOff);

  void setDoubleHeight(bool on) => _push(on ? _doubleOn : _doubleOff);

  /// Prints [text] with a trailing line feed.
  void printText(String text) {
    _b.add(encodeForPrinter(text, encoding));
    _push(_feedLine);
  }

  /// Prints [text] without a line feed (for low-level sequences).
  void printRaw(String text) {
    _b.add(encodeForPrinter(text, encoding));
  }

  /// Prints a full-width separator line.
  void separator([String char = '-']) {
    printText(List.filled(width, char).join());
  }

  /// Three-column row; [middle] and [right] are right-aligned by default.
  void printRow({
    required String left,
    String middle = '',
    required String right,
  }) {
    final leftWidth = (width * 0.4).floor();
    final rightWidth = (width * 0.32).floor();
    final midWidth = width - leftWidth - rightWidth;
    final parts = StringBuffer();
    parts.write(_fit(left, leftWidth, align: EscPosAlign.left));
    parts.write(_fit(middle, midWidth, align: EscPosAlign.center));
    parts.write(_fit(right, rightWidth, align: EscPosAlign.right));
    printText(parts.toString());
  }

  void printQRCode(String data, {int size = 8}) {
    _push(_qrModel);
    _push([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, size]);
    _push(_qrError);
    final payload = encodeForPrinter(data, encoding);
    final length = payload.length + 3;
    final pL = length & 0xFF;
    final pH = (length >> 8) & 0xFF;
    _push([0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30]);
    _b.add(payload);
    _push([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
    feed();
  }

  /// CODE128 barcode (GS k 73 with 2-byte length), used by most POS80 printers.
  void printBarcode(String data) {
    final payload = encodeForPrinter(data, encoding);
    if (payload.isEmpty) return;
    _push(_barcodeHeight);
    _push(_barcodeWidth);
    _push([0x1D, 0x6B, 0x49, payload.length & 0xFF, (payload.length >> 8) & 0xFF]);
    _b.add(payload);
    feed();
  }

  void feed([int lines = 1]) {
    for (var i = 0; i < lines; i++) {
      _push(_feedLine);
    }
  }

  void cut() => _push(_cut);

  Uint8List takeBytes() => _b.takeBytes();

  void _push(List<int> bytes) => _b.add(bytes);

  String _fit(String text, int target, {required EscPosAlign align}) {
    final visible = _visibleWidth(text);
    if (visible > target) {
      final cut = text.substring(0, text.length - (visible - target));
      return _fit(cut, target, align: align);
    }
    final pad = target - visible;
    return switch (align) {
      EscPosAlign.left => text + ' ' * pad,
      EscPosAlign.right => ' ' * pad + text,
      EscPosAlign.center => ' ' * (pad ~/ 2) + text + ' ' * (pad - pad ~/ 2),
    };
  }

  int _visibleWidth(String text) {
    var w = 0;
    for (final char in text.split('')) {
      w += encodeForPrinter(char, encoding).length;
    }
    return w;
  }
}