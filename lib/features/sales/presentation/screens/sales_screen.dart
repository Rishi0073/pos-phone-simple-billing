import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_billing/core/utils/formatters.dart';
import 'package:simple_billing/features/billing/data/repositories/bill_repository.dart';

enum _Range { today, thisWeek, thisMonth, all }

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  _Range _range = _Range.today;
  late Future<SalesSummary> _future;

  ({DateTime? from, DateTime? to}) _rangeBounds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case _Range.today:
        return (from: today, to: today.add(const Duration(days: 1)));
      case _Range.thisWeek:
        final start = today.subtract(Duration(days: now.weekday - 1));
        return (from: start, to: start.add(const Duration(days: 7)));
      case _Range.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return (from: start, to: start.add(const Duration(days: 31)));
      case _Range.all:
        return (from: null, to: null);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final bounds = _rangeBounds();
    _future = context
        .read<BillRepository>()
        .getSalesSummary(from: bounds.from, to: bounds.to);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SALES'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => setState(_load),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SegmentedButton<_Range>(
              segments: const [
                ButtonSegment(value: _Range.today, label: Text('TODAY')),
                ButtonSegment(value: _Range.thisWeek, label: Text('WEEK')),
                ButtonSegment(value: _Range.thisMonth, label: Text('MONTH')),
                ButtonSegment(value: _Range.all, label: Text('ALL')),
              ],
              selected: {_range},
              onSelectionChanged: (selection) {
                setState(() {
                  _range = selection.first;
                  _load();
                });
              },
            ),
            Expanded(
              child: FutureBuilder<SalesSummary>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data;
                  if (data == null) {
                    return const Center(child: Text('No data'));
                  }
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _StatCard(
                          label: 'TOTAL SALES',
                          value: formatMoney(data.totalSales),
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 12),
                        _StatCard(
                          label: 'NUMBER OF BILLS',
                          value: '${data.billCount}',
                          color: scheme.secondary,
                        ),
                        const SizedBox(height: 12),
                        _StatCard(
                          label: 'AVERAGE BILL',
                          value: formatMoney(data.averageBill),
                          color: scheme.tertiary,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}