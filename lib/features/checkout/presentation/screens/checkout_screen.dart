import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_billing/core/utils/formatters.dart';
import 'package:simple_billing/features/billing/presentation/controllers/billing_controller.dart';
import 'package:simple_billing/features/checkout/domain/services/bill_saver.dart';
import 'package:simple_billing/features/checkout/presentation/screens/cash_screen.dart';
import 'package:simple_billing/features/checkout/presentation/screens/upi_payment_screen.dart';
import 'package:simple_billing/features/settings/presentation/controllers/settings_controller.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _discount = 0;
  String? _discountError;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BillingController>();
    final items = controller.savedItems;
    final shop = context.watch<SettingsController>().settings;
    final subtotal = controller.savedTotal;
    final total = subtotal - _discount;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('CHECKOUT')),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: scheme.primaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.shopName.isEmpty ? 'SHOP' : shop.shopName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FutureBuilder<int>(
                    future: context.read<BillSaver>().nextBillNumber(),
                    builder: (context, snapshot) => Text(
                      'Bill No: ${formatBillNumber(snapshot.data ?? 1)} • ${formatDateTime(DateTime.now())}',
                      style: TextStyle(
                        fontSize: 15,
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length + 3,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'PRICE',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'QTY',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'AMOUNT',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (index <= items.length) {
                    final item = items[index - 1];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              formatMoney(item.price),
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${item.quantity}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              formatMoney(item.lineTotal),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return _DiscountRow(
                    discount: _discount,
                    error: _discountError,
                    onChanged: (value) {
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed < 0) {
                        setState(() {
                          _discount = 0;
                          _discountError = 'Enter a valid discount amount.';
                        });
                        return;
                      }
                      setState(() {
                        _discount = parsed > subtotal ? subtotal : parsed;
                        _discountError = null;
                      });
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          formatMoney(total),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.payments, size: 28),
                          label: const Text('CASH'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CashScreen(items: items, discount: _discount),
                            ),
                          ),
                        ),
                      ),
                      if (shop.hasUpiId) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.qr_code_2, size: 28),
                            label: const Text('UPI'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => UpiPaymentScreen(
                                  items: items,
                                  discount: _discount,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscountRow extends StatelessWidget {
  const _DiscountRow({
    required this.discount,
    required this.error,
    required this.onChanged,
  });

  final int discount;
  final String? error;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'DISCOUNT (optional)',
          prefixText: '₹ ',
          errorText: error,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
