import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_billing/core/errors/app_failures.dart';
import 'package:simple_billing/core/utils/formatters.dart';
import 'package:simple_billing/features/billing/data/repositories/bill_repository.dart';
import 'package:simple_billing/features/billing/domain/entities/bill_entities.dart';
import 'package:simple_billing/features/printer/domain/print_encoding.dart';
import 'package:simple_billing/features/printer/domain/receipt_builder.dart';
import 'package:simple_billing/features/printer/domain/thermal_printer_service.dart';
import 'package:simple_billing/features/settings/presentation/controllers/settings_controller.dart';
import 'package:simple_billing/features/upi/domain/services/upi_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Bill>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<BillRepository>().getBills();
  }

  void _reload() {
    setState(() {
      _future = context.read<BillRepository>().getBills();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HISTORY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Bill>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final bills = snapshot.data ?? const <Bill>[];
            if (bills.isEmpty) {
              return const Center(
                child: Text(
                  'NO BILLS YET',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: bills.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _BillCard(bill: bills[index], onChanged: _reload),
            );
          },
        ),
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, required this.onChanged});

  final Bill bill;
  final VoidCallback onChanged;

  Future<void> _reprint(BuildContext context) async {
    try {
      final shop = context.read<SettingsController>().settings;
      final printer = context.read<ThermalPrinterService>();
      final upiPayload = shop.hasUpiId
          ? const UpiService().buildPaymentUri(
              upiId: shop.upiId,
              merchantName: shop.shopName.isEmpty ? 'Shop' : shop.shopName,
              amount: bill.total,
              billReference: formatBillNumber(bill.billNumber),
            )
          : null;
      final bytes = ReceiptBuilder(
        width: shop.paperWidthChars,
        encoding: PrintEncoding.fromValue(shop.printerEncoding),
        printLogo: shop.printLogo,
        printBarcode: shop.printBarcode,
      ).build(
        shop: shop,
        bill: bill,
        upiPayload: upiPayload,
        autoCut: shop.autoCut,
      );
      await printer.print(bytes);
    } on AppFailure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final repo = context.read<BillRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('DELETE BILL?'),
        content: Text(
            'Bill ${formatBillNumber(bill.billNumber)} will be removed.'),
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
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repo.deleteBill(bill.id);
      if (!context.mounted) return;
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bill ${formatBillNumber(bill.billNumber)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  bill.paymentMethod.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formatDateTime(bill.createdAt),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${bill.items.length} ITEMS',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  formatMoney(bill.total),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => _reprint(context),
                    icon: const Icon(Icons.print, size: 20),
                    label: const Text('REPRINT'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _delete(context),
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}