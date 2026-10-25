import 'dart:convert';
import 'dart:typed_data';

/// Character encodings supported for ESC/POS text output.
///
/// Most POS80-class printers default to ASCII; accented/box characters come
/// from a code page. CP437 is the classic PC code page on these printers.
enum PrintEncoding {
  utf8('utf8', 'UTF-8'),
  cp437('cp437', 'CP437'),
  latin1('latin1', 'Latin-1');

  const PrintEncoding(this.value, this.label);

  final String value;
  final String label;

  static PrintEncoding fromValue(String? value) =>
      values.firstWhere((e) => e.value == value, orElse: () => utf8);
}

/// Encodes [text] into printer bytes for [encoding]. Unmappable characters
/// become '?' so the printer never stalls on unknown bytes.
Uint8List encodeForPrinter(String text, PrintEncoding encoding) {
  switch (encoding) {
    case PrintEncoding.utf8:
      return Uint8List.fromList(utf8.encode(text));
    case PrintEncoding.cp437:
      final out = BytesBuilder(copy: false);
      for (final char in text.split('')) {
        final code = char.codeUnitAt(0);
        if (code < 0x80) {
          out.addByte(code);
        } else {
          out.addByte(_cp437[code] ?? 0x3F);
        }
      }
      return out.takeBytes();
    case PrintEncoding.latin1:
      final out = BytesBuilder(copy: false);
      for (final char in text.split('')) {
        final code = char.codeUnitAt(0);
        if (code < 0x100) {
          out.addByte(code);
        } else {
          out.addByte(0x3F);
        }
      }
      return out.takeBytes();
  }
}

/// CP437 mappings for the characters most likely to appear on receipts.
const _cp437 = <int, int>{
  0x00C7: 0x80, // Ç
  0x00FC: 0x81, // ü
  0x00E9: 0x82, // é
  0x00E2: 0x83, // â
  0x00E4: 0x84, // ä
  0x00E0: 0x85, // à
  0x00E5: 0x86, // å
  0x00E7: 0x87, // ç
  0x00EA: 0x88, // ê
  0x00EB: 0x89, // ë
  0x00E8: 0x8A, // è
  0x00EF: 0x8B, // ï
  0x00EE: 0x8C, // î
  0x00EC: 0x8D, // ì
  0x00C4: 0x8E, // Ä
  0x00C5: 0x8F, // Å
  0x00C9: 0x90, // É
  0x00E6: 0x91, // æ
  0x00C6: 0x92, // Æ
  0x00F4: 0x93, // ô
  0x00F6: 0x94, // ö
  0x00F2: 0x95, // ò
  0x00FB: 0x96, // û
  0x00F9: 0x97, // ù
  0x00FF: 0x98, // ÿ
  0x00D6: 0x99, // Ö
  0x00DC: 0x9A, // Ü
  0x00A2: 0x9B, // ¢
  0x00A3: 0x9C, // £
  0x00A5: 0x9D, // ¥
  0x00E1: 0xA0, // á
  0x00ED: 0xA1, // í
  0x00F3: 0xA2, // ó
  0x00FA: 0xA3, // ú
  0x00F1: 0xA4, // ñ
  0x00D1: 0xA5, // Ñ
  0x00AA: 0xA6, // ª
  0x00BA: 0xA7, // º
  0x00BF: 0xA8, // ¿
  0x00AC: 0xAA, // ¬
  0x00BD: 0xAB, // ½
  0x00BC: 0xAC, // ¼
  0x00A1: 0xAD, // ¡
  0x00AB: 0xAE, // «
  0x00BB: 0xAF, // »
  0x2500: 0xC4, // ─
  0x2502: 0xB3, // │
  0x250C: 0xDA, // ┌
  0x2510: 0xBF, // ┐
  0x2514: 0xC0, // └
  0x2518: 0xD9, // ┘
  0x253C: 0xC5, // ┼
  0x2550: 0xCD, // ═
  0x2551: 0xBA, // ║
  0x00B0: 0xF8, // °
  0x00B1: 0xF1, // ±
  0x00B7: 0xFA, // ·
  0x00F7: 0xF6, // ÷
  0x2248: 0xF7, // ≈
  0x00B2: 0xFD, // ²
  0x00B5: 0xE6, // µ
  0x00DF: 0xE1, // ß
  0x00D7: 0x78, // × → ASCII x
  0x20AC: 0x63, // € → ASCII c
};