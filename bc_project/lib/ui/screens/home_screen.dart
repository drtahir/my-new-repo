// lib/ui/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/loading_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final todayTxns = ref.watch(todayTransactionsProvider);
    final now = DateTime.now();
    final monthKey = MonthKey(now.year, now.month);
    final monthlyTxns = ref.watch(monthTransactionsProvider(monthKey));
    final categories = ref.watch(categoriesProvider(null));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(todayTransactionsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ─── App Bar ──────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: Theme.of(context).colorScheme.primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.tertiary,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Family Finance',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                                    onPressed: () {},
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppFormatters.monthYear(DateTime.now()),
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          summary.when(
                            data: (data) => _NetWorthBanner(data: data),
                            loading: () => const _NetWorthLoading(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ─── Summary Cards ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: summary.when(
                data: (data) => _SummaryCards(data: data),
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: LoadingWidget(),
                ),
                error: (e, _) => _ErrorCard(message: e.toString()),
              ),
            ),

            // ─── Monthly Chart ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _MonthlyBarChart(year: now.year, ref: ref),
            ),

            // ─── Quick Actions ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _QuickActions(),
              ),
            ),

            // ─── Today's Transactions ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Today's Transactions",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/transactions'),
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ),
            ),

            todayTxns.when(
              data: (txns) {
                if (txns.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: _EmptyTransactions(),
                  );
                }
                final catMap = categories.valueOrNull ?? [];
                final catUuidMap = {for (final c in catMap) c.uuid: c};
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                      child: TransactionTile(
                        transaction: txns[i],
                        category: catUuidMap[txns[i].categoryId],
                        onTap: () => Navigator.pushNamed(ctx, '/transaction/edit', arguments: txns[i]),
                      ),
                    ),
                    childCount: txns.length,
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(child: LoadingWidget()),
              error: (e, _) => SliverToBoxAdapter(child: _ErrorCard(message: e.toString())),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),

      // ─── FAB ──────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/transaction/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _NetWorthBanner extends StatelessWidget {
  final DashboardSummary data;
  const _NetWorthBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Net Worth', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text(
              AppFormatters.currencyCompact(data.netWorth),
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('This Month', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Row(
              children: [
                Icon(
                  data.monthlyNet >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: data.monthlyNet >= 0 ? Colors.greenAccent : Colors.redAccent,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  AppFormatters.currencyCompact(data.monthlyNet.abs()),
                  style: TextStyle(
                    color: data.monthlyNet >= 0 ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _NetWorthLoading extends StatelessWidget {
  const _NetWorthLoading();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        SizedBox(width: 8),
        Text('Loading...', style: TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final DashboardSummary data;
  const _SummaryCards({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  title: 'Income',
                  subtitle: 'This Month',
                  amount: data.monthlyIncome,
                  icon: Icons.arrow_downward_rounded,
                  color: Colors.green,
                  onTap: () => Navigator.pushNamed(context, '/transactions', arguments: 'income'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SummaryCard(
                  title: 'Expense',
                  subtitle: 'This Month',
                  amount: data.monthlyExpense,
                  icon: Icons.arrow_upward_rounded,
                  color: Colors.red,
                  onTap: () => Navigator.pushNamed(context, '/transactions', arguments: 'expense'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  title: 'Assets',
                  subtitle: 'Total Value',
                  amount: data.totalAssets,
                  icon: Icons.account_balance_wallet,
                  color: Colors.blue,
                  onTap: () => Navigator.pushNamed(context, '/assets'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SummaryCard(
                  title: 'Liabilities',
                  subtitle: 'Outstanding',
                  amount: data.totalLiabilities,
                  icon: Icons.credit_card,
                  color: Colors.orange,
                  onTap: () => Navigator.pushNamed(context, '/liabilities'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final int year;
  final WidgetRef ref;
  const _MonthlyBarChart({required this.year, required this.ref});

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(yearlySummaryProvider(year));
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$year Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              const Text('Income', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 12),
              Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              const Text('Expense', style: TextStyle(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: summary.when(
              data: (months) => BarChart(
                BarChartData(
                  barGroups: months.map((m) => BarChartGroupData(
                    x: m.month - 1,
                    barRods: [
                      BarChartRodData(toY: m.income, color: Colors.green, width: 6, borderRadius: BorderRadius.circular(2)),
                      BarChartRodData(toY: m.expense, color: Colors.red, width: 6, borderRadius: BorderRadius.circular(2)),
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
                        getTitlesWidget: (val, meta) => Text(
                          AppFormatters.shortMonthName(val.toInt() + 1),
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Chart unavailable')),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(icon: Icons.add_circle_outline, label: 'Add Income', color: Colors.green, route: '/transaction/add', args: 'income'),
      _QuickAction(icon: Icons.remove_circle_outline, label: 'Add Expense', color: Colors.red, route: '/transaction/add', args: 'expense'),
      _QuickAction(icon: Icons.account_balance, label: 'Assets', color: Colors.blue, route: '/assets'),
      _QuickAction(icon: Icons.cruelty_free, label: 'Zakat', color: Colors.teal, route: '/zakat'),
      _QuickAction(icon: Icons.bar_chart, label: 'Reports', color: Colors.purple, route: '/reports'),
      _QuickAction(icon: Icons.backup, label: 'Backup', color: Colors.orange, route: '/settings'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: actions.map((a) => _QuickActionButton(action: a)).toList(),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  final Object? args;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.route, this.args});
}

class _QuickActionButton extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.pushNamed(context, action.route, arguments: action.args),
      child: Container(
        decoration: BoxDecoration(
          color: action.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: action.color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, color: action.color, size: 28),
            const SizedBox(height: 4),
            Text(action.label, style: TextStyle(fontSize: 10, color: action.color, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No transactions today', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Tap + to add your first transaction', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}
