// lib/ui/screens/add_transaction_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final Transaction? existingTransaction;
  final String? initialType;

  const AddTransactionScreen({
    super.key,
    this.existingTransaction,
    this.initialType,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _typeController;

  // Form fields
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _type = 'expense';
  String? _selectedCategoryId;
  String _paymentMethod = 'cash';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  bool get _isEditing => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? widget.existingTransaction?.type ?? 'expense';
    _typeController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _type == 'income' ? 1 : 0,
    );
    _typeController.addListener(() {
      if (!_typeController.indexIsChanging) {
        setState(() {
          _type = _typeController.index == 0 ? 'expense' : 'income';
          _selectedCategoryId = null; // reset category on type change
        });
      }
    });

    if (_isEditing) {
      final t = widget.existingTransaction!;
      _titleController.text = t.title;
      _amountController.text = t.amount.toStringAsFixed(0);
      _notesController.text = t.notes ?? '';
      _selectedCategoryId = t.categoryId;
      _paymentMethod = t.paymentMethod;
      _selectedDate = t.transactionDate;
    }
  }

  @override
  void dispose() {
    _typeController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider(_type));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteTransaction,
              tooltip: 'Delete',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Type Tab ────────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _typeController,
                labelColor: Colors.white,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                indicator: BoxDecoration(
                  color: _type == 'expense' ? Colors.red : Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                tabs: const [
                  Tab(text: '↑ Expense'),
                  Tab(text: '↓ Income'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Amount ───────────────────────────────────────────────────────
            _buildAmountField(),
            const SizedBox(height: 16),

            // ─── Title ────────────────────────────────────────────────────────
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration('Title / Description', Icons.title),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 200,
              validator: (v) => AppValidators.required(v, fieldName: 'Title'),
            ),
            const SizedBox(height: 16),

            // ─── Category ─────────────────────────────────────────────────────
            categories.when(
              data: (cats) => _buildCategorySelector(cats),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Could not load categories'),
            ),
            const SizedBox(height: 16),

            // ─── Payment Method ────────────────────────────────────────────────
            _buildPaymentMethodSelector(),
            const SizedBox(height: 16),

            // ─── Date ─────────────────────────────────────────────────────────
            _buildDatePicker(context),
            const SizedBox(height: 16),

            // ─── Notes ────────────────────────────────────────────────────────
            TextFormField(
              controller: _notesController,
              decoration: _inputDecoration('Notes (optional)', Icons.notes),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 24),

            // ─── Save Button ──────────────────────────────────────────────────
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : (_isEditing ? 'Update Transaction' : 'Save Transaction')),
              style: FilledButton.styleFrom(
                backgroundColor: _type == 'expense' ? Colors.red : Colors.green,
                minimumSize: const Size(double.infinity, 56),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (_type == 'expense' ? Colors.red : Colors.green).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (_type == 'expense' ? Colors.red : Colors.green).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('₨', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _type == 'expense' ? Colors.red : Colors.green)),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '0',
                hintStyle: TextStyle(fontSize: 36, color: Colors.grey),
              ),
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _type == 'expense' ? Colors.red : Colors.green),
              validator: AppValidators.amount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(List<Category> cats) {
    final filtered = cats.where((c) => c.type == _type || c.type == 'both').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filtered.map((cat) {
            final selected = _selectedCategoryId == cat.uuid;
            final catColor = _hexToColor(cat.color);
            return FilterChip(
              label: Text(cat.name),
              avatar: Icon(_iconFromName(cat.icon), size: 16, color: selected ? Colors.white : catColor),
              selected: selected,
              onSelected: (_) => setState(() => _selectedCategoryId = cat.uuid),
              selectedColor: catColor,
              labelStyle: TextStyle(
                color: selected ? Colors.white : null,
                fontSize: 12,
              ),
              checkmarkColor: Colors.white,
            );
          }).toList(),
        ),
        if (_selectedCategoryId == null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Please select a category', style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildPaymentMethodSelector() {
    const methods = {
      'cash': ('Cash', Icons.money),
      'bank': ('Bank Transfer', Icons.account_balance),
      'mobile_wallet': ('Mobile Wallet', Icons.phone_android),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: methods.entries.map((e) {
            final selected = _paymentMethod == e.key;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _paymentMethod = e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(e.value.$2, size: 20, color: selected ? Theme.of(context).colorScheme.primary : null),
                        const SizedBox(height: 4),
                        Text(e.value.$1, style: TextStyle(fontSize: 10, color: selected ? Theme.of(context).colorScheme.primary : null), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(AppFormatters.date(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      final amount = double.parse(_amountController.text.replaceAll(',', ''));
      final dao = ref.read(transactionDaoProvider);

      if (_isEditing) {
        await dao.updateTransaction(widget.existingTransaction!.toCompanion(true).copyWith(
          title: Value(_titleController.text.trim()),
          amount: Value(amount),
          type: Value(_type),
          categoryId: Value(_selectedCategoryId!),
          paymentMethod: Value(_paymentMethod),
          notes: Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
          transactionDate: Value(_selectedDate),
          updatedAt: Value(DateTime.now()),
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction updated'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } else {
        await dao.insertTransaction(TransactionsCompanion.insert(
          uuid: const Uuid().v4(),
          title: _titleController.text.trim(),
          amount: amount,
          type: _type,
          categoryId: _selectedCategoryId!,
          paymentMethod: _paymentMethod,
          notes: Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
          transactionDate: _selectedDate,
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction saved'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteTransaction() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(transactionDaoProvider).softDelete(widget.existingTransaction!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Color _hexToColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  IconData _iconFromName(String name) {
    const map = {
      'work': Icons.work, 'business': Icons.business, 'trending_up': Icons.trending_up,
      'home': Icons.home, 'house': Icons.house, 'computer': Icons.computer,
      'card_giftcard': Icons.card_giftcard, 'attach_money': Icons.attach_money,
      'restaurant': Icons.restaurant, 'bolt': Icons.bolt, 'directions_car': Icons.directions_car,
      'local_hospital': Icons.local_hospital, 'school': Icons.school, 'checkroom': Icons.checkroom,
      'movie': Icons.movie, 'volunteer_activism': Icons.volunteer_activism, 'more_horiz': Icons.more_horiz,
      'category': Icons.category,
    };
    return map[name] ?? Icons.category;
  }
}
