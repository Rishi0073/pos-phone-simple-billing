import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_billing/core/errors/app_failures.dart';
import 'package:simple_billing/core/utils/formatters.dart';
import 'package:simple_billing/features/billing/domain/entities/bill_entities.dart';
import 'package:simple_billing/features/printer/domain/print_encoding.dart';
import 'package:simple_billing/features/printer/domain/receipt_builder.dart';
import 'package:simple_billing/features/printer/domain/thermal_printer_service.dart';
import 'package:simple_billing/features/settings/presentation/controllers/settings_controller.dart';
import 'package:simple_billing/features/upi/domain/services/upi_service.dart';

/// Shown after a bill is saved: "Print" or "Done".
Future<void> showBillCompletionDialog(
  BuildContext context, {
  required Bill bill,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _CompletionDialog(bill: bill),
  );
}

class _CompletionDialog extends StatefulWidget {
  const _CompletionDialog({required this.bill});

  final Bill bill;

  @override
  State<_CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<_CompletionDialog> {
  bool _printing = false;
  String? _error;

  Future<void> _print() async {
    setState(() {
      _printing = true;
      _error = null;
    });
    try {
      final shop = context.read<SettingsController>().settings;
      final printer = context.read<ThermalPrinterService>();
      final upiPayload = shop.hasUpiId
          ? const UpiService().buildPaymentUri(
              upiId: shop.upiId,
              merchantName: shop.shopName.isEmpty ? 'Shop' : shop.shopName,
              amount: widget.bill.total,
              billReference: formatBillNumber(widget.bill.billNumber),
            )
          : null;
      final bytes = ReceiptBuilder(
        width: shop.paperWidthChars,
        encoding: PrintEncoding.fromValue(shop.printerEncoding),
        printLogo: shop.printLogo,
        printBarcode: shop.printBarcode,
      ).build(
        shop: shop,
        bill: widget.bill,
        upiPayload: upiPayload,
        autoCut: shop.autoCut,
      );
      await printer.print(bytes);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on AppFailure catch (e) {
      if (mounted) {
        setState(() {
          _printing = false;
          _error = e.userMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _printing = false;
          _error = 'Could not print the bill.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('BILL SAVED'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill No: ${formatBillNumber(widget.bill.billNumber)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Text(
            'Total: ${formatMoney(widget.bill.total)}',
            style: const TextStyle(fontSize: 20),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('DONE'),
        ),
        FilledButton.icon(
          onPressed: _printing ? null : _print,
          icon: _printing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.print),
          label: Text(_printing ? 'PRINTING...' : 'PRINT'),
        ),
      ],
    );
  }
}