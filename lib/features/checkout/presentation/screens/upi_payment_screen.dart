import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:simple_billing/core/utils/formatters.dart';
import 'package:simple_billing/features/billing/domain/entities/bill_entities.dart';
import 'package:simple_billing/features/billing/presentation/controllers/billing_controller.dart';
import 'package:simple_billing/features/checkout/domain/services/bill_saver.dart';
import 'package:simple_billing/features/checkout/presentation/widgets/bill_completion_dialog.dart';
import 'package:simple_billing/features/settings/presentation/controllers/settings_controller.dart';
import 'package:simple_billing/features/upi/domain/services/upi_service.dart';

class UpiPaymentScreen extends StatefulWidget {
  const UpiPaymentScreen({
    super.key,
    required this.items,
    required this.discount,
  });

  final List<BillItem> items;
  final int discount;

  @override
  State<UpiPaymentScreen> createState() => _UpiPaymentScreenState();
}

class _UpiPaymentScreenState extends State<UpiPaymentScreen> {
  String _payload = '';

  int get _total {
    final subtotal =
        widget.items.fold<int>(0, (sum, item) => sum + item.lineTotal);
    return subtotal - widget.discount;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shop = context.read<SettingsController>().settings;
    _payload = const UpiService().buildPaymentUri(
      upiId: shop.upiId,
      merchantName: shop.shopName.isEmpty ? 'Shop' : shop.shopName,
      amount: _total,
      billReference: 'CART',
    );
  }

  Future<void> _markPaid() async {
    final saver = context.read<BillSaver>();
    final bill = await saver.save(
      items: widget.items,
      discountAmount: widget.discount,
      paymentMethod: PaymentMethod.upi,
      paymentStatus: PaymentStatus.paid,
    );
    if (!mounted) return;
    await showBillCompletionDialog(context, bill: bill);
    if (!mounted) return;
    context.read<BillingController>().clearBill();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('UPI PAYMENT')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Spacer(),
              Text(
                'PAY WITH UPI',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatMoney(_total),
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: QrImageView(
                  data: _payload,
                  version: QrVersions.auto,
                  size: 260,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: const Color(0xFF1A2530),
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: const Color(0xFF1A2530),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Show this QR to the customer.\nScanning the QR does not confirm payment.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _markPaid,
                      icon: const Icon(Icons.check_circle, size: 28),
                      label: const Text('MARK AS PAID'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}