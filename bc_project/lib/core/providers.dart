// lib/core/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/app_database.dart';
import 'backup/backup_service.dart';
import 'security/auth_service.dart';
import '../features/zakat/data/zakat_engine.dart';

// ─── DATABASE ─────────────────────────────────────────────────────────────────

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ─── DAOs ─────────────────────────────────────────────────────────────────────

final transactionDaoProvider = Provider<TransactionDao>((ref) => ref.watch(databaseProvider).transactionDao);
final categoryDaoProvider = Provider<CategoryDao>((ref) => ref.watch(databaseProvider).categoryDao);
final assetDaoProvider = Provider<AssetDao>((ref) => ref.watch(databaseProvider).assetDao);
final liabilityDaoProvider = Provider<LiabilityDao>((ref) => ref.watch(databaseProvider).liabilityDao);
final zakatDaoProvider = Provider<ZakatDao>((ref) => ref.watch(databaseProvider).zakatDao);
final settingsDaoProvider = Provider<SettingsDao>((ref) => ref.watch(databaseProvider).settingsDao);
final bcDaoProvider = Provider<BcDao>((ref) => ref.watch(databaseProvider).bcDao);

// ─── SERVICES ─────────────────────────────────────────────────────────────────

final backupServiceProvider = Provider<BackupService>((ref) => BackupService(db: ref.watch(databaseProvider)));
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final zakatEngineProvider = Provider<ZakatEngine>((ref) => ZakatEngine(
  assetDao: ref.watch(assetDaoProvider),
  liabilityDao: ref.watch(liabilityDaoProvider),
  settingsDao: ref.watch(settingsDaoProvider),
));

// ─── STREAMS: TRANSACTIONS ────────────────────────────────────────────────────

final allTransactionsProvider = StreamProvider.autoDispose.family<List<Transaction>, TransactionFilter>((ref, filter) {
  return ref.watch(transactionDaoProvider).watchAll(type: filter.type, categoryId: filter.categoryId, from: filter.from, to: filter.to);
});

final todayTransactionsProvider = StreamProvider.autoDispose<List<Transaction>>((ref) {
  return ref.watch(transactionDaoProvider).watchToday();
});

final monthTransactionsProvider = StreamProvider.autoDispose.family<List<Transaction>, MonthKey>((ref, key) {
  return ref.watch(transactionDaoProvider).watchByMonth(key.year, key.month);
});

// ─── STREAMS: ASSETS ──────────────────────────────────────────────────────────

final allAssetsProvider = StreamProvider.autoDispose<List<Asset>>((ref) => ref.watch(assetDaoProvider).watchAll());
final assetsByTypeProvider = StreamProvider.autoDispose.family<List<Asset>, String>((ref, type) => ref.watch(assetDaoProvider).watchAll(type: type));

// ─── STREAMS: LIABILITIES ─────────────────────────────────────────────────────

final allLiabilitiesProvider = StreamProvider.autoDispose<List<Liability>>((ref) => ref.watch(liabilityDaoProvider).watchAll());
final activeLiabilitiesProvider = StreamProvider.autoDispose<List<Liability>>((ref) => ref.watch(liabilityDaoProvider).watchAll(status: 'active'));

// ─── STREAMS: CATEGORIES ──────────────────────────────────────────────────────

final categoriesProvider = StreamProvider.autoDispose.family<List<Category>, String?>((ref, type) => ref.watch(categoryDaoProvider).watchAll(type: type));

// ─── STREAMS: ZAKAT ───────────────────────────────────────────────────────────

final zakatSnapshotsProvider = StreamProvider.autoDispose<List<ZakatSnapshot>>((ref) => ref.watch(zakatDaoProvider).watchAll());

// ─── STREAMS: SETTINGS ────────────────────────────────────────────────────────

final allSettingsProvider = StreamProvider.autoDispose<List<AppSetting>>((ref) => ref.watch(settingsDaoProvider).watchAll());

// ─── STREAMS: BC / COMMITTEE ──────────────────────────────────────────────────

final bcGroupsProvider = StreamProvider.autoDispose<List<BcGroup>>((ref) {
  return ref.watch(bcDaoProvider).watchAllGroups();
});

final bcMembersProvider = StreamProvider.autoDispose.family<List<BcMember>, int>((ref, groupId) {
  return ref.watch(bcDaoProvider).watchMembers(groupId);
});

final bcRoundsProvider = StreamProvider.autoDispose.family<List<BcRound>, int>((ref, groupId) {
  return ref.watch(bcDaoProvider).watchRounds(groupId);
});

final bcPaymentsForRoundProvider = StreamProvider.autoDispose.family<List<BcPayment>, int>((ref, roundId) {
  return ref.watch(bcDaoProvider).watchPaymentsForRound(roundId);
});

final bcGroupStatsProvider = FutureProvider.autoDispose.family<BcGroupStats, int>((ref, groupId) async {
  return ref.watch(bcDaoProvider).getGroupStats(groupId);
});

// ─── DASHBOARD SUMMARY ────────────────────────────────────────────────────────

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final txDao = ref.watch(transactionDaoProvider);
  final assetDao = ref.watch(assetDaoProvider);
  final liabilityDao = ref.watch(liabilityDaoProvider);
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
  final results = await Future.wait([
    txDao.getTotalIncome(from: monthStart, to: monthEnd),
    txDao.getTotalExpense(from: monthStart, to: monthEnd),
    assetDao.getTotalValue(),
    liabilityDao.getTotalLiabilities(),
  ]);
  return DashboardSummary(monthlyIncome: results[0], monthlyExpense: results[1], totalAssets: results[2], totalLiabilities: results[3]);
});

final zakatCalculationProvider = FutureProvider.autoDispose<ZakatCalculation>((ref) async {
  return ref.watch(zakatEngineProvider).calculate();
});

final yearlySummaryProvider = FutureProvider.autoDispose.family<List<MonthlySummary>, int>((ref, year) async {
  return ref.watch(transactionDaoProvider).getMonthlySummary(year);
});

// ─── FILTER MODELS ────────────────────────────────────────────────────────────

class TransactionFilter {
  final String? type;
  final String? categoryId;
  final DateTime? from;
  final DateTime? to;
  const TransactionFilter({this.type, this.categoryId, this.from, this.to});
  static const empty = TransactionFilter();
  TransactionFilter copyWith({String? type, String? categoryId, DateTime? from, DateTime? to}) =>
      TransactionFilter(type: type ?? this.type, categoryId: categoryId ?? this.categoryId, from: from ?? this.from, to: to ?? this.to);
  @override
  bool operator ==(Object other) =>
      other is TransactionFilter && type == other.type && categoryId == other.categoryId && from == other.from && to == other.to;
  @override
  int get hashCode => Object.hash(type, categoryId, from, to);
}

class MonthKey {
  final int year;
  final int month;
  const MonthKey(this.year, this.month);
  @override
  bool operator ==(Object other) => other is MonthKey && year == other.year && month == other.month;
  @override
  int get hashCode => Object.hash(year, month);
}

class DashboardSummary {
  final double monthlyIncome;
  final double monthlyExpense;
  final double totalAssets;
  final double totalLiabilities;
  double get monthlyNet => monthlyIncome - monthlyExpense;
  double get netWorth => totalAssets - totalLiabilities;
  const DashboardSummary({required this.monthlyIncome, required this.monthlyExpense, required this.totalAssets, required this.totalLiabilities});
}
