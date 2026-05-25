// lib/ui/screens/zakat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../../features/zakat/data/zakat_engine.dart';
import '../../features/reports/data/pdf_report_service.dart';
import '../widgets/loading_widget.dart';

class ZakatScreen extends ConsumerWidget {
  const ZakatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calcAsync = ref.watch(zakatCalculationProvider);
    final snapshots = ref.watch(zakatSnapshotsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zakat Calculator'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          calcAsync.maybeWhen(
            data: (calc) => IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => _exportPdf(context, ref, calc),
              tooltip: 'Export PDF',
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(zakatCalculationProvider),
            tooltip: 'Recalculate',
          ),
        ],
      ),
      body: calcAsync.when(
        data: (calc) => _ZakatContent(calc: calc, ref: ref),
        loading: () => const LoadingWidget(message: 'Calculating Zakat...'),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref, ZakatCalculation calc) async {
    try {
      final service = PdfReportService(
        transactionDao: ref.read(transactionDaoProvider),
        assetDao: ref.read(assetDaoProvider),
        liabilityDao: ref.read(liabilityDaoProvider),
        categoryDao: ref.read(categoryDaoProvider),
      );
      final bytes = await service.generateZakatReport(calc);
      await Printing.layoutPdf(onLayout: (_) => bytes, name: 'Zakat_Report_${DateTime.now().year}.pdf');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

class _ZakatContent extends ConsumerStatefulWidget {
  final ZakatCalculation calc;
  final WidgetRef ref;

  const _ZakatContent({required this.calc, required this.ref});

  @override
  ConsumerState<_ZakatContent> createState() => _ZakatContentState();
}

class _ZakatContentState extends ConsumerState<_ZakatContent> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final calc = widget.calc;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ─── Status Banner ──────────────────────────────────────────────────
        _StatusBanner(calc: calc),
        const SizedBox(height: 16),

        // ─── Prices Warning ─────────────────────────────────────────────────
        if (calc.goldPricePerGram == 0 || calc.silverPricePerGram == 0)
          _PricesWarningCard(),

        // ─── Wealth Breakdown ────────────────────────────────────────────────
        _SectionCard(
          title: 'Zakatable Wealth',
          icon: Icons.account_balance_wallet,
          iconColor: Colors.teal,
          child: Column(
            children: [
              _WealthRow('Gold (Zakatable)', calc.goldValue, Colors.amber),
              _WealthRow('Silver (Zakatable)', calc.silverValue, Colors.grey.shade400),
              _WealthRow('Cash & Savings', calc.cashValue, Colors.green),
              _WealthRow('Business Assets', calc.businessValue, Colors.blue),
              _WealthRow('Other Assets', calc.otherAssetsValue, Colors.purple),
              const Divider(height: 16),
              _WealthRow('Gross Wealth', calc.grossWealth, Colors.teal, bold: true),
              _WealthRow('Less: Liabilities', -calc.totalLiabilities, Colors.red, isDeduction: true),
              const Divider(height: 8),
              _WealthRow('Net Zakatable Wealth', calc.zakatableWealth, Colors.teal, bold: true, large: true),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ─── Nisab Info ──────────────────────────────────────────────────────
        _SectionCard(
          title: 'Nisab Threshold',
          icon: Icons.info_outline,
          iconColor: Colors.orange,
          child: Column(
            children: [
              _NisabRow('Gold Nisab (87.48g)', calc.nisabGoldValue, calc.nisabMethod == 'gold'),
              _NisabRow('Silver Nisab (612.36g)', calc.nisabSilverValue, calc.nisabMethod == 'silver'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Using ${calc.nisabMethod == "gold" ? "Gold" : "Silver"} Nisab. Change in Settings.',
                        style: const TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ─── Zakat Amount ────────────────────────────────────────────────────
        if (calc.zakatDue)
          _SectionCard(
            title: 'Zakat Due (2.5%)',
            icon: Icons.volunteer_activism,
            iconColor: Colors.teal,
            child: Column(
              children: [
                Center(
                  child: Text(
                    AppFormatters.currency(calc.zakatAmount, decimals: 2),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '= ${AppFormatters.currency(calc.zakatableWealth)} × 2.5%',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),

        // ─── Save Snapshot ───────────────────────────────────────────────────
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveSnapshot,
          icon: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save),
          label: Text(_isSaving ? 'Saving...' : 'Save ${DateTime.now().year} Zakat Record'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.teal,
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
        const SizedBox(height: 24),

        // ─── Previous Snapshots ──────────────────────────────────────────────
        _SnapshotsSection(),
        const SizedBox(height: 80),
      ],
    );
  }

  Future<void> _saveSnapshot() async {
    setState(() => _isSaving = true);
    try {
      final engine = ref.read(zakatEngineProvider);
      await engine.saveSnapshot(
        calculation: widget.calc,
        zakatDao: ref.read(zakatDaoProvider),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zakat record saved successfully'), backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _PricesWarningCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gold/Silver prices not set', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                const Text('Go to Settings → Zakat Settings to enter current prices for accurate calculation.', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            child: const Text('Set Now'),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final ZakatCalculation calc;
  const _StatusBanner({required this.calc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: calc.zakatDue
              ? [Colors.orange.shade700, Colors.orange.shade400]
              : [Colors.teal.shade700, Colors.teal.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text(calc.zakatDue ? '🌙' : '✅', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            calc.zakatDue ? 'Zakat is Obligatory' : 'Zakat Not Due',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            calc.zakatDue
                ? 'Your wealth exceeds the Nisab threshold'
                : 'Wealth is below Nisab threshold',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (calc.zakatDue) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                AppFormatters.currency(calc.zakatAmount, decimals: 2),
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _SectionCard({required this.title, required this.icon, required this.iconColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const Divider(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _WealthRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool bold;
  final bool large;
  final bool isDeduction;

  const _WealthRow(this.label, this.amount, this.color, {this.bold = false, this.large = false, this.isDeduction = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: large ? 14 : 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
          Text(
            isDeduction ? '- ${AppFormatters.currency(amount.abs())}' : AppFormatters.currency(amount),
            style: TextStyle(
              fontSize: large ? 16 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: isDeduction ? Colors.red : (amount > 0 ? null : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _NisabRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isActive;

  const _NisabRow(this.label, this.value, this.isActive);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: isActive ? Border.all(color: Colors.orange, width: 1.5) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (isActive) const Icon(Icons.check_circle, color: Colors.orange, size: 16)
              else const Icon(Icons.circle_outlined, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
          Text(
            value > 0 ? AppFormatters.currency(value, decimals: 2) : 'Price not set',
            style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: value > 0 ? null : Colors.red),
          ),
        ],
      ),
    );
  }
}

class _SnapshotsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshots = ref.watch(zakatSnapshotsProvider);
    return snapshots.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Previous Records', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...list.map((snap) => _SnapshotTile(snapshot: snap)),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  final ZakatSnapshot snapshot;
  const _SnapshotTile({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.history, color: Colors.teal),
        ),
        title: Text('${snapshot.year} Zakat Record', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(snapshot.zakatDue ? 'Due: ${AppFormatters.currency(snapshot.zakatAmount, decimals: 2)}' : 'Below Nisab – Not Due'),
        trailing: Chip(
          label: Text(snapshot.zakatDue ? 'Due' : 'Not Due', style: const TextStyle(fontSize: 11, color: Colors.white)),
          backgroundColor: snapshot.zakatDue ? Colors.orange : Colors.teal,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
