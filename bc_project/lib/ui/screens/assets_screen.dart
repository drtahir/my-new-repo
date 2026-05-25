// lib/ui/screens/assets_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/constants.dart';
import '../widgets/loading_widget.dart';

class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(allAssetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assets'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: assetsAsync.when(
        data: (assets) {
          if (assets.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No Assets Yet',
              subtitle: 'Add your gold, property, cash savings, and other assets.',
              actionLabel: 'Add Asset',
              onAction: () => _showAssetForm(context, ref),
            );
          }
          // Group by type
          final grouped = <String, List<Asset>>{};
          for (final a in assets) {
            grouped.putIfAbsent(a.type, () => []).add(a);
          }
          final totalValue = assets.fold(0.0, (s, a) => s + a.currentValue);

          return CustomScrollView(
            slivers: [
              // Total banner
              SliverToBoxAdapter(
                child: _TotalBanner(total: totalValue),
              ),
              // Type groups
              for (final entry in grouped.entries) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Text(AppConstants.assetTypeIcons[entry.key] ?? '📦', style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          AppConstants.assetTypeLabels[entry.key] ?? entry.key,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const Spacer(),
                        Text(
                          AppFormatters.currencyCompact(entry.value.fold(0.0, (s, a) => s + a.currentValue)),
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: _AssetTile(
                        asset: entry.value[i],
                        onEdit: () => _showAssetForm(ctx, ref, existing: entry.value[i]),
                        onDelete: () => ref.read(assetDaoProvider).softDelete(entry.value[i].id),
                      ),
                    ),
                    childCount: entry.value.length,
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
        loading: () => const LoadingWidget(message: 'Loading assets...'),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAssetForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Asset'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showAssetForm(BuildContext context, WidgetRef ref, {Asset? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AssetForm(existing: existing, ref: ref),
      ),
    );
  }
}

class _TotalBanner extends StatelessWidget {
  final double total;
  const _TotalBanner({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Asset Value', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text(AppFormatters.currency(total), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.account_balance_wallet, color: Colors.white54, size: 40),
        ],
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  final Asset asset;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AssetTile({required this.asset, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final gain = asset.currentValue - asset.purchaseValue;
    final gainPercent = asset.purchaseValue > 0 ? (gain / asset.purchaseValue) * 100 : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(AppConstants.assetTypeIcons[asset.type] ?? '📦', style: const TextStyle(fontSize: 22))),
        ),
        title: Text(asset.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (asset.quantity != null)
              Text('${asset.quantity?.toStringAsFixed(2)} ${asset.unit ?? ''}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            Row(
              children: [
                if (asset.isZakatApplicable)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: const Text('Zakat', style: TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.w600)),
                  ),
                if (asset.isZakatApplicable) const SizedBox(width: 6),
                if (gain != 0)
                  Text(
                    '${gain >= 0 ? '+' : ''}${gainPercent.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 11, color: gain >= 0 ? Colors.green : Colors.red),
                  ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(AppFormatters.currencyCompact(asset.currentValue),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
            if (asset.purchaseValue > 0)
              Text('Cost: ${AppFormatters.currencyCompact(asset.purchaseValue)}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
        onTap: onEdit,
        onLongPress: () async {
          final action = await showModalBottomSheet<String>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(leading: const Icon(Icons.edit), title: const Text('Edit'), onTap: () => Navigator.pop(ctx, 'edit')),
                  ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Delete', style: TextStyle(color: Colors.red)), onTap: () => Navigator.pop(ctx, 'delete')),
                ],
              ),
            ),
          );
          if (action == 'edit') onEdit();
          if (action == 'delete') onDelete();
        },
      ),
    );
  }
}

class _AssetForm extends ConsumerStatefulWidget {
  final Asset? existing;
  final WidgetRef ref;
  const _AssetForm({this.existing, required this.ref});

  @override
  ConsumerState<_AssetForm> createState() => _AssetFormState();
}

class _AssetFormState extends ConsumerState<_AssetForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _currentValueCtrl = TextEditingController();
  final _purchaseValueCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _type = 'gold';
  String _unit = 'grams';
  bool _zakatApplicable = true;
  DateTime? _purchaseDate;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final a = widget.existing!;
      _nameCtrl.text = a.name;
      _currentValueCtrl.text = a.currentValue.toStringAsFixed(0);
      _purchaseValueCtrl.text = a.purchaseValue.toStringAsFixed(0);
      _quantityCtrl.text = a.quantity?.toStringAsFixed(2) ?? '';
      _locationCtrl.text = a.location ?? '';
      _notesCtrl.text = a.notes ?? '';
      _type = a.type;
      _unit = a.unit ?? 'grams';
      _zakatApplicable = a.isZakatApplicable;
      _purchaseDate = a.purchaseDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _currentValueCtrl.dispose(); _purchaseValueCtrl.dispose();
    _quantityCtrl.dispose(); _locationCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_isEditing ? 'Edit Asset' : 'Add Asset', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Asset type
            DropdownButtonFormField<String>(
              value: _type,
              decoration: _dec('Asset Type', Icons.category),
              items: AppConstants.assetTypes.map((t) => DropdownMenuItem(
                value: t,
                child: Text('${AppConstants.assetTypeIcons[t]} ${AppConstants.assetTypeLabels[t]}'),
              )).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _nameCtrl,
              decoration: _dec('Asset Name', Icons.label),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _currentValueCtrl,
                    decoration: _dec('Current Value (₨)', Icons.attach_money),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _purchaseValueCtrl,
                    decoration: _dec('Purchase Value (₨)', Icons.shopping_bag),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_type == 'gold' || _type == 'silver' || _type == 'land') ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityCtrl,
                      decoration: _dec('Quantity', Icons.balance),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: _dec('Unit', Icons.straighten),
                      items: (_type == 'gold' || _type == 'silver')
                          ? ['grams', 'tola', 'kg'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList()
                          : ['marla', 'kanal', 'sq ft', 'acres'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setState(() => _unit = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            if (_type == 'land') ...[
              TextFormField(
                controller: _locationCtrl,
                decoration: _dec('Location / Address', Icons.location_on),
              ),
              const SizedBox(height: 14),
            ],

            // Purchase date
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context, initialDate: _purchaseDate ?? DateTime.now(),
                  firstDate: DateTime(1990), lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _purchaseDate = d);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 10),
                    Text(_purchaseDate != null ? 'Purchased: ${AppFormatters.date(_purchaseDate!)}' : 'Purchase Date (optional)',
                      style: TextStyle(color: _purchaseDate != null ? null : Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _notesCtrl,
              decoration: _dec('Notes (optional)', Icons.notes),
              maxLines: 2,
            ),
            const SizedBox(height: 14),

            SwitchListTile(
              title: const Text('Zakat Applicable'),
              subtitle: const Text('Include in Zakat calculation'),
              value: _zakatApplicable,
              onChanged: (v) => setState(() => _zakatApplicable = v),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            const SizedBox(height: 20),

            FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEditing ? 'Update Asset' : 'Save Asset'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    filled: true,
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final dao = ref.read(assetDaoProvider);
      final companion = AssetsCompanion(
        uuid: _isEditing ? Value(widget.existing!.uuid) : Value(const Uuid().v4()),
        name: Value(_nameCtrl.text.trim()),
        type: Value(_type),
        currentValue: Value(double.tryParse(_currentValueCtrl.text) ?? 0),
        purchaseValue: Value(double.tryParse(_purchaseValueCtrl.text) ?? 0),
        quantity: Value(double.tryParse(_quantityCtrl.text)),
        unit: Value(_quantityCtrl.text.isNotEmpty ? _unit : null),
        location: Value(_locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim()),
        notes: Value(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
        isZakatApplicable: Value(_zakatApplicable),
        purchaseDate: Value(_purchaseDate),
        updatedAt: Value(DateTime.now()),
      );
      if (_isEditing) {
        await dao.updateAsset(companion.copyWith(id: Value(widget.existing!.id)));
      } else {
        await dao.insertAsset(companion);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
