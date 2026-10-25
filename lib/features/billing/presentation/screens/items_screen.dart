import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_billing/core/utils/formatters.dart';
import 'package:simple_billing/features/billing/domain/entities/bill_entities.dart';
import 'package:simple_billing/features/billing/presentation/controllers/billing_controller.dart';

class ItemsScreen extends StatelessWidget {
  const ItemsScreen({super.key});

  void _openCheckout(BuildContext context) {
    final controller = context.read<BillingController>();
    if (controller.savedItems.isEmpty) return;
    Navigator.of(context).pushNamed('/checkout');
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BillingController>();
    final items = controller.savedItems;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ITEMS'),
        actions: [
          IconButton(
            tooltip: 'Undo last item',
            icon: const Icon(Icons.undo),
            onPressed: controller.savedItems.isEmpty
                ? null
                : () {
                    context.read<BillingController>().pressUndo();
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: scheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'NO ITEMS YET',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Enter a price to start billing.',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _ItemRow(
                          item: item,
                          onTap: () => _showItemActions(context, item),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${items.length} ITEMS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimary,
                      ),
                    ),
                    Text(
                      formatMoney(controller.savedTotal),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: items.isEmpty
                      ? null
                      : () => _openCheckout(context),
                  icon: const Icon(Icons.point_of_sale, size: 28),
                  label: const Text('BILL / CHECKOUT'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemActions(BuildContext context, BillItem item) {
    final controller = context.read<BillingController>();
    final index = controller.savedItems.indexOf(item);
    if (index < 0) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ITEM ${item.itemOrder}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${formatMoney(item.price)} × ${item.quantity}',
                  style: const TextStyle(fontSize: 22),
                ),
                Text(
                  formatMoney(item.lineTotal),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(sheetContext).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _showEditDialog(context, index, item);
                    },
                    child: const Text('EDIT'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(sheetContext).colorScheme.error,
                    ),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _confirmRemove(context, index);
                    },
                    child: const Text('REMOVE'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('CANCEL'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmRemove(BuildContext context, int index) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('REMOVE ITEM?'),
        content: const Text('This item will be removed from the bill.'),
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
              context.read<BillingController>().removeItem(index);
            },
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, int index, BillItem item) {
    final controller = context.read<BillingController>();
    final priceController =
        TextEditingController(text: item.price.toString());
    final qtyController = TextEditingController(text: item.quantity.toString());

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('EDIT ITEM'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PRICE',
                prefixText: '₹ ',
              ),
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'QUANTITY'),
              style: const TextStyle(fontSize: 22),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              final price = int.tryParse(priceController.text.trim()) ?? -1;
              final qty = int.tryParse(qtyController.text.trim()) ?? 0;
              if (price >= 0 && qty > 0) {
                controller.editItem(index, price: price, quantity: qty);
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onTap});

  final BillItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(
                '${item.itemOrder}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${formatMoney(item.price)} × ${item.quantity}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatMoney(item.lineTotal),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}