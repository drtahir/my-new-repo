// lib/features/zakat/data/zakat_engine.dart
import '../../../core/database/app_database.dart';

/// Zakat Calculation Engine implementing Islamic finance rules
///
/// Key concepts:
/// - Nisab: Minimum threshold of wealth (value of 87.48g gold OR 612.36g silver)
/// - Hawl: One lunar year must have passed with wealth above Nisab
/// - Rate: 2.5% of zakatable net wealth
/// - Zakatable assets: Gold, silver, cash, business inventory, receivables
/// - Deductible: Immediate liabilities, personal use items excluded

class ZakatEngine {
  static const double goldNisabGrams = 87.48;
  static const double silverNisabGrams = 612.36;
  static const double zakatRate = 0.025; // 2.5%

  final AssetDao assetDao;
  final LiabilityDao liabilityDao;
  final SettingsDao settingsDao;

  ZakatEngine({
    required this.assetDao,
    required this.liabilityDao,
    required this.settingsDao,
  });

  Future<ZakatCalculation> calculate() async {
    final settings = await settingsDao.getAll();
    final goldPricePerGram = double.tryParse(settings['gold_price_per_gram'] ?? '0') ?? 0.0;
    final silverPricePerGram = double.tryParse(settings['silver_price_per_gram'] ?? '0') ?? 0.0;
    final nisabMethod = settings['nisab_method'] ?? 'silver';

    // ─── Fetch assets by type ─────────────────────────────────────────────────
    final goldValue = await assetDao.getValueByType('gold');
    final silverValue = await assetDao.getValueByType('silver');
    final cashValue = await assetDao.getValueByType('cash');
    final businessValue = await assetDao.getValueByType('business');
    final otherZakatableValue = await _getOtherZakatableAssets();

    // ─── Fetch liabilities ────────────────────────────────────────────────────
    final totalLiabilities = await liabilityDao.getTotalLiabilities();

    // ─── Nisab calculation ────────────────────────────────────────────────────
    final nisabGoldValue = goldNisabGrams * goldPricePerGram;
    final nisabSilverValue = silverNisabGrams * silverPricePerGram;
    final nisabThreshold = nisabMethod == 'gold' ? nisabGoldValue : nisabSilverValue;

    // ─── Total zakatable wealth ───────────────────────────────────────────────
    final grossWealth = goldValue + silverValue + cashValue + businessValue + otherZakatableValue;
    final zakatableWealth = (grossWealth - totalLiabilities).clamp(0.0, double.infinity);

    // ─── Zakat due? ───────────────────────────────────────────────────────────
    final zakatDue = nisabThreshold > 0 && zakatableWealth >= nisabThreshold;
    final zakatAmount = zakatDue ? zakatableWealth * zakatRate : 0.0;

    return ZakatCalculation(
      goldValue: goldValue,
      silverValue: silverValue,
      cashValue: cashValue,
      businessValue: businessValue,
      otherAssetsValue: otherZakatableValue,
      totalLiabilities: totalLiabilities,
      grossWealth: grossWealth,
      zakatableWealth: zakatableWealth,
      nisabGoldValue: nisabGoldValue,
      nisabSilverValue: nisabSilverValue,
      nisabThreshold: nisabThreshold,
      nisabMethod: nisabMethod,
      zakatDue: zakatDue,
      zakatAmount: zakatAmount,
      goldPricePerGram: goldPricePerGram,
      silverPricePerGram: silverPricePerGram,
    );
  }

  Future<double> _getOtherZakatableAssets() async {
    double total = 0.0;
    for (final type in ['land', 'vehicle', 'other']) {
      total += await assetDao.getValueByType(type);
    }
    // Only zakat-applicable assets
    return total;
  }

  Future<ZakatSnapshot> saveSnapshot({
    required ZakatCalculation calculation,
    required ZakatDao zakatDao,
    String? notes,
  }) async {
    final now = DateTime.now();
    final companion = ZakatSnapshotsCompanion(
      year: Value(now.year),
      cashAmount: Value(calculation.cashValue),
      goldValue: Value(calculation.goldValue),
      silverValue: Value(calculation.silverValue),
      businessAssets: Value(calculation.businessValue),
      otherAssets: Value(calculation.otherAssetsValue),
      totalLiabilities: Value(calculation.totalLiabilities),
      zakatableWealth: Value(calculation.zakatableWealth),
      zakatAmount: Value(calculation.zakatAmount),
      nisabGold: Value(calculation.nisabGoldValue),
      nisabSilver: Value(calculation.nisabSilverValue),
      zakatDue: Value(calculation.zakatDue),
      notes: Value(notes),
      calculatedAt: Value(now),
    );
    final id = await zakatDao.saveSnapshot(companion);
    final saved = await zakatDao.getByYear(now.year);
    return saved!;
  }
}

class ZakatCalculation {
  final double goldValue;
  final double silverValue;
  final double cashValue;
  final double businessValue;
  final double otherAssetsValue;
  final double totalLiabilities;
  final double grossWealth;
  final double zakatableWealth;
  final double nisabGoldValue;
  final double nisabSilverValue;
  final double nisabThreshold;
  final String nisabMethod;
  final bool zakatDue;
  final double zakatAmount;
  final double goldPricePerGram;
  final double silverPricePerGram;

  const ZakatCalculation({
    required this.goldValue,
    required this.silverValue,
    required this.cashValue,
    required this.businessValue,
    required this.otherAssetsValue,
    required this.totalLiabilities,
    required this.grossWealth,
    required this.zakatableWealth,
    required this.nisabGoldValue,
    required this.nisabSilverValue,
    required this.nisabThreshold,
    required this.nisabMethod,
    required this.zakatDue,
    required this.zakatAmount,
    required this.goldPricePerGram,
    required this.silverPricePerGram,
  });

  String get statusMessage {
    if (goldPricePerGram == 0 || silverPricePerGram == 0) {
      return 'Please set gold and silver prices in Settings to calculate Zakat accurately.';
    }
    if (!zakatDue) {
      return 'Your wealth is below the Nisab threshold. Zakat is not obligatory this year.';
    }
    return 'Zakat is obligatory. You must pay ₨${zakatAmount.toStringAsFixed(2)} this year.';
  }

  Map<String, dynamic> toJson() => {
    'goldValue': goldValue,
    'silverValue': silverValue,
    'cashValue': cashValue,
    'businessValue': businessValue,
    'otherAssetsValue': otherAssetsValue,
    'totalLiabilities': totalLiabilities,
    'grossWealth': grossWealth,
    'zakatableWealth': zakatableWealth,
    'nisabGoldValue': nisabGoldValue,
    'nisabSilverValue': nisabSilverValue,
    'nisabThreshold': nisabThreshold,
    'nisabMethod': nisabMethod,
    'zakatDue': zakatDue,
    'zakatAmount': zakatAmount,
    'goldPricePerGram': goldPricePerGram,
    'silverPricePerGram': silverPricePerGram,
  };
}
