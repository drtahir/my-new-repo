// lib/core/utils/validators.dart

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
    if (value == null || value.trim().isEmpty) return null;
    if (!RegExp(r'^03\d{9}$').hasMatch(value.trim())) {
      return 'Enter a valid Pakistani number (03XXXXXXXXX)';
    }
    return null;
  }

  static String? positiveNumber(String? value, {String fieldName = 'Value'}) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value);
    if (parsed == null) return '$fieldName must be a number';
    if (parsed < 0) return '$fieldName cannot be negative';
    return null;
  }
}
