// lib/ui/screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:printing/printing.dart';
import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../../features/reports/data/pdf_report_service.dart';
import '../widgets/loading_widget.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _generatingPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Monthly'),
            Tab(text: 'Yearly'),
            Tab(text: 'Breakdown'),
          ],
        ),
        actions: [
          if (_generatingPdf)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _exportPdf,
              tooltip: 'Export PDF',
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MonthlyTab(
            year: _selectedYear,
            month: _selectedMonth,
            onYearChanged: (y) => setState(() => _selectedYear = y),
            onMonthChanged: (m) => setState(() => _selectedMonth = m),
          ),
          _YearlyTab(
            year: _selectedYear,
            onYearChanged: (y) => setState(() => _selectedYear = y),
          ),
          _BreakdownTab(year: _selectedYear, month: _selectedMonth),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    setState(() => _generatingPdf = true);
    try {
      final service = PdfReportService(
        transactionDao: ref.read(transactionDaoProvider),
        assetDao: ref.read(assetDaoProvider),
        liabilityDao: ref.read(liabilityDaoProvider),
        categoryDao: ref.read(categoryDaoProvider),
      );

      Uint8List? bytes;
      String name;

      if (_tabController.index == 1) {
        bytes = await service.generateYearlyReport(_selectedYear);
        name = 'Yearly_Report_$_selectedYear.pdf';
      } else {
        bytes = await service.generateMonthlyReport(_selectedYear, _selectedMonth);
        name = 'Monthly_Report_${AppFormatters.monthName(_selectedMonth)}_$_selectedYear.pdf';
      }

      await Printing.layoutPdf(onLayout: (_) => bytes!, name: name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }
}

// ─── MONTHLY TAB ───────────────────────────────────────────────────────────────

class _MonthlyTab extends ConsumerWidget {
  final int year;
  final int month;
  final Function(int) onYearChanged;
  final Function(int) onMonthChanged;

  const _MonthlyTab({required this.year, required this.month, required this.onYearChanged, required this.onMonthChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = MonthKey(year, month);
    final txnsAsync = ref.watch(monthTransactionsProvider(key));
    final categories = ref.watch(categoriesProvider(null));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Date selector
        _MonthYearSelector(year: year, month: month, onYearChanged: onYearChanged, onMonthChanged: onMonthChanged),
        const SizedBox(height: 16),

        txnsAsync.when(
          data: (txns) {
            double income = 0, expense = 0;
            for (final t in txns) {
              if (t.type == 'income') income += t.amount;
              else expense += t.amount;
            }
            final catMap = {for (final c in categories.valueOrNull ?? []) c.uuid: c};

            return Column(
              children: [
                // Summary row
                _SummaryRow(income: income, expense: expense),
                const SizedBox(height: 16),

                // Pie chart
                if (txns.isNotEmpty) _ExpensePieChart(transactions: txns, catMap: catMap),
                const SizedBox(height: 16),

                // Top expenses
                _TopCategoriesCard(transactions: txns, type: 'expense', catMap: catMap, color: Colors.red),
                const SizedBox(height: 16),
                _TopCategoriesCard(transactions: txns, type: 'income', catMap: catMap, color: Colors.green),
              ],
            );
          },
          loading: () => const LoadingWidget(),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }
}

class _MonthYearSelector extends StatelessWidget {
  final int year;
  final int month;
  final Function(int) onYearChanged;
  final Function(int) onMonthChanged;

  const _MonthYearSelector({required this.year, required this.month, required this.onYearChanged, required this.onMonthChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Month
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int>(
            value: month,
            decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
            items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(AppFormatters.monthName(i + 1)))),
            onChanged: (v) => onMonthChanged(v!),
          ),
        ),
        const SizedBox(width: 12),
        // Year
        Expanded(
          child: DropdownButtonFormField<int>(
            value: year,
            decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
            items: List.generate(6, (i) => DateTime.now().year - i)
                .map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
            onChanged: (v) => onYearChanged(v!),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final double income;
  final double expense;
  const _SummaryRow({required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MetricCard('Income', income, Colors.green, Icons.arrow_downward)),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard('Expense', expense, Colors.red, Icons.arrow_upward)),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard('Net', income - expense, (income - expense) >= 0 ? Colors.blue : Colors.orange, Icons.account_balance)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _MetricCard(this.label, this.amount, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(AppFormatters.currencyCompact(amount.abs()), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _ExpensePieChart extends StatelessWidget {
  final List transactions;
  final Map catMap;

  const _ExpensePieChart({required this.transactions, required this.catMap});

  @override
  Widget build(BuildContext context) {
    final expenseByCat = <String, double>{};
    for (final t in transactions) {
      if (t.type == 'expense') {
        expenseByCat[t.categoryId] = (expenseByCat[t.categoryId] ?? 0) + t.amount;
      }
    }
    if (expenseByCat.isEmpty) return const SizedBox.shrink();

    final sorted = expenseByCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final colors = [Colors.red, Colors.orange, Colors.purple, Colors.blue, Colors.teal, Colors.pink, Colors.indigo, Colors.green];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Expense Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sorted.asMap().entries.map((e) {
                  final cat = catMap[e.value.key];
                  return PieChartSectionData(
                    value: e.value.value,
                    title: '${((e.value.value / expenseByCat.values.fold(0.0, (s, v) => s + v)) * 100).toStringAsFixed(0)}%',
                    color: colors[e.key % colors.length],
                    radius: 70,
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  );
                }).toList(),
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12, runSpacing: 6,
            children: sorted.asMap().entries.map((e) {
              final cat = catMap[e.value.key];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[e.key % colors.length], shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(cat?.name ?? 'Other', style: const TextStyle(fontSize: 11)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TopCategoriesCard extends StatelessWidget {
  final List transactions;
  final String type;
  final Map catMap;
  final Color color;

  const _TopCategoriesCard({required this.transactions, required this.type, required this.catMap, required this.color});

  @override
  Widget build(BuildContext context) {
    final byCat = <String, double>{};
    for (final t in transactions) {
      if (t.type == type) byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
    }
    if (byCat.isEmpty) return const SizedBox.shrink();

    final sorted = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = byCat.values.fold(0.0, (s, v) => s + v);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top ${type == "expense" ? "Expenses" : "Income Sources"}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          ...sorted.take(5).map((e) {
            final cat = catMap[e.key];
            final pct = total > 0 ? e.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(cat?.name ?? 'Other', style: const TextStyle(fontSize: 13)),
                      Text(AppFormatters.currencyCompact(e.value), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct, minHeight: 6,
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── YEARLY TAB ────────────────────────────────────────────────────────────────

class _YearlyTab extends ConsumerWidget {
  final int year;
  final Function(int) onYearChanged;

  const _YearlyTab({required this.year, required this.onYearChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(yearlySummaryProvider(year));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Year selector
        DropdownButtonFormField<int>(
          value: year,
          decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
          items: List.generate(6, (i) => DateTime.now().year - i)
              .map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
          onChanged: (v) => onYearChanged(v!),
        ),
        const SizedBox(height: 20),

        summaryAsync.when(
          data: (months) {
            final totalIncome = months.fold(0.0, (s, m) => s + m.income);
            final totalExpense = months.fold(0.0, (s, m) => s + m.expense);

            return Column(
              children: [
                _SummaryRow(income: totalIncome, expense: totalExpense),
                const SizedBox(height: 20),

                // Bar chart
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$year Monthly Comparison', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            barGroups: months.map((m) => BarChartGroupData(
                              x: m.month - 1,
                              barRods: [
                                BarChartRodData(toY: m.income, color: Colors.green.shade400, width: 8, borderRadius: BorderRadius.circular(4)),
                                BarChartRodData(toY: m.expense, color: Colors.red.shade400, width: 8, borderRadius: BorderRadius.circular(4)),
                              ],
                              barsSpace: 2,
                            )).toList(),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, _) => Text(AppFormatters.shortMonthName(v.toInt() + 1), style: const TextStyle(fontSize: 9)),
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LegendDot(color: Colors.green.shade400, label: 'Income'),
                          const SizedBox(width: 16),
                          _LegendDot(color: Colors.red.shade400, label: 'Expense'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Monthly table
                _MonthlyTable(months: months),
              ],
            );
          },
          loading: () => const LoadingWidget(),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _MonthlyTable extends StatelessWidget {
  final List<MonthlySummary> months;
  const _MonthlyTable({required this.months});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: const [
                Expanded(child: Text('Month', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                SizedBox(width: 80, child: Text('Income', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                SizedBox(width: 80, child: Text('Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                SizedBox(width: 70, child: Text('Net', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
              ],
            ),
          ),
          ...months.asMap().entries.map((e) {
            final m = e.value;
            final isEven = e.key % 2 == 0;
            return Container(
              color: isEven ? Colors.transparent : Colors.grey.withOpacity(0.04),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Text(AppFormatters.shortMonthName(m.month), style: const TextStyle(fontSize: 13))),
                  SizedBox(width: 80, child: Text(AppFormatters.currencyCompact(m.income), style: const TextStyle(color: Colors.green, fontSize: 12), textAlign: TextAlign.right)),
                  SizedBox(width: 80, child: Text(AppFormatters.currencyCompact(m.expense), style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.right)),
                  SizedBox(width: 70, child: Text(AppFormatters.currencyCompact(m.net), style: TextStyle(color: m.net >= 0 ? Colors.blue : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── BREAKDOWN TAB ─────────────────────────────────────────────────────────────

class _BreakdownTab extends ConsumerWidget {
  final int year;
  final int month;
  const _BreakdownTab({required this.year, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = MonthKey(year, month);
    final txnsAsync = ref.watch(monthTransactionsProvider(key));
    final categories = ref.watch(categoriesProvider(null));

    return txnsAsync.when(
      data: (txns) {
        final catMap = {for (final c in categories.valueOrNull ?? []) c.uuid: c};

        final expenseByCat = <String, double>{};
        final incomeByCat = <String, double>{};
        for (final t in txns) {
          if (t.type == 'expense') expenseByCat[t.categoryId] = (expenseByCat[t.categoryId] ?? 0) + t.amount;
          else incomeByCat[t.categoryId] = (incomeByCat[t.categoryId] ?? 0) + t.amount;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${AppFormatters.monthName(month)} $year',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _CatBreakdownList(data: expenseByCat, catMap: catMap, title: 'Expense by Category', color: Colors.red),
            const SizedBox(height: 16),
            _CatBreakdownList(data: incomeByCat, catMap: catMap, title: 'Income by Category', color: Colors.green),
          ],
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _CatBreakdownList extends StatelessWidget {
  final Map<String, double> data;
  final Map catMap;
  final String title;
  final Color color;

  const _CatBreakdownList({required this.data, required this.catMap, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = data.values.fold(0.0, (s, v) => s + v);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(AppFormatters.currencyCompact(total), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          ...sorted.map((e) {
            final cat = catMap[e.key];
            final pct = total > 0 ? e.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(cat?.name ?? 'Other', style: const TextStyle(fontSize: 13)),
                      Row(children: [
                        Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        const SizedBox(width: 8),
                        Text(AppFormatters.currencyCompact(e.value), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct, minHeight: 7,
                      backgroundColor: color.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.7)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
