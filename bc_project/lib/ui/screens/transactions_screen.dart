// lib/ui/screens/transactions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/loading_widget.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  final String? initialFilter; // 'income' | 'expense' | null
  const TransactionsScreen({super.key, this.initialFilter});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _typeFilter;
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _typeFilter = widget.initialFilter;
    _tabController = TabController(length: 3, vsync: this,
      initialIndex: _typeFilter == 'income' ? 1 : _typeFilter == 'expense' ? 2 : 0,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0: _typeFilter = null; break;
            case 1: _typeFilter = 'income'; break;
            case 2: _typeFilter = 'expense'; break;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = TransactionFilter(
      type: _typeFilter,
      categoryId: _selectedCategoryId,
      from: _fromDate,
      to: _toDate,
    );
    final txnsAsync = ref.watch(allTransactionsProvider(filter));
    final categories = ref.watch(categoriesProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Income'),
            Tab(text: 'Expense'),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_fromDate != null || _toDate != null || _selectedCategoryId != null)
                  Positioned(
                    top: 0, right: 0,
                    child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                  ),
              ],
            ),
            onPressed: () => _showFilterSheet(context, categories.valueOrNull ?? []),
          ),
        ],
      ),
      body: Column(
        children: [
          // Active filter chips
          if (_fromDate != null || _toDate != null || _selectedCategoryId != null)
            _ActiveFiltersBar(
              fromDate: _fromDate,
              toDate: _toDate,
              categoryId: _selectedCategoryId,
              categories: categories.valueOrNull ?? [],
              onClear: () => setState(() {
                _fromDate = null;
                _toDate = null;
                _selectedCategoryId = null;
              }),
            ),

          // Totals bar
          txnsAsync.when(
            data: (txns) => _TotalsBar(transactions: txns),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // List
          Expanded(
            child: txnsAsync.when(
              data: (txns) {
                if (txns.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Transactions',
                    subtitle: 'No transactions found for the selected filters.',
                    actionLabel: 'Add Transaction',
                    onAction: () => Navigator.pushNamed(context, '/transaction/add'),
                  );
                }
                final catMap = {for (final c in categories.valueOrNull ?? []) c.uuid: c};
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: txns.length,
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TransactionTile(
                      transaction: txns[i],
                      category: catMap[txns[i].categoryId],
                      onTap: () => Navigator.pushNamed(ctx, '/transaction/edit', arguments: txns[i]),
                      onDelete: () => ref.read(transactionDaoProvider).softDelete(txns[i].id),
                    ),
                  ),
                );
              },
              loading: () => const LoadingWidget(message: 'Loading transactions...'),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/transaction/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, List categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, controller) => _FilterSheet(
          fromDate: _fromDate,
          toDate: _toDate,
          onApply: (from, to) {
            setState(() {
              _fromDate = from;
              _toDate = to;
            });
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }
}

class _TotalsBar extends StatelessWidget {
  final List transactions;
  const _TotalsBar({required this.transactions});

  @override
  Widget build(BuildContext context) {
    double income = 0, expense = 0;
    for (final t in transactions) {
      if (t.type == 'income') income += t.amount;
      else expense += t.amount;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _TotalChip(label: 'Income', amount: income, color: Colors.green),
          _TotalChip(label: 'Expense', amount: expense, color: Colors.red),
          _TotalChip(label: 'Net', amount: income - expense, color: (income - expense) >= 0 ? Colors.blue : Colors.orange),
        ],
      ),
    );
  }
}

class _TotalChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _TotalChip({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        Text(AppFormatters.currencyCompact(amount.abs()), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class _ActiveFiltersBar extends StatelessWidget {
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? categoryId;
  final List categories;
  final VoidCallback onClear;

  const _ActiveFiltersBar({
    required this.fromDate, required this.toDate,
    required this.categoryId, required this.categories, required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 16, color: Colors.blue),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 6,
              children: [
                if (fromDate != null)
                  Chip(label: Text('From: ${AppFormatters.shortDate(fromDate!)}', style: const TextStyle(fontSize: 11)), padding: EdgeInsets.zero),
                if (toDate != null)
                  Chip(label: Text('To: ${AppFormatters.shortDate(toDate!)}', style: const TextStyle(fontSize: 11)), padding: EdgeInsets.zero),
              ],
            ),
          ),
          TextButton(onPressed: onClear, child: const Text('Clear', style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final DateTime? fromDate;
  final DateTime? toDate;
  final Function(DateTime? from, DateTime? to) onApply;

  const _FilterSheet({required this.fromDate, required this.toDate, required this.onApply});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _from = widget.fromDate;
    _to = widget.toDate;
  }

  @override
  Widget build(BuildContext context) {
    final quickRanges = [
      ('This Month', _thisMonth()),
      ('Last Month', _lastMonth()),
      ('This Year', _thisYear()),
      ('Last 7 Days', _last7Days()),
      ('Last 30 Days', _last30Days()),
    ];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Quick Ranges', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: quickRanges.map((r) => ActionChip(
              label: Text(r.$1),
              onPressed: () {
                setState(() { _from = r.$2.$1; _to = r.$2.$2; });
              },
            )).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _DateButton(label: 'From', date: _from, onPick: (d) => setState(() => _from = d))),
              const SizedBox(width: 12),
              Expanded(child: _DateButton(label: 'To', date: _to, onPick: (d) => setState(() => _to = d))),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onApply(null, null),
                  child: const Text('Clear Filters'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => widget.onApply(_from, _to),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (DateTime, DateTime) _thisMonth() {
    final now = DateTime.now();
    return (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1)));
  }

  (DateTime, DateTime) _lastMonth() {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month - 1, 1);
    return (first, DateTime(now.year, now.month, 1).subtract(const Duration(days: 1)));
  }

  (DateTime, DateTime) _thisYear() {
    final now = DateTime.now();
    return (DateTime(now.year, 1, 1), DateTime(now.year, 12, 31));
  }

  (DateTime, DateTime) _last7Days() {
    final now = DateTime.now();
    return (now.subtract(const Duration(days: 7)), now);
  }

  (DateTime, DateTime) _last30Days() {
    final now = DateTime.now();
    return (now.subtract(const Duration(days: 30)), now);
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final Function(DateTime) onPick;

  const _DateButton({required this.label, required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) onPick(picked);
      },
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(date != null ? AppFormatters.shortDate(date!) : label, style: const TextStyle(fontSize: 13)),
    );
  }
}
