import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_billing/core/errors/app_failures.dart';
import 'package:simple_billing/features/billing/data/repositories/bill_repository.dart';
import 'package:simple_billing/features/billing/domain/entities/bill_entities.dart';
import 'package:simple_billing/features/printer/domain/print_encoding.dart';
import 'package:simple_billing/features/printer/domain/receipt_builder.dart';
import 'package:simple_billing/features/printer/domain/thermal_printer_service.dart';
import 'package:simple_billing/features/settings/domain/shop_settings.dart';
import 'package:simple_billing/features/settings/presentation/controllers/settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _SectionHeader('SHOP'),
            _SettingsTile(
              icon: Icons.storefront,
              title: 'Shop details',
              subtitle: 'Name, address, phone, GSTIN, footer',
              onTap: () => _openShopForm(context),
            ),
            _SectionHeader('PAYMENTS'),
            _SettingsTile(
              icon: Icons.qr_code,
              title: 'UPI ID',
              subtitle: 'PIN-protected change',
              onTap: () => _openUpiChange(context),
            ),
            _SettingsTile(
              icon: Icons.lock_outline,
              title: 'Security PIN',
              subtitle: 'Protects UPI settings',
              onTap: () => _openPinChange(context),
            ),
            _SectionHeader('PRINTER'),
            _SettingsTile(
              icon: Icons.print,
              title: 'POS80 / USB printer',
              subtitle: 'Detect, connect, test print, preview',
              onTap: () => _openPrinterSetup(context),
            ),
            _SectionHeader('ACCESSIBILITY'),
            _SwitchTile(
              icon: Icons.zoom_in,
              title: 'Large mode',
              subtitle: 'Bigger text everywhere',
              value: settings.largeMode,
              onChanged: (v) => _save(settings.copyWith(largeMode: v)),
            ),
            _SwitchTile(
              icon: Icons.contrast,
              title: 'High contrast',
              subtitle: 'Black and white, strong colors',
              value: settings.highContrast,
              onChanged: (v) => _save(settings.copyWith(highContrast: v)),
            ),
            _SwitchTile(
              icon: Icons.vibration,
              title: 'Vibration on keys',
              subtitle: 'Light buzz when pressing keys',
              value: settings.vibration,
              onChanged: (v) => _save(settings.copyWith(vibration: v)),
            ),
            _SwitchTile(
              icon: Icons.music_note_outlined,
              title: 'Button sound',
              subtitle: 'Click sound on key press',
              value: settings.buttonSound,
              onChanged: (v) => _save(settings.copyWith(buttonSound: v)),
            ),
            _SwitchTile(
              icon: Icons.volume_up_outlined,
              title: 'Speak total',
              subtitle: 'Speaks the total aloud',
              value: settings.speakTotal,
              onChanged: (v) => _save(settings.copyWith(speakTotal: v)),
            ),
            _SwitchTile(
              icon: Icons.mic_none,
              title: 'Voice input',
              subtitle: 'Enter prices by speaking',
              value: settings.voiceInput,
              onChanged: (v) => _save(settings.copyWith(voiceInput: v)),
            ),
            _SectionHeader('DATA'),
            _SettingsTile(
              icon: Icons.backup_outlined,
              title: 'Backup bills',
              subtitle: 'Save all bills to a file',
              onTap: () => _backup(context),
            ),
            _SettingsTile(
              icon: Icons.restore,
              title: 'Restore bills',
              subtitle: 'Load bills from backup file',
              onTap: () => _restore(context),
            ),
            _SettingsTile(
              icon: Icons.delete_sweep_outlined,
              title: 'Clear history',
              subtitle: 'Delete all saved bills',
              onTap: () => _clearHistory(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(ShopSettings next) =>
      context.read<SettingsController>().save(next);

  void _openShopForm(BuildContext context) {
    final settings = context.read<SettingsController>().settings;
    final name = TextEditingController(text: settings.shopName);
    final address = TextEditingController(text: settings.address);
    final phone = TextEditingController(text: settings.phone);
    final gstin = TextEditingController(text: settings.gstin);
    final footer = TextEditingController(text: settings.receiptFooter);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('SHOP DETAILS'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Shop name'),
              ),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextField(
                controller: gstin,
                decoration: const InputDecoration(labelText: 'GSTIN (optional)'),
              ),
              TextField(
                controller: footer,
                decoration:
                    const InputDecoration(labelText: 'Receipt footer'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              final repo = context.read<SettingsController>();
              await repo.save(settings.copyWith(
                shopName: name.text.trim(),
                address: address.text.trim(),
                phone: phone.text.trim(),
                gstin: gstin.text.trim(),
                receiptFooter: footer.text.trim(),
              ));
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _openUpiChange(BuildContext context) {
    final settings = context.read<SettingsController>().settings;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _PinGateDialog(
        settings: settings,
        onVerified: (verifiedSettings) async {
          if (!dialogContext.mounted) return;
          Navigator.of(dialogContext).pop();
          if (!context.mounted) return;
          _openNewUpiForm(context, verifiedSettings);
        },
      ),
    );
  }

  void _openNewUpiForm(BuildContext context, ShopSettings settings) {
    final controller = TextEditingController(text: settings.upiId);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('UPI ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CURRENT: ${settings.upiId.isEmpty ? 'not set' : settings.upiId}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'NEW UPI ID',
                hintText: 'shopname@upi',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              final repo = context.read<SettingsController>();
              await repo.save(
                settings.copyWith(upiId: controller.text.trim()),
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _openPinChange(BuildContext context) {
    final settings = context.read<SettingsController>().settings;
    final pin = TextEditingController();
    final confirm = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('SECURITY PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'New PIN'),
            ),
            TextField(
              controller: confirm,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Confirm PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              if (pin.text.isEmpty ||
                  pin.text != confirm.text ||
                  pin.text.length < 4) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('PINs must match and be at least 4 digits.'),
                  ),
                );
                return;
              }
              final repo = context.read<SettingsController>();
              await repo.save(
                settings.copyWith(securityPin: pin.text),
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _openPrinterSetup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PrinterSetupScreen()),
    );
  }

  Future<void> _backup(BuildContext context) async {
    try {
      await context.read<SettingsController>().backupBills();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup saved to app documents.')),
      );
    } on AppFailure catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.userMessage)));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final controller = context.read<SettingsController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('RESTORE BILLS?'),
        content: const Text(
            'Current bills will be replaced with the backup contents.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.restoreBills();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bills restored.')));
    } on AppFailure catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.userMessage)));
    }
  }

  Future<void> _clearHistory(BuildContext context) async {
    final repo = context.read<BillRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('CLEAR HISTORY?'),
        content: const Text('All saved bills will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('CLEAR'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await repo.clearAllBills();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('History cleared.')));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        minTileHeight: 64,
        leading: Icon(icon, size: 28),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 14)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        minVerticalPadding: 10,
        secondary: Icon(icon, size: 28),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 14)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

/// Blocks UPI changes until the settings PIN is verified (design.md 12).
class _PinGateDialog extends StatefulWidget {
  const _PinGateDialog({required this.settings, required this.onVerified});

  final ShopSettings settings;
  final ValueChanged<ShopSettings> onVerified;

  @override
  State<_PinGateDialog> createState() => _PinGateDialogState();
}

class _PinGateDialogState extends State<_PinGateDialog> {
  final _pin = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('SECURITY PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Enter PIN',
              errorText: _error,
            ),
            onSubmitted: (_) => _verify(context),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () => _verify(context),
          child: const Text('VERIFY'),
        ),
      ],
    );
  }

  void _verify(BuildContext context) {
    if (widget.settings.hasPin && _pin.text == widget.settings.securityPin) {
      widget.onVerified(widget.settings);
    } else if (!widget.settings.hasPin) {
      _showNoPin(context);
    } else {
      setState(() => _error = 'Incorrect PIN.');
    }
  }

  void _showNoPin(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('NO PIN SET'),
        content: const Text(
            'Set a security PIN first in the SETTINGS > Security PIN screen.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class PrinterSetupScreen extends StatefulWidget {
  const PrinterSetupScreen({super.key});

  @override
  State<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends State<PrinterSetupScreen> {
  List<PrinterDevice> _devices = const [];
  bool _detecting = false;
  bool _connecting = false;
  String? _message;

  Future<void> _detect() async {
    setState(() {
      _detecting = true;
      _message = null;
    });
    try {
      final devices =
          await context.read<ThermalPrinterService>().detect();
      if (!context.mounted) return;
      setState(() {
        _devices = devices;
        _detecting = false;
        if (devices.isEmpty) {
          _message = 'No USB printer detected.\n'
              'Connect the POS80 with a USB OTG cable.';
        }
      });
    } catch (_) {
      if (!context.mounted) return;
      setState(() {
        _detecting = false;
        _message = 'Could not detect USB devices.';
      });
    }
  }

  Future<void> _connect(PrinterDevice device) async {
    setState(() {
      _connecting = true;
      _message = null;
    });
    try {
      await context.read<ThermalPrinterService>().connect(device);
      if (!context.mounted) return;
      setState(() {
        _connecting = false;
        _message = '${device.label} connected.';
      });
    } on AppFailure catch (e) {
      if (!context.mounted) return;
      setState(() {
        _connecting = false;
        _message = e.userMessage;
      });
    } catch (_) {
      if (!context.mounted) return;
      setState(() {
        _connecting = false;
        _message = 'Connection failed.';
      });
    }
  }

  Future<void> _disconnect() async {
    await context.read<ThermalPrinterService>().disconnect();
    if (!context.mounted) return;
    setState(() => _message = 'Printer disconnected.');
  }

  Future<void> _testPrint() async {
    setState(() => _message = null);
    try {
      final shop = context.read<SettingsController>().settings;
      final bytes = ReceiptBuilder(
        width: shop.paperWidthChars,
        encoding: PrintEncoding.fromValue(shop.printerEncoding),
        printLogo: shop.printLogo,
        printBarcode: shop.printBarcode,
      ).build(
        shop: shop,
        bill: _sampleBill(),
        autoCut: false,
      );
      await context.read<ThermalPrinterService>().testPrint(bytes);
      if (!context.mounted) return;
      setState(() => _message = 'Test print sent.');
    } on AppFailure catch (e) {
      if (!context.mounted) return;
      setState(() => _message = e.userMessage);
    } catch (_) {
      if (!context.mounted) return;
      setState(() => _message = 'Could not print.');
    }
  }

  Future<void> _preview() async {
    final shop = context.read<SettingsController>().settings;
    final text = ReceiptTextPreview(width: shop.paperWidthChars).build(
      shop: shop,
      bill: _sampleBill(),
    );
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('RECEIPT PREVIEW'),
        content: SingleChildScrollView(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Bill _sampleBill() {
    final now = DateTime.now();
    return Bill(
      id: 0,
      billNumber: 1,
      createdAt: now,
      subtotal: 550,
      discountAmount: 50,
      total: 500,
      paymentMethod: PaymentMethod.cash,
      paymentStatus: PaymentStatus.paid,
      items: const [
        BillItem(id: 0, billId: 0, itemOrder: 1, price: 100, quantity: 2),
        BillItem(id: 0, billId: 0, itemOrder: 2, price: 350, quantity: 1),
      ],
    );
  }

  String _classLabel(int interfaceClass) => switch (interfaceClass) {
        7 => 'Printer class',
        255 => 'Vendor class',
        2 => 'CDC-ACM',
        10 => 'CDC data',
        _ => 'USB class $interfaceClass',
      };

  Future<void> _save(ShopSettings next) =>
      context.read<SettingsController>().save(next);

  @override
  Widget build(BuildContext context) {
    final printer = context.watch<ThermalPrinterService>();
    final settings = context.watch<SettingsController>().settings;
    final scheme = Theme.of(context).colorScheme;
    final connected = printer.state == PrinterConnectionState.connected;
    final connecting = printer.state == PrinterConnectionState.connecting;
    final device = printer.connectedDevice;

    return Scaffold(
      appBar: AppBar(title: const Text('PRINTER')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.usb),
                title: const Text(
                  'Printer type',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                    'USB OTG direct connection. No Bluetooth, no PC.'),
                trailing: Chip(
                  label: const Text('USB'),
                  backgroundColor: scheme.primaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: connected
                    ? const Color(0xFFE8F5E9)
                    : connecting
                        ? const Color(0xFFFFF8E1)
                        : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    connected
                        ? Icons.check_circle
                        : connecting
                            ? Icons.sync
                            : Icons.error_outline,
                    color: connected
                        ? const Color(0xFF2E7D32)
                        : connecting
                            ? const Color(0xFFF57F17)
                            : scheme.error,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connected
                              ? 'PRINTER CONNECTED'
                              : connecting
                                  ? 'CONNECTING...'
                                  : 'PRINTER NOT CONNECTED',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (connected && device != null)
                          Text(
                            '${device.label}  (${device.vidPid})',
                            style: const TextStyle(fontSize: 14),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _detecting ? null : _detect,
                icon: _detecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.usb),
                label: const Text('SCAN USB PRINTERS'),
              ),
            ),
            const SizedBox(height: 12),
            if (_devices.isNotEmpty)
              ..._devices.map(
                (d) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    minTileHeight: 60,
                    leading: const Icon(Icons.print),
                    title: Text(
                      d.label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'VID:PID ${d.vidPid}  •  ${_classLabel(d.interfaceClass)}'
                      '${d.hasPermission ? '  •  permission OK' : ''}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: connected && device?.deviceId == d.deviceId
                        ? Chip(
                            label: const Text('CONNECTED'),
                            backgroundColor: const Color(0xFFE8F5E9),
                            side: BorderSide.none,
                          )
                        : FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 44),
                            ),
                            onPressed: _connecting ? null : () => _connect(d),
                            child: Text(_connecting ? '...' : 'CONNECT'),
                          ),
                  ),
                ),
              ),
            if (_devices.isEmpty && !_detecting)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No devices yet. Tap "SCAN USB PRINTERS".',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: connected ? _testPrint : null,
                    icon: const Icon(Icons.print),
                    label: const Text('TEST PRINT'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _preview,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('PREVIEW'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: connected ? _disconnect : null,
                    icon: const Icon(Icons.link_off),
                    label: const Text('DISCONNECT'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'PRINTER SETTINGS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: scheme.primary,
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: settings.paperWidthChars,
                      decoration: const InputDecoration(
                        labelText: 'Paper width',
                        border: OutlineInputBorder(),
                      ),
                      items: const [32, 42, 48]
                          .map(
                            (w) => DropdownMenuItem(
                              value: w,
                              child: Text(
                                w == 32
                                    ? '80 mm (32 chars)'
                                    : '80 mm narrow ($w chars)',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => _save(
                        settings.copyWith(paperWidthChars: v ?? 32),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: settings.printerEncoding,
                      decoration: const InputDecoration(
                        labelText: 'Character encoding',
                        border: OutlineInputBorder(),
                      ),
                      items: PrintEncoding.values
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.value,
                              child: Text(e.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => _save(
                        settings.copyWith(printerEncoding: v ?? 'utf8'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      minVerticalPadding: 6,
                      title: const Text(
                        'Auto-cut',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text('Cut paper after every receipt'),
                      value: settings.autoCut,
                      onChanged: (v) => _save(settings.copyWith(autoCut: v)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      minVerticalPadding: 6,
                      title: const Text(
                        'Print logo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text('Large shop name with border lines'),
                      value: settings.printLogo,
                      onChanged: (v) => _save(settings.copyWith(printLogo: v)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      minVerticalPadding: 6,
                      title: const Text(
                        'Print barcode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text('Bill number as CODE128 barcode'),
                      value: settings.printBarcode,
                      onChanged: (v) =>
                          _save(settings.copyWith(printBarcode: v)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}