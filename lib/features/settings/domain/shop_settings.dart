import 'dart:convert';

import 'package:simple_billing/core/constants/app_constants.dart';

class ShopSettings {
  const ShopSettings({
    this.shopName = '',
    this.address = '',
    this.phone = '',
    this.gstin = '',
    this.receiptFooter = 'Thank you!',
    this.upiId = '',
    this.securityPin = '',
    this.autoCut = true,
    this.printerEncoding = 'utf8',
    this.printLogo = true,
    this.printBarcode = true,
    this.paperWidthChars = AppConstants.receiptPaperWidthChars,
    this.largeMode = false,
    this.highContrast = false,
    this.vibration = false,
    this.buttonSound = false,
    this.speakTotal = false,
    this.voiceInput = false,
  });

  final String shopName;
  final String address;
  final String phone;
  final String gstin;
  final String receiptFooter;
  final String upiId;
  final String securityPin;
  final bool autoCut;

  // Printer settings (POS80 USB ESC/POS).
  final String printerEncoding;
  final bool printLogo;
  final bool printBarcode;
  final int paperWidthChars;

  // Accessibility (PRD section 15).
  final bool largeMode;
  final bool highContrast;
  final bool vibration;
  final bool buttonSound;
  final bool speakTotal;
  final bool voiceInput;

  bool get hasPin => securityPin.isNotEmpty;

  bool get hasUpiId => upiId.isNotEmpty;

  ShopSettings copyWith({
    String? shopName,
    String? address,
    String? phone,
    String? gstin,
    String? receiptFooter,
    String? upiId,
    String? securityPin,
    bool? autoCut,
    String? printerEncoding,
    bool? printLogo,
    bool? printBarcode,
    int? paperWidthChars,
    bool? largeMode,
    bool? highContrast,
    bool? vibration,
    bool? buttonSound,
    bool? speakTotal,
    bool? voiceInput,
  }) {
    return ShopSettings(
      shopName: shopName ?? this.shopName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      gstin: gstin ?? this.gstin,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      upiId: upiId ?? this.upiId,
      securityPin: securityPin ?? this.securityPin,
      autoCut: autoCut ?? this.autoCut,
      printerEncoding: printerEncoding ?? this.printerEncoding,
      printLogo: printLogo ?? this.printLogo,
      printBarcode: printBarcode ?? this.printBarcode,
      paperWidthChars: paperWidthChars ?? this.paperWidthChars,
      largeMode: largeMode ?? this.largeMode,
      highContrast: highContrast ?? this.highContrast,
      vibration: vibration ?? this.vibration,
      buttonSound: buttonSound ?? this.buttonSound,
      speakTotal: speakTotal ?? this.speakTotal,
      voiceInput: voiceInput ?? this.voiceInput,
    );
  }

  Map<String, dynamic> toJson() => {
        'shopName': shopName,
        'address': address,
        'phone': phone,
        'gstin': gstin,
        'receiptFooter': receiptFooter,
        'upiId': upiId,
        'securityPin': securityPin,
        'autoCut': autoCut,
        'printerEncoding': printerEncoding,
        'printLogo': printLogo,
        'printBarcode': printBarcode,
        'paperWidthChars': paperWidthChars,
        'largeMode': largeMode,
        'highContrast': highContrast,
        'vibration': vibration,
        'buttonSound': buttonSound,
        'speakTotal': speakTotal,
        'voiceInput': voiceInput,
      };

  factory ShopSettings.fromJson(Map<String, dynamic> json) => ShopSettings(
        shopName: json['shopName'] as String? ?? '',
        address: json['address'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        gstin: json['gstin'] as String? ?? '',
        receiptFooter: json['receiptFooter'] as String? ?? 'Thank you!',
        upiId: json['upiId'] as String? ?? '',
        securityPin: json['securityPin'] as String? ?? '',
        autoCut: json['autoCut'] as bool? ?? true,
        printerEncoding: json['printerEncoding'] as String? ?? 'utf8',
        printLogo: json['printLogo'] as bool? ?? true,
        printBarcode: json['printBarcode'] as bool? ?? true,
        paperWidthChars: json['paperWidthChars'] as int? ??
            AppConstants.receiptPaperWidthChars,
        largeMode: json['largeMode'] as bool? ?? false,
        highContrast: json['highContrast'] as bool? ?? false,
        vibration: json['vibration'] as bool? ?? false,
        buttonSound: json['buttonSound'] as bool? ?? false,
        speakTotal: json['speakTotal'] as bool? ?? false,
        voiceInput: json['voiceInput'] as bool? ?? false,
      );

  String toJsonString() => jsonEncode(toJson());
}

abstract class SettingsRepository {
  Future<ShopSettings> loadSettings();

  Future<void> saveSettings(ShopSettings settings);

  Future<void> backupBills();

  Future<void> restoreBills();
}
