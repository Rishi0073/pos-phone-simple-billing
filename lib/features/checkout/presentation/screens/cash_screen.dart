import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_billing/core/utils/formatters.dart';
import 'package:simple_billing/features/billing/domain/entities/bill_entities.dart';
import 'package:simple_billing/features/billing/presentation/controllers/billing_controller.dart';
import 'package:simple_billing/features/checkout/domain/services/bill_saver.dart';
import 'package:simple_billing/features/checkout/presentation/widgets/bill_completion_dialog.dart';
import 'package:simple_billing/features/billing/presentation/widgets/keypad.dart';

class CashScreen extends StatefulWidget {
  const CashScreen({super.key, required this.items, required this.discount});

  final List<BillItem> items;
  final int discount;

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  int _customerGives = 0;

  int get _total {
    final subtotal =
        widget.items.fold<int>(0, (sum, item) => sum + item.lineTotal);
    return subtotal - widget.discount;
  }

  int get _change => _customerGives >= _total ? _customerGives - _total : 0;

  bool get _enough => _customerGives >= _total;

  Future<void> _complete() async {
    final saver = context.read<BillSaver>();
    final bill = await saver.save(
      items: widget.items,
      discountAmount: widget.discount,
      paymentMethod: PaymentMethod.cash,
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
      appBar: AppBar(title: const Text('CASH')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                formatMoney(_total),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'CUSTOMER GIVES',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                _customerGives == 0 ? '₹0' : formatMoney(_customerGives),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _enough ? scheme.primary : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'CHANGE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _enough ? scheme.onPrimary : scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      formatMoney(_change),
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: _enough ? scheme.onPrimary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  for (final d in ['1', '2', '3']) ...[
                    if (d != '1') const SizedBox(width: 8),
                    Expanded(
                      child: KeypadButton(
                        label: d,
                        onPressed: () => setState(() {
                          _customerGives = _customerGives * 10 + int.parse(d);
                        }),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final d in ['4', '5', '6']) ...[
                    if (d != '4') const SizedBox(width: 8),
                    Expanded(
                      child: KeypadButton(
                        label: d,
                        onPressed: () => setState(() {
                          _customerGives = _customerGives * 10 + int.parse(d);
                        }),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final d in ['7', '8', '9']) ...[
                    if (d != '7') const SizedBox(width: 8),
                    Expanded(
                      child: KeypadButton(
                        label: d,
                        onPressed: () => setState(() {
                          _customerGives = _customerGives * 10 + int.parse(d);
                        }),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: KeypadButton(
                      label: 'C',
                      onPressed: () => setState(() => _customerGives = 0),
                      backgroundColor: const Color(0xFFFFE0B2),
                      foregroundColor: const Color(0xFF7A4A00),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: KeypadButton(
                      label: '0',
                      onPressed: () => setState(() {
                        _customerGives = _customerGives * 10;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: KeypadButton(
                      label: '⌫',
                      onPressed: () => setState(() {
                        _customerGives = _customerGives ~/ 10;
                      }),
                      backgroundColor: const Color(0xFFFFCDD2),
                      foregroundColor: const Color(0xFF8C1D18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _enough ? _complete : null,
                  child: Text(_enough ? 'PAY & PRINT' : 'ENTER AMOUNT'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}