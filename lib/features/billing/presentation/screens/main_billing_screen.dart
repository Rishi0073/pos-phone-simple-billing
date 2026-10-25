import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:simple_billing/core/constants/app_constants.dart';
import 'package:simple_billing/core/utils/formatters.dart';
import 'package:simple_billing/features/billing/data/repositories/bill_repository.dart';
import 'package:simple_billing/features/billing/presentation/controllers/billing_controller.dart';
import 'package:simple_billing/features/billing/presentation/widgets/keypad.dart';
import 'package:simple_billing/features/printer/domain/thermal_printer_service.dart';
import 'package:simple_billing/features/settings/presentation/controllers/settings_controller.dart';
import 'package:simple_billing/shared/services/voice_service.dart';

class MainBillingScreen extends StatefulWidget {
  const MainBillingScreen({super.key, required this.shopName});

  final String shopName;

  @override
  State<MainBillingScreen> createState() => _MainBillingScreenState();
}

class _MainBillingScreenState extends State<MainBillingScreen> {
  List<int> _recentPrices = const [];

  @override
  void initState() {
    super.initState();
    _loadRecentPrices();
  }

  Future<void> _loadRecentPrices() async {
    final prices = await context.read<BillRepository>().getRecentPrices();
    if (!mounted) return;
    setState(() => _recentPrices = prices);
  }

  /// Optional vibration / click sound for every key press (PRD 15).
  void _feedback() {
    final settings = context.read<SettingsController>().settings;
    if (settings.vibration) {
      HapticFeedback.lightImpact();
    }
    if (settings.buttonSound) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  void _onNextItem() {
    _feedback();
    final controller = context.read<BillingController>();
    final price = controller.current.price;
    controller.pressNextItem();
    if (price > 0) {
      context.read<BillRepository>().addRecentPrice(price);
      _loadRecentPrices();
    }
  }

  void _onClear() {
    _feedback();
    final controller = context.read<BillingController>();
    if (controller.savedItems.isEmpty) {
      controller.pressClear();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('CLEAR ALL ITEMS?'),
        content: Text(
          '${controller.savedCount} saved item(s) will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              controller.clearBill();
            },
            child: const Text('CLEAR'),
          ),
        ],
      ),
    );
  }

  void _openItems() {
    final controller = context.read<BillingController>();
    controller.commitPendingForCheckout();
    Navigator.of(context).pushNamed('/items');
  }

  Future<void> _speakTotal() async {
    final controller = context.read<BillingController>();
    final total = controller.grandTotal;
    await context.read<VoiceService>().speak(
      'Total ${formatPlainMoney(total)} rupees',
    );
  }

  Future<void> _listenForPrice() async {
    final voice = context.read<VoiceService>();
    await voice.listen(
      onDigits: (digits) {
        final value = int.tryParse(digits);
        if (value != null) {
          context.read<BillingController>().pressSetPrice(value);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BillingController>();
    final settings = context.watch<SettingsController>().settings;
    final voice = context.watch<VoiceService>();
    final printer = context.watch<ThermalPrinterService>();
    final current = controller.current;
    final scheme = Theme.of(context).colorScheme;
    final showRecentAnywhere = !current.hasInput && _recentPrices.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.shopName.isEmpty
                        ? AppConstants.appName
                        : widget.shopName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2530),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (printer.state == PrinterConnectionState.connected)
                  Tooltip(
                    message: 'H80i connected',
                    child: Icon(Icons.print, color: scheme.primary, size: 26),
                  ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(96, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _openItems,
                  child: const Text('ITEMS'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.outlineVariant, width: 1.5),
                ),
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showRecentAnywhere)
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final price in _recentPrices)
                                        ActionChip(
                                          visualDensity: VisualDensity.compact,
                                          label: Text(
                                            formatMoney(price),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          onPressed: () {
                                            _feedback();
                                            controller.pressSetPrice(price);
                                          },
                                        ),
                                    ],
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                              Column(
                                children: [
                                  if (settings.speakTotal && voice.ttsAvailable)
                                    IconButton(
                                      iconSize: 28,
                                      tooltip: 'Speak total',
                                      onPressed: _speakTotal,
                                      icon: const Icon(Icons.volume_up),
                                    ),
                                  if (settings.voiceInput && voice.sttAvailable)
                                    IconButton(
                                      iconSize: 28,
                                      tooltip: voice.isListening
                                          ? 'Listening...'
                                          : 'Enter price by voice',
                                      onPressed: voice.isListening
                                          ? voice.stopListening
                                          : _listenForPrice,
                                      icon: Icon(
                                        voice.isListening
                                            ? Icons.mic
                                            : Icons.mic_none,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            current.hasInput
                                ? formatMoney(current.price)
                                : '₹0',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${formatMoney(current.price)} × ${current.effectiveQuantity}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            current.hasInput
                                ? formatMoney(current.lineTotal)
                                : '—',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (controller.lastError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  controller.lastError!,
                  style: TextStyle(
                    color: scheme.error,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildRow(const ['7', '8', '9'], controller),
                  _buildRow(const ['4', '5', '6'], controller),
                  _buildRow(const ['1', '2', '3'], controller),
                  Row(
                    children: [
                      Expanded(
                        child: KeypadButton(
                          label: 'C',
                          onPressed: _onClear,
                          backgroundColor: const Color(0xFFFFE0B2),
                          foregroundColor: const Color(0xFF7A4A00),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: KeypadButton(
                          label: '0',
                          onPressed: () {
                            _feedback();
                            controller.pressDigit('0');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: KeypadButton(
                          label: '⌫',
                          onPressed: () {
                            _feedback();
                            controller.pressBackspace();
                          },
                          backgroundColor: const Color(0xFFFFCDD2),
                          foregroundColor: const Color(0xFF8C1D18),
                        ),
                      ),
                    ],
                  ),
                  ActionRow(
                    onMultiply: () {
                      _feedback();
                      controller.pressMultiply();
                    },
                    onNextItem: _onNextItem,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(
                    'ITEMS: ${controller.savedCount}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        formatMoney(controller.grandTotal),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> digits, BillingController controller) {
    return Row(
      children: [
        for (var i = 0; i < digits.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: KeypadButton(
              label: digits[i],
              onPressed: () {
                _feedback();
                controller.pressDigit(digits[i]);
              },
            ),
          ),
        ],
      ],
    );
  }
}
