// lib/core/utils/constants.dart
import 'package:flutter/material.dart';

class AppConstants {
  // ─── Asset Types ───────────────────────────────────────────────────────────
  static const List<String> assetTypes = [
    'gold', 'silver', 'cash', 'land', 'business', 'vehicle', 'other',
  ];

  static const Map<String, String> assetTypeLabels = {
    'gold': 'Gold',
    'silver': 'Silver',
    'cash': 'Cash & Savings',
    'land': 'Land & Property',
    'business': 'Business Assets',
    'vehicle': 'Vehicle',
    'other': 'Other Asset',
  };

  static const Map<String, String> assetTypeIcons = {
    'gold': '🥇',
    'silver': '🥈',
    'cash': '💵',
    'land': '🏠',
    'business': '🏢',
    'vehicle': '🚗',
    'other': '📦',
  };

  // ─── Liability Types ───────────────────────────────────────────────────────
  static const List<String> liabilityTypes = [
    'loan_taken', 'loan_given', 'committee', 'debt',
  ];

  static const Map<String, String> liabilityTypeLabels = {
    'loan_taken': 'Loan Taken',
    'loan_given': 'Loan Given',
    'committee': 'Committee',
    'debt': 'Debt',
  };

  static const Map<String, String> liabilityTypeIcons = {
    'loan_taken': '🏦',
    'loan_given': '🤝',
    'committee': '👥',
    'debt': '📋',
  };

  // ─── Payment Methods ───────────────────────────────────────────────────────
  static const List<String> paymentMethods = ['cash', 'bank', 'mobile_wallet'];

  static const Map<String, String> paymentMethodLabels = {
    'cash': 'Cash',
    'bank': 'Bank Transfer',
    'mobile_wallet': 'Mobile Wallet',
  };

  static const Map<String, IconData> paymentMethodIconData = {
    'cash': Icons.money,
    'bank': Icons.account_balance,
    'mobile_wallet': Icons.phone_android,
  };

  // ─── Currencies ────────────────────────────────────────────────────────────
  static const List<Map<String, String>> currencies = [
    {'code': 'PKR', 'symbol': '₨', 'name': 'Pakistani Rupee'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
    {'code': 'SAR', 'symbol': '﷼', 'name': 'Saudi Riyal'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
  ];

  // ─── Zakat ─────────────────────────────────────────────────────────────────
  static const double goldNisabGrams   = 87.48;
  static const double silverNisabGrams = 612.36;
  static const double zakatRate        = 0.025; // 2.5%

  // ─── App Info ──────────────────────────────────────────────────────────────
  static const String appName    = 'Family Finance & Zakat';
  static const String appVersion = '1.0.0';
  static const String dbName     = 'family_finance.db';
}

// ─── App Validators ────────────────────────────────────────────────────────────

class AppValidators {
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) return 'Amount is required';
    final parsed = double.tryParse(value.replaceAll(',', ''));
    if (parsed == null) return 'Enter a valid number';
    if (parsed <= 0) return 'Amount must be greater than 0';
    if (parsed > 999999999999) return 'Amount is too large';
    return null;
  }

  static String? pin(String? value) {
    if (value == null || value.isEmpty) return 'PIN is required';
    if (value.length < 4 || value.length > 6) return 'PIN must be 4–6 digits';
    if (!RegExp(r'^\d+$').hasMatch(value)) return 'PIN must contain only numbers';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    if (!RegExp(r'^03\d{9}$').hasMatch(value.trim())) {
      return 'Enter a valid Pakistani number (03XXXXXXXXX)';
    }
    return null;
  }

  static String? positiveNumber(String? value, {String fieldName = 'Value'}) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final parsed = double.tryParse(value);
    if (parsed == null) return '$fieldName must be a number';
    if (parsed < 0) return '$fieldName cannot be negative';
    return null;
  }
}
