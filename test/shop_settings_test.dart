import 'package:flutter_test/flutter_test.dart';
import 'package:simple_billing/features/settings/domain/shop_settings.dart';

void main() {
  test('settings JSON round trip keeps every field', () {
    const settings = ShopSettings(
      shopName: 'My Shop',
      address: 'Main Road 1',
      phone: '9876543210',
      gstin: 'GSTIN123',
      receiptFooter: 'Visit again',
      upiId: 'myshop@upi',
      securityPin: '4321',
      autoCut: false,
      largeMode: true,
      highContrast: true,
      vibration: true,
      buttonSound: false,
      speakTotal: true,
      voiceInput: true,
    );

    final restored = ShopSettings.fromJson(
      (settings.toJson()),
    );

    expect(restored.shopName, 'My Shop');
    expect(restored.address, 'Main Road 1');
    expect(restored.phone, '9876543210');
    expect(restored.gstin, 'GSTIN123');
    expect(restored.receiptFooter, 'Visit again');
    expect(restored.upiId, 'myshop@upi');
    expect(restored.securityPin, '4321');
    expect(restored.autoCut, isFalse);
    expect(restored.largeMode, isTrue);
    expect(restored.highContrast, isTrue);
    expect(restored.vibration, isTrue);
    expect(restored.buttonSound, isFalse);
    expect(restored.speakTotal, isTrue);
    expect(restored.voiceInput, isTrue);
  });

  test('fromJson defaults are safe for missing keys', () {
    final restored = ShopSettings.fromJson(const {});
    expect(restored.largeMode, isFalse);
    expect(restored.highContrast, isFalse);
    expect(restored.vibration, isFalse);
    expect(restored.speakTotal, isFalse);
    expect(restored.voiceInput, isFalse);
    expect(restored.autoCut, isTrue);
  });

  test('copyWith only touches the given fields', () {
    const base = ShopSettings();
    final next = base.copyWith(largeMode: true);
    expect(next.largeMode, isTrue);
    expect(next.highContrast, isFalse);
    expect(next.shopName, '');
    expect(next.receiptFooter, 'Thank you!');
  });
}