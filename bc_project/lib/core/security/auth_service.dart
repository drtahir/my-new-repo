// lib/core/security/auth_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AuthService {
  static const _pinKey = 'ff_pin_hash';
  static const _pinEnabledKey = 'ff_pin_enabled';
  static const _biometricEnabledKey = 'ff_biometric_enabled';
  static const _failedAttemptsKey = 'ff_failed_attempts';
  static const _lockoutTimeKey = 'ff_lockout_time';
  static const _maxAttempts = 5;
  static const _lockoutDuration = Duration(minutes: 5);

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  AuthService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        ),
        _localAuth = LocalAuthentication();

  // ─── PIN MANAGEMENT ────────────────────────────────────────────────────────

  Future<bool> get isPinEnabled async {
    final val = await _storage.read(key: _pinEnabledKey);
    return val == 'true';
  }

  Future<bool> get isBiometricEnabled async {
    final val = await _storage.read(key: _biometricEnabledKey);
    return val == 'true';
  }

  Future<bool> get isBiometricAvailable async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    final hash = _hashPin(pin);
    await _storage.write(key: _pinKey, value: hash);
    await _storage.write(key: _pinEnabledKey, value: 'true');
    await _resetFailedAttempts();
  }

  Future<void> removePin() async {
    await _storage.delete(key: _pinKey);
    await _storage.write(key: _pinEnabledKey, value: 'false');
    await _storage.write(key: _biometricEnabledKey, value: 'false');
    await _resetFailedAttempts();
  }

  Future<PinAuthResult> verifyPin(String pin) async {
    // Check lockout
    final lockoutResult = await _checkLockout();
    if (lockoutResult != null) return lockoutResult;

    final storedHash = await _storage.read(key: _pinKey);
    if (storedHash == null) return PinAuthResult.error('PIN not set');

    if (_hashPin(pin) == storedHash) {
      await _resetFailedAttempts();
      return PinAuthResult.success();
    } else {
      await _incrementFailedAttempts();
      final remaining = await _getRemainingAttempts();
      if (remaining <= 0) {
        await _setLockout();
        return PinAuthResult.lockedOut(_lockoutDuration);
      }
      return PinAuthResult.wrongPin(remaining);
    }
  }

  Future<void> enableBiometric() async {
    await _storage.write(key: _biometricEnabledKey, value: 'true');
  }

  Future<void> disableBiometric() async {
    await _storage.write(key: _biometricEnabledKey, value: 'false');
  }

  // ─── BIOMETRIC AUTH ────────────────────────────────────────────────────────

  Future<BiometricAuthResult> authenticateWithBiometric() async {
    try {
      final available = await isBiometricAvailable;
      if (!available) return BiometricAuthResult.notAvailable();

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Family Finance',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      return authenticated
          ? BiometricAuthResult.success()
          : BiometricAuthResult.failed();
    } catch (e) {
      return BiometricAuthResult.error(e.toString());
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  // ─── PRIVATE ───────────────────────────────────────────────────────────────

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin + 'ff_salt_2024');
    return sha256.convert(bytes).toString();
  }

  Future<PinAuthResult?> _checkLockout() async {
    final lockoutTimeStr = await _storage.read(key: _lockoutTimeKey);
    if (lockoutTimeStr == null) return null;

    final lockoutTime = DateTime.tryParse(lockoutTimeStr);
    if (lockoutTime == null) return null;

    final unlockTime = lockoutTime.add(_lockoutDuration);
    if (DateTime.now().isBefore(unlockTime)) {
      final remaining = unlockTime.difference(DateTime.now());
      return PinAuthResult.lockedOut(remaining);
    }

    await _resetFailedAttempts();
    return null;
  }

  Future<void> _incrementFailedAttempts() async {
    final current = await _getFailedAttempts();
    await _storage.write(key: _failedAttemptsKey, value: '${current + 1}');
  }

  Future<void> _resetFailedAttempts() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockoutTimeKey);
  }

  Future<void> _setLockout() async {
    await _storage.write(key: _lockoutTimeKey, value: DateTime.now().toIso8601String());
  }

  Future<int> _getFailedAttempts() async {
    final val = await _storage.read(key: _failedAttemptsKey);
    return int.tryParse(val ?? '0') ?? 0;
  }

  Future<int> _getRemainingAttempts() async {
    final failed = await _getFailedAttempts();
    return _maxAttempts - failed;
  }
}

// ─── RESULT TYPES ─────────────────────────────────────────────────────────────

enum PinAuthStatus { success, wrongPin, lockedOut, error }

class PinAuthResult {
  final PinAuthStatus status;
  final int? remainingAttempts;
  final Duration? lockoutDuration;
  final String? errorMessage;

  const PinAuthResult._({
    required this.status,
    this.remainingAttempts,
    this.lockoutDuration,
    this.errorMessage,
  });

  factory PinAuthResult.success() =>
      const PinAuthResult._(status: PinAuthStatus.success);

  factory PinAuthResult.wrongPin(int remaining) => PinAuthResult._(
    status: PinAuthStatus.wrongPin,
    remainingAttempts: remaining,
  );

  factory PinAuthResult.lockedOut(Duration duration) => PinAuthResult._(
    status: PinAuthStatus.lockedOut,
    lockoutDuration: duration,
  );

  factory PinAuthResult.error(String msg) => PinAuthResult._(
    status: PinAuthStatus.error,
    errorMessage: msg,
  );

  bool get isSuccess => status == PinAuthStatus.success;
}

enum BiometricAuthStatus { success, failed, notAvailable, error }

class BiometricAuthResult {
  final BiometricAuthStatus status;
  final String? errorMessage;

  const BiometricAuthResult._({required this.status, this.errorMessage});

  factory BiometricAuthResult.success() =>
      const BiometricAuthResult._(status: BiometricAuthStatus.success);

  factory BiometricAuthResult.failed() =>
      const BiometricAuthResult._(status: BiometricAuthStatus.failed);

  factory BiometricAuthResult.notAvailable() =>
      const BiometricAuthResult._(status: BiometricAuthStatus.notAvailable);

  factory BiometricAuthResult.error(String msg) => BiometricAuthResult._(
    status: BiometricAuthStatus.error,
    errorMessage: msg,
  );

  bool get isSuccess => status == BiometricAuthStatus.success;
}
