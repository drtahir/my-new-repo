// lib/features/reports/data/pdf_report_service.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/formatters.dart';
import '../../zakat/data/zakat_engine.dart';

class PdfReportService {
  final TransactionDao transactionDao;
  final AssetDao assetDao;
  final LiabilityDao liabilityDao;
  final CategoryDao categoryDao;

  PdfReportService({
    required this.transactionDao,
    required this.assetDao,
    required this.liabilityDao,
    required this.categoryDao,
  });

  // ─── MONTHLY REPORT ────────────────────────────────────────────────────────

  Future<Uint8List> generateMonthlyReport(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1).subtract(const Duration(milliseconds: 1));

    final transactions = await transactionDao.watchAll(from: start, to: end, limit: 1000).first;
    final totalIncome = await transactionDao.getTotalIncome(from: start, to: end);
    final totalExpense = await transactionDao.getTotalExpense(from: start, to: end);
    final categories = await categoryDao.getAll();
    final catMap = {for (final c in categories) c.uuid: c};

    final incomeBreakdown = await transactionDao.getCategoryBreakdown(type: 'income', from: start, to: end);
    final expenseBreakdown = await transactionDao.getCategoryBreakdown(type: 'expense', from: start, to: end);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.nunitoRegular(),
        bold: await PdfGoogleFonts.nunitoBold(),
      ),
    );

    final monthLabel = '${AppFormatters.monthName(month)} $year';
    final generatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader('Monthly Financial Report', monthLabel),
        footer: (ctx) => _buildFooter(ctx, generatedAt),
        build: (ctx) => [
          _buildSummaryBox(totalIncome, totalExpense),
          pw.SizedBox(height: 20),
          _buildSectionTitle('Income Breakdown'),
          _buildCategoryTable(incomeBreakdown, catMap, PdfColors.green100),
          pw.SizedBox(height: 20),
          _buildSectionTitle('Expense Breakdown'),
          _buildCategoryTable(expenseBreakdown, catMap, PdfColors.red100),
          pw.SizedBox(height: 20),
          _buildSectionTitle('All Transactions'),
          _buildTransactionTable(transactions, catMap),
        ],
      ),
    );

    return pdf.save();
  }

  // ─── YEARLY REPORT ─────────────────────────────────────────────────────────

  Future<Uint8List> generateYearlyReport(int year) async {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31, 23, 59, 59);

    final totalIncome = await transactionDao.getTotalIncome(from: start, to: end);
    final totalExpense = await transactionDao.getTotalExpense(from: start, to: end);
    final monthlySummary = await transactionDao.getMonthlySummary(year);
    final assets = await assetDao.getAllForExport();
    final liabilitiesList = await liabilityDao.getAllForExport();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.nunitoRegular(),
        bold: await PdfGoogleFonts.nunitoBold(),
      ),
    );

    final generatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader('Yearly Financial Report', year.toString()),
        footer: (ctx) => _buildFooter(ctx, generatedAt),
        build: (ctx) => [
          _buildSummaryBox(totalIncome, totalExpense),
          pw.SizedBox(height: 20),
          _buildSectionTitle('Monthly Summary'),
          _buildMonthlySummaryTable(monthlySummary),
          pw.SizedBox(height: 20),
          _buildSectionTitle('Assets Overview'),
          _buildAssetsTable(assets),
          pw.SizedBox(height: 20),
          _buildSectionTitle('Liabilities Overview'),
          _buildLiabilitiesTable(liabilitiesList),
        ],
      ),
    );

    return pdf.save();
  }

  // ─── ZAKAT REPORT ──────────────────────────────────────────────────────────

  Future<Uint8List> generateZakatReport(ZakatCalculation calc) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.nunitoRegular(),
        bold: await PdfGoogleFonts.nunitoBold(),
      ),
    );

    final generatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final year = DateTime.now().year.toString();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader('Zakat Calculation Report', year),
            pw.SizedBox(height: 24),
            _buildZakatStatus(calc),
            pw.SizedBox(height: 20),
            _buildSectionTitle('Wealth Breakdown'),
            _buildZakatBreakdownTable(calc),
            pw.SizedBox(height: 20),
            _buildSectionTitle('Nisab Information'),
            _buildNisabInfo(calc),
            pw.SizedBox(height: 20),
            _buildZakatNote(),
            pw.Spacer(),
            _buildFooter(ctx, generatedAt),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  // ─── PDF WIDGETS ───────────────────────────────────────────────────────────

  pw.Widget _buildHeader(String title, String subtitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue800, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Family Finance & Zakat Manager',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              pw.SizedBox(height: 4),
              pw.Text(title,
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.Text(subtitle,
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue800,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text('CONFIDENTIAL',
              style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context ctx, String generatedAt) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated: $generatedAt', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryBox(double income, double expense) {
    final net = income - expense;
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('Total Income', AppFormatters.currency(income), PdfColors.green700),
          _summaryItem('Total Expense', AppFormatters.currency(expense), PdfColors.red700),
          _summaryItem('Net Balance', AppFormatters.currency(net), net >= 0 ? PdfColors.green800 : PdfColors.red800),
        ],
      ),
    );
  }

  pw.Widget _summaryItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
    );
  }

  pw.Widget _buildTransactionTable(List<Transaction> txns, Map<String, Category> catMap) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
      },
      headers: ['Date', 'Title', 'Amount', 'Category', 'Type'],
      data: txns.map((t) => [
        AppFormatters.shortDate(t.transactionDate),
        t.title.length > 30 ? '${t.title.substring(0, 27)}...' : t.title,
        AppFormatters.currency(t.amount),
        catMap[t.categoryId]?.name ?? 'Unknown',
        t.type.toUpperCase(),
      ]).toList(),
    );
  }

  pw.Widget _buildCategoryTable(List<CategoryBreakdown> breakdown, Map<String, Category> catMap, PdfColor bg) {
    if (breakdown.isEmpty) {
      return pw.Text('No data', style: const pw.TextStyle(color: PdfColors.grey500));
    }
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: bg == PdfColors.green100 ? PdfColors.green700 : PdfColors.red700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
      headers: ['Category', 'Amount'],
      data: breakdown.map((b) => [
        catMap[b.categoryId]?.name ?? 'Unknown',
        AppFormatters.currency(b.amount),
      ]).toList(),
    );
  }

  pw.Widget _buildMonthlySummaryTable(List<MonthlySummary> months) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      headers: ['Month', 'Income', 'Expense', 'Net'],
      data: months.map((m) => [
        AppFormatters.monthName(m.month),
        AppFormatters.currency(m.income),
        AppFormatters.currency(m.expense),
        AppFormatters.currency(m.net),
      ]).toList(),
    );
  }

  pw.Widget _buildAssetsTable(List<Asset> assetList) {
    if (assetList.isEmpty) return pw.Text('No assets recorded.', style: const pw.TextStyle(color: PdfColors.grey500));
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headers: ['Name', 'Type', 'Current Value', 'Zakat?'],
      data: assetList.map((a) => [
        a.name,
        a.type.toUpperCase(),
        AppFormatters.currency(a.currentValue),
        a.isZakatApplicable ? 'Yes' : 'No',
      ]).toList(),
    );
  }

  pw.Widget _buildLiabilitiesTable(List<Liability> libs) {
    if (libs.isEmpty) return pw.Text('No liabilities recorded.', style: const pw.TextStyle(color: PdfColors.grey500));
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headers: ['Person', 'Type', 'Total', 'Remaining', 'Status'],
      data: libs.map((l) => [
        l.personName,
        l.type,
        AppFormatters.currency(l.totalAmount),
        AppFormatters.currency(l.remainingAmount),
        l.status.toUpperCase(),
      ]).toList(),
    );
  }

  pw.Widget _buildZakatStatus(ZakatCalculation calc) {
    final color = calc.zakatDue ? PdfColors.orange : PdfColors.green700;
    final bg = calc.zakatDue ? PdfColors.orange50 : PdfColors.green50;
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(calc.zakatDue ? '🌙 ZAKAT IS OBLIGATORY' : '✅ ZAKAT NOT DUE',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: color)),
          pw.SizedBox(height: 8),
          pw.Text(calc.zakatDue
            ? 'Zakat Amount Due: ${AppFormatters.currency(calc.zakatAmount)}'
            : 'Your wealth is below the Nisab threshold.',
            style: pw.TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  pw.Widget _buildZakatBreakdownTable(ZakatCalculation calc) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
      headers: ['Item', 'Amount (PKR)'],
      data: [
        ['Gold (Zakatable)', AppFormatters.currency(calc.goldValue)],
        ['Silver (Zakatable)', AppFormatters.currency(calc.silverValue)],
        ['Cash & Savings', AppFormatters.currency(calc.cashValue)],
        ['Business Assets', AppFormatters.currency(calc.businessValue)],
        ['Other Zakatable Assets', AppFormatters.currency(calc.otherAssetsValue)],
        ['Gross Wealth', AppFormatters.currency(calc.grossWealth)],
        ['Less: Liabilities', '- ${AppFormatters.currency(calc.totalLiabilities)}'],
        ['NET ZAKATABLE WEALTH', AppFormatters.currency(calc.zakatableWealth)],
        ['ZAKAT (2.5%)', AppFormatters.currency(calc.zakatAmount)],
      ],
    );
  }

  pw.Widget _buildNisabInfo(ZakatCalculation calc) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Nisab Method: ${calc.nisabMethod == "gold" ? "Gold (87.48g)" : "Silver (612.36g)"}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Text('Nisab Threshold: ${AppFormatters.currency(calc.nisabThreshold)}',
            style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Gold Rate: ₨${calc.goldPricePerGram}/g | Silver Rate: ₨${calc.silverPricePerGram}/g',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  pw.Widget _buildZakatNote() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.yellow50,
        border: pw.Border.all(color: PdfColors.yellow700),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        'Note: This Zakat calculation is based on the data entered in the app. '
        'Please consult a qualified Islamic scholar for your specific situation. '
        'Zakat must complete one full Hawl (lunar year) above Nisab to be obligatory.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
    );
  }
}
