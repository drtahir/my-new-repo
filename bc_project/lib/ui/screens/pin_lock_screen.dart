// lib/ui/screens/pin_lock_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/security/auth_service.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;
  const PinLockScreen({super.key, required this.onUnlocked});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  String _enteredPin = '';
  String? _errorMessage;
  bool _isLocked = false;
  Duration? _lockoutDuration;
  bool _checkingBiometric = false;

  static const int _pinLength = 4;

  @override
  void initState() {
    super.initState();
    _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    final auth = ref.read(authServiceProvider);
    final biometricEnabled = await auth.isBiometricEnabled;
    if (!biometricEnabled || !mounted) return;

    setState(() => _checkingBiometric = true);
    final result = await auth.authenticateWithBiometric();
    if (!mounted) return;
    setState(() => _checkingBiometric = false);

    if (result.isSuccess) {
      widget.onUnlocked();
    }
  }

  void _appendDigit(String digit) {
    if (_isLocked || _enteredPin.length >= _pinLength) return;
    setState(() {
      _enteredPin += digit;
      _errorMessage = null;
    });
    if (_enteredPin.length == _pinLength) _verifyPin();
  }

  void _deleteDigit() {
    if (_enteredPin.isEmpty) return;
    setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
  }

  Future<void> _verifyPin() async {
    final auth = ref.read(authServiceProvider);
    final result = await auth.verifyPin(_enteredPin);

    if (!mounted) return;

    if (result.isSuccess) {
      widget.onUnlocked();
      return;
    }

    switch (result.status) {
      case PinAuthStatus.wrongPin:
        setState(() {
          _enteredPin = '';
          _errorMessage = 'Wrong PIN. ${result.remainingAttempts} attempt${result.remainingAttempts == 1 ? '' : 's'} remaining.';
        });
        break;
      case PinAuthStatus.lockedOut:
        setState(() {
          _enteredPin = '';
          _isLocked = true;
          _lockoutDuration = result.lockoutDuration;
          _errorMessage = 'Too many attempts. Locked for ${result.lockoutDuration!.inMinutes} minutes.';
        });
        // Auto unlock after duration
        Future.delayed(result.lockoutDuration!, () {
          if (mounted) setState(() { _isLocked = false; _lockoutDuration = null; _errorMessage = null; });
        });
        break;
      default:
        setState(() { _enteredPin = ''; _errorMessage = 'An error occurred.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // App logo / name
            const Icon(Icons.account_balance_wallet, size: 60, color: Colors.white),
            const SizedBox(height: 12),
            const Text('Family Finance', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const Text('Enter PIN to continue', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 40),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _enteredPin.length ? Colors.white : Colors.white30,
                    border: Border.all(color: Colors.white54, width: 1.5),
                  ),
                ),
              )),
            ),
            const SizedBox(height: 16),

            // Error message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 13), textAlign: TextAlign.center),
                ),
              ),

            // Biometric indicator
            if (_checkingBiometric)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Checking biometric...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),

            const Spacer(),

            // Number pad
            if (!_isLocked)
              _NumberPad(onDigit: _appendDigit, onDelete: _deleteDigit, onBiometric: _tryBiometric),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  final Function(String) onDigit;
  final VoidCallback onDelete;
  final VoidCallback onBiometric;

  const _NumberPad({required this.onDigit, required this.onDelete, required this.onBiometric});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _PadRow(['1', '2', '3'], onDigit),
          const SizedBox(height: 12),
          _PadRow(['4', '5', '6'], onDigit),
          const SizedBox(height: 12),
          _PadRow(['7', '8', '9'], onDigit),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PadAction(icon: Icons.fingerprint, onTap: onBiometric),
              _PadDigit('0', onDigit),
              _PadAction(icon: Icons.backspace_outlined, onTap: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

class _PadRow extends StatelessWidget {
  final List<String> digits;
  final Function(String) onDigit;

  const _PadRow(this.digits, this.onDigit);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _PadDigit(d, onDigit)).toList(),
    );
  }
}

class _PadDigit extends StatelessWidget {
  final String digit;
  final Function(String) onDigit;

  const _PadDigit(this.digit, this.onDigit);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: () => onDigit(digit),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Text(digit, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

class _PadAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PadAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Icon(icon, color: Colors.white70, size: 28),
        ),
      ),
    );
  }
}
