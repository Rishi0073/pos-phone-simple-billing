import 'package:flutter/foundation.dart';
import 'package:simple_billing/features/settings/domain/shop_settings.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._repository);

  final SettingsRepository _repository;

  ShopSettings _settings = const ShopSettings();

  ShopSettings get settings => _settings;

  Future<void> load() async {
    _settings = await _repository.loadSettings();
    notifyListeners();
  }

  Future<void> save(ShopSettings settings) async {
    await _repository.saveSettings(settings);
    _settings = settings;
    notifyListeners();
  }

  Future<void> backupBills() => _repository.backupBills();

  Future<void> restoreBills() => _repository.restoreBills();
}