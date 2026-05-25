// lib/ui/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../core/providers.dart';
import '../../core/backup/backup_service.dart';
import '../../core/security/auth_service.dart';
import '../../core/utils/formatters.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _isSignedInToDrive = false;
  String? _driveUser;
  bool _backupLoading = false;
  String _lastBackup = '';
  String _goldPrice = '0';
  String _silverPrice = '0';
  String _nisabMethod = 'silver';
  String _currency = 'PKR';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final auth = ref.read(authServiceProvider);
    final backup = ref.read(backupServiceProvider);
    final settings = ref.read(settingsDaoProvider);

    final results = await Future.wait([
      auth.isPinEnabled,
      auth.isBiometricEnabled,
      auth.isBiometricAvailable,
      backup.isSignedIn,
    ]);

    final allSettings = await settings.getAll();
    final user = await backup.currentUser;

    if (mounted) {
      setState(() {
        _pinEnabled = results[0] as bool;
        _biometricEnabled = results[1] as bool;
        _biometricAvailable = results[2] as bool;
        _isSignedInToDrive = results[3] as bool;
        _driveUser = user?.email;
        _goldPrice = allSettings['gold_price_per_gram'] ?? '0';
        _silverPrice = allSettings['silver_price_per_gram'] ?? '0';
        _nisabMethod = allSettings['nisab_method'] ?? 'silver';
        _currency = allSettings['currency'] ?? 'PKR';
        _lastBackup = allSettings['last_backup'] ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── ZAKAT SETTINGS ──────────────────────────────────────────────
          _SectionHeader(icon: Icons.volunteer_activism, title: 'Zakat Settings', color: Colors.teal),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Column(
              children: [
                _PriceField(
                  label: 'Gold Price (per gram)',
                  icon: '🥇',
                  value: _goldPrice,
                  onChanged: (v) async {
                    setState(() => _goldPrice = v);
                    await ref.read(settingsDaoProvider).set('gold_price_per_gram', v);
                    ref.invalidate(zakatCalculationProvider);
                  },
                ),
                const Divider(height: 1, indent: 16),
                _PriceField(
                  label: 'Silver Price (per gram)',
                  icon: '🥈',
                  value: _silverPrice,
                  onChanged: (v) async {
                    setState(() => _silverPrice = v);
                    await ref.read(settingsDaoProvider).set('silver_price_per_gram', v);
                    ref.invalidate(zakatCalculationProvider);
                  },
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  title: const Text('Nisab Method'),
                  subtitle: Text(_nisabMethod == 'gold' ? 'Gold (87.48g) — stricter' : 'Silver (612.36g) — more common'),
                  trailing: DropdownButton<String>(
                    value: _nisabMethod,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'silver', child: Text('Silver')),
                      DropdownMenuItem(value: 'gold', child: Text('Gold')),
                    ],
                    onChanged: (v) async {
                      setState(() => _nisabMethod = v!);
                      await ref.read(settingsDaoProvider).set('nisab_method', v!);
                      ref.invalidate(zakatCalculationProvider);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── SECURITY ────────────────────────────────────────────────────
          _SectionHeader(icon: Icons.security, title: 'Security', color: Colors.indigo),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('PIN Lock'),
                  subtitle: Text(_pinEnabled ? 'App locked with PIN' : 'No PIN set'),
                  secondary: const Icon(Icons.pin),
                  value: _pinEnabled,
                  onChanged: (v) => v ? _setupPin() : _removePin(),
                ),
                if (_biometricAvailable) ...[
                  const Divider(height: 1, indent: 16),
                  SwitchListTile(
                    title: const Text('Biometric Unlock'),
                    subtitle: const Text('Fingerprint / Face ID'),
                    secondary: const Icon(Icons.fingerprint),
                    value: _biometricEnabled,
                    onChanged: _pinEnabled
                        ? (v) async {
                            final auth = ref.read(authServiceProvider);
                            if (v) await auth.enableBiometric();
                            else await auth.disableBiometric();
                            setState(() => _biometricEnabled = v);
                          }
                        : null,
                  ),
                ],
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Change PIN'),
                  enabled: _pinEnabled,
                  onTap: _pinEnabled ? _setupPin : null,
                  trailing: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── GOOGLE DRIVE BACKUP ─────────────────────────────────────────
          _SectionHeader(icon: Icons.cloud_upload, title: 'Google Drive Backup', color: Colors.blue),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Column(
              children: [
                // Account
                ListTile(
                  leading: const Icon(Icons.account_circle, color: Colors.blue, size: 32),
                  title: Text(_isSignedInToDrive ? _driveUser ?? 'Signed In' : 'Not Signed In'),
                  subtitle: Text(_isSignedInToDrive ? 'Connected to Google Drive' : 'Sign in to enable backup'),
                  trailing: _isSignedInToDrive
                      ? TextButton(onPressed: _signOut, child: const Text('Sign Out', style: TextStyle(color: Colors.red)))
                      : FilledButton(onPressed: _signIn, child: const Text('Sign In')),
                ),
                if (_lastBackup.isNotEmpty) ...[
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    leading: const Icon(Icons.history, color: Colors.grey),
                    title: const Text('Last Backup'),
                    subtitle: Text(DateTime.tryParse(_lastBackup) != null
                        ? AppFormatters.dateTime(DateTime.parse(_lastBackup))
                        : 'Never'),
                  ),
                ],
                const Divider(height: 1, indent: 16),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSignedInToDrive && !_backupLoading ? _backup : null,
                          icon: _backupLoading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.backup),
                          label: Text(_backupLoading ? 'Backing up...' : 'Backup Now'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isSignedInToDrive && !_backupLoading ? _showRestoreSheet : null,
                          icon: const Icon(Icons.restore),
                          label: const Text('Restore'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── LOCAL BACKUP ────────────────────────────────────────────────
          _SectionHeader(icon: Icons.folder, title: 'Local Backup', color: Colors.brown),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Export to Device'),
                  subtitle: const Text('Save backup ZIP file locally'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _localExport,
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: const Icon(Icons.upload),
                  title: const Text('Import from Device'),
                  subtitle: const Text('Restore from local ZIP backup'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _localImport,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── ABOUT ───────────────────────────────────────────────────────
          _SectionHeader(icon: Icons.info_outline, title: 'About', color: Colors.grey),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Column(
              children: const [
                ListTile(title: Text('App Version'), trailing: Text('1.0.0', style: TextStyle(color: Colors.grey))),
                Divider(height: 1, indent: 16),
                ListTile(title: Text('Family Finance & Zakat Manager'), subtitle: Text('Offline-first • Islamic finance • Secure')),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── PIN SETUP ─────────────────────────────────────────────────────────────

  Future<void> _setupPin() async {
    String? newPin;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PinSetupDialog(
        onConfirm: (pin) { newPin = pin; Navigator.pop(ctx); },
      ),
    );
    if (newPin != null && newPin!.isNotEmpty) {
      await ref.read(authServiceProvider).setPin(newPin!);
      if (mounted) setState(() => _pinEnabled = true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN set successfully'), backgroundColor: Colors.green));
    }
  }

  Future<void> _removePin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove PIN?'),
        content: const Text('This will disable PIN protection. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Remove')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authServiceProvider).removePin();
      if (mounted) setState(() { _pinEnabled = false; _biometricEnabled = false; });
    }
  }

  // ─── GOOGLE DRIVE ──────────────────────────────────────────────────────────

  Future<void> _signIn() async {
    try {
      final account = await ref.read(backupServiceProvider).signIn();
      if (account != null && mounted) {
        setState(() { _isSignedInToDrive = true; _driveUser = account.email; });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign in failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _signOut() async {
    await ref.read(backupServiceProvider).signOut();
    if (mounted) setState(() { _isSignedInToDrive = false; _driveUser = null; });
  }

  Future<void> _backup() async {
    setState(() => _backupLoading = true);
    try {
      final result = await ref.read(backupServiceProvider).createAndUploadBackup();
      if (mounted) {
        setState(() { _lastBackup = result.timestamp.toIso8601String(); _backupLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup complete: ${result.fileName}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _backupLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showRestoreSheet() async {
    setState(() => _backupLoading = true);
    List<BackupFile> backups = [];
    try {
      backups = await ref.read(backupServiceProvider).listBackups();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _backupLoading = false);
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        builder: (_, ctrl) => _RestoreSheet(
          backups: backups,
          onRestore: (fileId) async {
            Navigator.pop(ctx);
            setState(() => _backupLoading = true);
            try {
              await ref.read(backupServiceProvider).restoreFromBackup(fileId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore complete. Restart the app.'), backgroundColor: Colors.green));
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red));
            } finally {
              if (mounted) setState(() => _backupLoading = false);
            }
          },
        ),
      ),
    );
  }

  Future<void> _localExport() async {
    try {
      final file = await ref.read(backupServiceProvider).exportToLocalFile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to: ${file.path}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _localImport() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    if (result == null || result.files.single.path == null) return;
    try {
      await ref.read(backupServiceProvider).importFromLocalFile(File(result.files.single.path!));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imported successfully. Restart the app.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red));
    }
  }
}

// ─── WIDGETS ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _PriceField extends StatefulWidget {
  final String label;
  final String icon;
  final String value;
  final Function(String) onChanged;

  const _PriceField({required this.label, required this.icon, required this.value, required this.onChanged});

  @override
  State<_PriceField> createState() => _PriceFieldState();
}

class _PriceFieldState extends State<_PriceField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value == '0' ? '' : widget.value);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(widget.icon, style: const TextStyle(fontSize: 24)),
      title: Text(widget.label),
      trailing: SizedBox(
        width: 120,
        child: TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            prefixText: '₨ ',
            border: UnderlineInputBorder(),
            isDense: true,
          ),
          onChanged: widget.onChanged,
          onSubmitted: widget.onChanged,
        ),
      ),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
}

class _PinSetupDialog extends StatefulWidget {
  final Function(String) onConfirm;
  const _PinSetupDialog({required this.onConfirm});

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pin1,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Enter PIN (4-6 digits)', counterText: ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin2,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Confirm PIN', counterText: ''),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_pin1.text.length < 4) { setState(() => _error = 'PIN must be at least 4 digits'); return; }
            if (_pin1.text != _pin2.text) { setState(() => _error = 'PINs do not match'); return; }
            widget.onConfirm(_pin1.text);
          },
          child: const Text('Set PIN'),
        ),
      ],
    );
  }
}

class _RestoreSheet extends StatelessWidget {
  final List<BackupFile> backups;
  final Function(String) onRestore;

  const _RestoreSheet({required this.backups, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Backup to Restore', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('⚠️ This will replace all current data.', style: TextStyle(color: Colors.orange, fontSize: 13)),
          const SizedBox(height: 16),
          if (backups.isEmpty)
            const Center(child: Text('No backups found in Google Drive.'))
          else
            Expanded(
              child: ListView.builder(
                itemCount: backups.length,
                itemBuilder: (ctx, i) {
                  final b = backups[i];
                  return ListTile(
                    leading: const Icon(Icons.backup, color: Colors.blue),
                    title: Text(b.name, style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${AppFormatters.dateTime(b.createdAt)} • ${AppFormatters.fileSize(b.size)}'),
                    trailing: TextButton(
                      onPressed: () => onRestore(b.id),
                      child: const Text('Restore'),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
