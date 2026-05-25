// lib/core/database/app_database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables/tables.dart';

part 'app_database.g.dart';

// ─── DATABASE ─────────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    Transactions,
    Categories,
    Assets,
    Liabilities,
    LiabilityPayments,
    ZakatSnapshots,
    AppSettings,
    // BC / Committee tables
    BcGroups,
    BcMembers,
    BcRounds,
    BcPayments,
  ],
  daos: [
    TransactionDao,
    CategoryDao,
    AssetDao,
    LiabilityDao,
    ZakatDao,
    SettingsDao,
    BcDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openDatabase());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _insertDefaultCategories();
          await _insertDefaultSettings();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Migrate from v1 → v2: add BC tables
            await m.createTable(bcGroups);
            await m.createTable(bcMembers);
            await m.createTable(bcRounds);
            await m.createTable(bcPayments);
          }
        },
      );

  static QueryExecutor _openDatabase() {
    return driftDatabase(name: 'family_finance.db');
  }

  Future<String> getDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'family_finance.db');
  }

  Future<void> _insertDefaultCategories() async {
    final defaults = [
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Salary', nameUrdu: const Value('تنخواہ'), type: 'income', icon: const Value('work'), color: const Value('#4CAF50'), isSystem: const Value(true)),
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Business', nameUrdu: const Value('کاروبار'), type: 'income', icon: const Value('business'), color: const Value('#2196F3'), isSystem: const Value(true)),
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Investment', nameUrdu: const Value('سرمایہ کاری'), type: 'income', icon: const Value('trending_up'), color: const Value('#9C27B0'), isSystem: const Value(true)),
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Rental Income', nameUrdu: const Value('کرایہ'), type: 'income', icon: const Value('home'), color: const Value('#FF9800'), isSystem: const Value(true)),
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Freelance', nameUrdu: const Value('فری لانس'), type: 'income', icon: const Value('computer'), color: const Value('#00BCD4'), isSystem: const Value(true)),
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Gift', nameUrdu: const Value('تحفہ'), type: 'income', icon: const Value('card_giftcard'), color: const Value('#E91E63'), isSystem: const Value(true)),
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Other Income', nameUrdu: const Value('دیگر آمدن'), type: 'income', icon: const Value('attach_money'), color: const Value('#607D8B'), isSystem: const Value(true)),
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Food & Groceries', nameUrdu: const Value('کھانا'), type: 'expense', icon: const Value('restaurant'), color: const Value('#F44336'), isSystem: const Value(true)),
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Rent / Mortgage', nameUrdu: const Value('کرایہ'), type: 'expense', icon: const Value('house'), color: const Value('#9C27B0'), isSystem: const Value(true)),
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Utilities', nameUrdu: const Value('بجلی پانی'), type: 'expense', icon: const Value('bolt'), color: const Value('#FF9800'), isSystem: const Value(true)),
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Transport', nameUrdu: const Value('سفر'), type: 'expense', icon: const Value('directions_car'), color: const Value('#2196F3'), isSystem: const Value(true)),
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Healthcare', nameUrdu: const Value('صحت'), type: 'expense', icon: const Value('local_hospital'), color: const Value('#E91E63'), isSystem: const Value(true)),
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Education', nameUrdu: const Value('تعلیم'), type: 'expense', icon: const Value('school'), color: const Value('#4CAF50'), isSystem: const Value(true)),
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Clothing', nameUrdu: const Value('کپڑے'), type: 'expense', icon: const Value('checkroom'), color: const Value('#00BCD4'), isSystem: const Value(true)),
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Entertainment', nameUrdu: const Value('تفریح'), type: 'expense', icon: const Value('movie'), color: const Value('#607D8B'), isSystem: const Value(true)),
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Zakat / Charity', nameUrdu: const Value('زکوٰۃ / صدقہ'), type: 'expense', icon: const Value('volunteer_activism'), color: const Value('#795548'), isSystem: const Value(true)),
      CategoriesCompanion.insert(uuid: _uuid(), name: 'Other Expense', nameUrdu: const Value('دیگر اخراجات'), type: 'expense', icon: const Value('more_horiz'), color: const Value('#9E9E9E'), isSystem: const Value(true)),
    ];
    for (final cat in defaults) {
      await into(categories).insertOnConflictUpdate(cat);
    }
  }

  Future<void> _insertDefaultSettings() async {
    final defaults = {
      'currency': 'PKR',
      'currency_symbol': '₨',
      'language': 'en',
      'pin_enabled': 'false',
      'biometric_enabled': 'false',
      'gold_price_per_gram': '0',
      'silver_price_per_gram': '0',
      'nisab_method': 'silver',
      'theme_mode': 'system',
      'backup_frequency': 'weekly',
      'last_backup': '',
    };
    for (final entry in defaults.entries) {
      await into(appSettings).insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: entry.key, value: entry.value),
      );
    }
  }

  static String _uuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(
      RegExp(r'[xy]'),
      (m) {
        final r = (now + m.start * 16) % 16;
        return m.group(0) == 'x' ? r.toRadixString(16) : (r & 0x3 | 0x8).toRadixString(16);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DAO: TRANSACTIONS
// ═══════════════════════════════════════════════════════════════════════════════

@DriftAccessor(tables: [Transactions, Categories])
class TransactionDao extends DatabaseAccessor<AppDatabase> with _$TransactionDaoMixin {
  TransactionDao(super.db);

  Stream<List<Transaction>> watchAll({String? type, String? categoryId, DateTime? from, DateTime? to, int limit = 100, int offset = 0}) {
    final query = select(transactions)..where((t) => t.isDeleted.equals(false));
    if (type != null) query.where((t) => t.type.equals(type));
    if (categoryId != null) query.where((t) => t.categoryId.equals(categoryId));
    if (from != null) query.where((t) => t.transactionDate.isBiggerOrEqualValue(from));
    if (to != null) query.where((t) => t.transactionDate.isSmallerOrEqualValue(to));
    query..orderBy([(t) => OrderingTerm.desc(t.transactionDate)])..limit(limit, offset: offset);
    return query.watch();
  }

  Stream<List<Transaction>> watchByMonth(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1).subtract(const Duration(milliseconds: 1));
    return watchAll(from: start, to: end, limit: 500);
  }

  Stream<List<Transaction>> watchToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    return watchAll(from: start, to: end, limit: 200);
  }

  Future<double> getTotalIncome({DateTime? from, DateTime? to}) async {
    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(transactions.isDeleted.equals(false) & transactions.type.equals('income'));
    if (from != null) query.where(transactions.transactionDate.isBiggerOrEqualValue(from));
    if (to != null) query.where(transactions.transactionDate.isSmallerOrEqualValue(to));
    final result = await query.getSingle();
    return result.read(transactions.amount.sum()) ?? 0.0;
  }

  Future<double> getTotalExpense({DateTime? from, DateTime? to}) async {
    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(transactions.isDeleted.equals(false) & transactions.type.equals('expense'));
    if (from != null) query.where(transactions.transactionDate.isBiggerOrEqualValue(from));
    if (to != null) query.where(transactions.transactionDate.isSmallerOrEqualValue(to));
    final result = await query.getSingle();
    return result.read(transactions.amount.sum()) ?? 0.0;
  }

  Future<List<MonthlySummary>> getMonthlySummary(int year) async {
    final results = <MonthlySummary>[];
    for (int month = 1; month <= 12; month++) {
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 1).subtract(const Duration(milliseconds: 1));
      final income = await getTotalIncome(from: start, to: end);
      final expense = await getTotalExpense(from: start, to: end);
      results.add(MonthlySummary(month: month, income: income, expense: expense));
    }
    return results;
  }

  Future<List<CategoryBreakdown>> getCategoryBreakdown({required String type, DateTime? from, DateTime? to}) async {
    final query = selectOnly(transactions)
      ..addColumns([transactions.categoryId, transactions.amount.sum()])
      ..where(transactions.isDeleted.equals(false) & transactions.type.equals(type))
      ..groupBy([transactions.categoryId]);
    if (from != null) query.where(transactions.transactionDate.isBiggerOrEqualValue(from));
    if (to != null) query.where(transactions.transactionDate.isSmallerOrEqualValue(to));
    final rows = await query.get();
    return rows.map((r) => CategoryBreakdown(categoryId: r.read(transactions.categoryId)!, amount: r.read(transactions.amount.sum()) ?? 0.0)).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  Future<Transaction> getById(int id) => (select(transactions)..where((t) => t.id.equals(id))).getSingle();
  Future<int> insertTransaction(TransactionsCompanion entry) => into(transactions).insert(entry);
  Future<bool> updateTransaction(TransactionsCompanion entry) => update(transactions).replace(entry);
  Future<void> softDelete(int id) async {
    await (update(transactions)..where((t) => t.id.equals(id))).write(const TransactionsCompanion(isDeleted: Value(true)));
  }
  Future<List<Transaction>> getAllForExport() => (select(transactions)..where((t) => t.isDeleted.equals(false))).get();
}

// ═══════════════════════════════════════════════════════════════════════════════
// DAO: CATEGORIES
// ═══════════════════════════════════════════════════════════════════════════════

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase> with _$CategoryDaoMixin {
  CategoryDao(super.db);
  Stream<List<Category>> watchAll({String? type}) {
    final query = select(categories)..where((c) => c.isActive.equals(true));
    if (type != null && type != 'both') query.where((c) => c.type.equals(type) | c.type.equals('both'));
    query.orderBy([(c) => OrderingTerm.asc(c.name)]);
    return query.watch();
  }
  Future<List<Category>> getAll({String? type}) async {
    final query = select(categories)..where((c) => c.isActive.equals(true));
    if (type != null && type != 'both') query.where((c) => c.type.equals(type) | c.type.equals('both'));
    return query.get();
  }
  Future<Category?> getById(int id) => (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();
  Future<Category?> getByUuid(String uuid) => (select(categories)..where((c) => c.uuid.equals(uuid))).getSingleOrNull();
  Future<int> insertCategory(CategoriesCompanion entry) => into(categories).insert(entry);
  Future<bool> updateCategory(CategoriesCompanion entry) => update(categories).replace(entry);
}

// ═══════════════════════════════════════════════════════════════════════════════
// DAO: ASSETS
// ═══════════════════════════════════════════════════════════════════════════════

@DriftAccessor(tables: [Assets])
class AssetDao extends DatabaseAccessor<AppDatabase> with _$AssetDaoMixin {
  AssetDao(super.db);
  Stream<List<Asset>> watchAll({String? type}) {
    final query = select(assets)..where((a) => a.isDeleted.equals(false));
    if (type != null) query.where((a) => a.type.equals(type));
    query.orderBy([(a) => OrderingTerm.desc(a.currentValue)]);
    return query.watch();
  }
  Future<double> getTotalValue() async {
    final query = selectOnly(assets)..addColumns([assets.currentValue.sum()])..where(assets.isDeleted.equals(false));
    final result = await query.getSingle();
    return result.read(assets.currentValue.sum()) ?? 0.0;
  }
  Future<double> getZakatableValue() async {
    final query = selectOnly(assets)..addColumns([assets.currentValue.sum()])..where(assets.isDeleted.equals(false) & assets.isZakatApplicable.equals(true));
    final result = await query.getSingle();
    return result.read(assets.currentValue.sum()) ?? 0.0;
  }
  Future<double> getValueByType(String type) async {
    final query = selectOnly(assets)..addColumns([assets.currentValue.sum()])..where(assets.isDeleted.equals(false) & assets.type.equals(type));
    final result = await query.getSingle();
    return result.read(assets.currentValue.sum()) ?? 0.0;
  }
  Future<Asset?> getById(int id) => (select(assets)..where((a) => a.id.equals(id))).getSingleOrNull();
  Future<int> insertAsset(AssetsCompanion entry) => into(assets).insert(entry);
  Future<bool> updateAsset(AssetsCompanion entry) => update(assets).replace(entry);
  Future<void> softDelete(int id) async {
    await (update(assets)..where((a) => a.id.equals(id))).write(const AssetsCompanion(isDeleted: Value(true)));
  }
  Future<List<Asset>> getAllForExport() => (select(assets)..where((a) => a.isDeleted.equals(false))).get();
}

// ═══════════════════════════════════════════════════════════════════════════════
// DAO: LIABILITIES
// ═══════════════════════════════════════════════════════════════════════════════

@DriftAccessor(tables: [Liabilities, LiabilityPayments])
class LiabilityDao extends DatabaseAccessor<AppDatabase> with _$LiabilityDaoMixin {
  LiabilityDao(super.db);
  Stream<List<Liability>> watchAll({String? type, String? status}) {
    final query = select(liabilities)..where((l) => l.isDeleted.equals(false));
    if (type != null) query.where((l) => l.type.equals(type));
    if (status != null) query.where((l) => l.status.equals(status));
    query.orderBy([(l) => OrderingTerm.desc(l.createdAt)]);
    return query.watch();
  }
  Future<double> getTotalLiabilities() async {
    final query = selectOnly(liabilities)..addColumns([liabilities.remainingAmount.sum()])..where(liabilities.isDeleted.equals(false) & liabilities.status.equals('active'));
    final result = await query.getSingle();
    return result.read(liabilities.remainingAmount.sum()) ?? 0.0;
  }
  Future<Liability?> getById(int id) => (select(liabilities)..where((l) => l.id.equals(id))).getSingleOrNull();
  Future<int> insertLiability(LiabilitiesCompanion entry) => into(liabilities).insert(entry);
  Future<bool> updateLiability(LiabilitiesCompanion entry) => update(liabilities).replace(entry);
  Future<void> softDelete(int id) async {
    await (update(liabilities)..where((l) => l.id.equals(id))).write(const LiabilitiesCompanion(isDeleted: Value(true)));
  }
  Stream<List<LiabilityPayment>> watchPayments(int liabilityId) =>
      (select(liabilityPayments)..where((p) => p.liabilityId.equals(liabilityId))..orderBy([(p) => OrderingTerm.desc(p.paymentDate)])).watch();
  Future<int> addPayment(LiabilityPaymentsCompanion entry) async {
    final id = await into(liabilityPayments).insert(entry);
    final liability = await getById(entry.liabilityId.value);
    if (liability != null) {
      final newRemaining = (liability.remainingAmount - entry.amount.value).clamp(0.0, double.infinity);
      final newStatus = newRemaining <= 0 ? 'paid' : 'active';
      await updateLiability(liability.toCompanion(true).copyWith(remainingAmount: Value(newRemaining), status: Value(newStatus), updatedAt: Value(DateTime.now())));
    }
    return id;
  }
  Future<List<Liability>> getAllForExport() => (select(liabilities)..where((l) => l.isDeleted.equals(false))).get();
}

// ═══════════════════════════════════════════════════════════════════════════════
// DAO: ZAKAT
// ═══════════════════════════════════════════════════════════════════════════════

@DriftAccessor(tables: [ZakatSnapshots])
class ZakatDao extends DatabaseAccessor<AppDatabase> with _$ZakatDaoMixin {
  ZakatDao(super.db);
  Stream<List<ZakatSnapshot>> watchAll() => (select(zakatSnapshots)..orderBy([(z) => OrderingTerm.desc(z.year)])).watch();
  Future<ZakatSnapshot?> getByYear(int year) => (select(zakatSnapshots)..where((z) => z.year.equals(year))).getSingleOrNull();
  Future<int> saveSnapshot(ZakatSnapshotsCompanion entry) async {
    final existing = await getByYear(entry.year.value);
    if (existing != null) {
      await (update(zakatSnapshots)..where((z) => z.year.equals(entry.year.value))).write(entry);
      return existing.id;
    }
    return into(zakatSnapshots).insert(entry);
  }
  Future<List<ZakatSnapshot>> getAllForExport() => select(zakatSnapshots).get();
}

// ═══════════════════════════════════════════════════════════════════════════════
// DAO: SETTINGS
// ═══════════════════════════════════════════════════════════════════════════════

@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);
  Stream<List<AppSetting>> watchAll() => select(appSettings).watch();
  Future<String?> get(String key) async {
    final row = await (select(appSettings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }
  Future<void> set(String key, String value) async {
    await into(appSettings).insertOnConflictUpdate(AppSettingsCompanion(key: Value(key), value: Value(value), updatedAt: Value(DateTime.now())));
  }
  Future<Map<String, String>> getAll() async {
    final rows = await select(appSettings).get();
    return {for (final r in rows) r.key: r.value};
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DAO: BC / COMMITTEE
// ═══════════════════════════════════════════════════════════════════════════════

@DriftAccessor(tables: [BcGroups, BcMembers, BcRounds, BcPayments])
class BcDao extends DatabaseAccessor<AppDatabase> with _$BcDaoMixin {
  BcDao(super.db);

  // ── GROUPS ──────────────────────────────────────────────────────────────────

  Stream<List<BcGroup>> watchAllGroups() {
    return (select(bcGroups)
          ..where((g) => g.isDeleted.equals(false))
          ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
        .watch();
  }

  Future<BcGroup?> getGroupById(int id) =>
      (select(bcGroups)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<int> insertGroup(BcGroupsCompanion entry) => into(bcGroups).insert(entry);

  Future<bool> updateGroup(BcGroupsCompanion entry) => update(bcGroups).replace(entry);

  Future<void> softDeleteGroup(int id) async {
    await (update(bcGroups)..where((g) => g.id.equals(id)))
        .write(const BcGroupsCompanion(isDeleted: Value(true)));
  }

  // ── MEMBERS ─────────────────────────────────────────────────────────────────

  Stream<List<BcMember>> watchMembers(int groupId) {
    return (select(bcMembers)
          ..where((m) => m.bcGroupId.equals(groupId) & m.isActive.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.slotNumber)]))
        .watch();
  }

  Future<List<BcMember>> getMembersByGroup(int groupId) {
    return (select(bcMembers)
          ..where((m) => m.bcGroupId.equals(groupId) & m.isActive.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.slotNumber)]))
        .get();
  }

  Future<BcMember?> getMemberById(int id) =>
      (select(bcMembers)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<int> insertMember(BcMembersCompanion entry) => into(bcMembers).insert(entry);
  Future<bool> updateMember(BcMembersCompanion entry) => update(bcMembers).replace(entry);
  Future<void> deactivateMember(int id) async {
    await (update(bcMembers)..where((m) => m.id.equals(id)))
        .write(const BcMembersCompanion(isActive: Value(false)));
  }

  // ── ROUNDS ──────────────────────────────────────────────────────────────────

  Stream<List<BcRound>> watchRounds(int groupId) {
    return (select(bcRounds)
          ..where((r) => r.bcGroupId.equals(groupId))
          ..orderBy([(r) => OrderingTerm.asc(r.roundNumber)]))
        .watch();
  }

  Future<List<BcRound>> getRoundsByGroup(int groupId) {
    return (select(bcRounds)
          ..where((r) => r.bcGroupId.equals(groupId))
          ..orderBy([(r) => OrderingTerm.asc(r.roundNumber)]))
        .get();
  }

  Future<BcRound?> getRoundById(int id) =>
      (select(bcRounds)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<int> insertRound(BcRoundsCompanion entry) => into(bcRounds).insert(entry);

  Future<void> setRoundWinner(int roundId, int memberId, String memberName) async {
    await (update(bcRounds)..where((r) => r.id.equals(roundId))).write(
      BcRoundsCompanion(
        winnerMemberId: Value(memberId),
        winnerName: Value(memberName),
        status: const Value('drawn'),
        drawDate: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markRoundPaidOut(int roundId) async {
    await (update(bcRounds)..where((r) => r.id.equals(roundId)))
        .write(const BcRoundsCompanion(status: Value('paid_out')));
  }

  Future<void> updateRoundTotal(int roundId, double total) async {
    await (update(bcRounds)..where((r) => r.id.equals(roundId)))
        .write(BcRoundsCompanion(totalCollected: Value(total)));
  }

  // ── PAYMENTS ────────────────────────────────────────────────────────────────

  Stream<List<BcPayment>> watchPaymentsForRound(int roundId) {
    return (select(bcPayments)
          ..where((p) => p.bcRoundId.equals(roundId))
          ..orderBy([(p) => OrderingTerm.asc(p.memberName)]))
        .watch();
  }

  Future<List<BcPayment>> getPaymentsForRound(int roundId) {
    return (select(bcPayments)..where((p) => p.bcRoundId.equals(roundId))).get();
  }

  Future<List<BcPayment>> getAllPaymentsForGroup(int groupId) {
    return (select(bcPayments)..where((p) => p.bcGroupId.equals(groupId))).get();
  }

  Future<int> insertPayment(BcPaymentsCompanion entry) => into(bcPayments).insert(entry);

  Future<void> markPaymentPaid(int paymentId) async {
    await (update(bcPayments)..where((p) => p.id.equals(paymentId))).write(
      BcPaymentsCompanion(status: const Value('paid'), paidAt: Value(DateTime.now())),
    );
  }

  Future<void> markPaymentPending(int paymentId) async {
    await (update(bcPayments)..where((p) => p.id.equals(paymentId))).write(
      const BcPaymentsCompanion(status: Value('pending'), paidAt: Value(null)),
    );
  }

  // ── BULK / COMPOSITE OPERATIONS ─────────────────────────────────────────────

  /// Creates all rounds + payment slots when a new BC group is saved
  Future<void> initializeGroupData({
    required int groupId,
    required int totalSlots,
    required String frequency,
    required DateTime startDate,
    required List<BcMember> members,
    required double contributionAmount,
  }) async {
    for (int i = 1; i <= totalSlots; i++) {
      DateTime scheduledDate;
      switch (frequency) {
        case 'weekly':
          scheduledDate = startDate.add(Duration(days: 7 * (i - 1)));
          break;
        case 'biweekly':
          scheduledDate = startDate.add(Duration(days: 14 * (i - 1)));
          break;
        default: // monthly
          scheduledDate = DateTime(startDate.year, startDate.month + i - 1, startDate.day);
      }

      final label = switch (frequency) {
        'weekly' => 'Week $i',
        'biweekly' => 'Bi-Week $i',
        _ => 'Month $i',
      };

      final roundId = await into(bcRounds).insert(BcRoundsCompanion.insert(
        bcGroupId: groupId,
        roundNumber: i,
        label: label,
        scheduledDate: Value(scheduledDate),
      ));

      for (final member in members) {
        await into(bcPayments).insert(BcPaymentsCompanion.insert(
          bcGroupId: groupId,
          bcRoundId: roundId,
          bcMemberId: member.id,
          memberName: member.name,
          amount: contributionAmount,
        ));
      }
    }
  }

  /// Returns members who haven't yet won a draw in this group
  Future<List<BcMember>> getEligibleDrawMembers(int groupId) async {
    final rounds = await getRoundsByGroup(groupId);
    final winnerIds = rounds
        .where((r) => r.winnerMemberId != null)
        .map((r) => r.winnerMemberId!)
        .toSet();
    final allMembers = await getMembersByGroup(groupId);
    return allMembers.where((m) => !winnerIds.contains(m.id)).toList();
  }

  /// Aggregated stats for a BC group
  Future<BcGroupStats> getGroupStats(int groupId) async {
    final members = await getMembersByGroup(groupId);
    final rounds = await getRoundsByGroup(groupId);
    final payments = await getAllPaymentsForGroup(groupId);

    final drawn = rounds.where((r) => r.status != 'pending').length;
    final collected = payments.where((p) => p.status == 'paid').fold(0.0, (s, p) => s + p.amount);
    final pending = payments.where((p) => p.status == 'pending').fold(0.0, (s, p) => s + p.amount);

    return BcGroupStats(
      totalMembers: members.length,
      totalRounds: rounds.length,
      drawnRounds: drawn,
      totalCollected: collected,
      totalPending: pending,
    );
  }
}

// ─── DATA CLASSES ─────────────────────────────────────────────────────────────

class MonthlySummary {
  final int month;
  final double income;
  final double expense;
  double get net => income - expense;
  MonthlySummary({required this.month, required this.income, required this.expense});
}

class CategoryBreakdown {
  final String categoryId;
  final double amount;
  CategoryBreakdown({required this.categoryId, required this.amount});
}

class BcGroupStats {
  final int totalMembers;
  final int totalRounds;
  final int drawnRounds;
  final double totalCollected;
  final double totalPending;

  BcGroupStats({
    required this.totalMembers,
    required this.totalRounds,
    required this.drawnRounds,
    required this.totalCollected,
    required this.totalPending,
  });
}
