// lib/ui/screens/liabilities_screen.dart
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

class LiabilitiesScreen extends ConsumerWidget {
  const LiabilitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liabAsync = ref.watch(allLiabilitiesProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Liabilities'),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Loans/Debts'),
              Tab(text: 'Committees'),
            ],
          ),
        ),
        body: liabAsync.when(
          data: (liabilities) {
            final all = liabilities;
            final loans = liabilities.where((l) => l.type == 'loan_taken' || l.type == 'loan_given' || l.type == 'debt').toList();
            final committees = liabilities.where((l) => l.type == 'committee').toList();

            return TabBarView(
              children: [
                _LiabilityList(items: all, ref: ref),
                _LiabilityList(items: loans, ref: ref),
                _LiabilityList(items: committees, ref: ref),
              ],
            );
          },
          loading: () => const LoadingWidget(),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showLiabilityForm(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Add'),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  void _showLiabilityForm(BuildContext context, WidgetRef ref, {Liability? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _LiabilityForm(existing: existing, ref: ref),
      ),
    );
  }
}

class _LiabilityList extends StatelessWidget {
  final List<Liability> items;
  final WidgetRef ref;

  const _LiabilityList({required this.items, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.credit_card_off_outlined,
        title: 'No Records',
        subtitle: 'No liabilities found.',
      );
    }

    final total = items.fold(0.0, (s, l) => s + l.remainingAmount);

    return Column(
      children: [
        _LiabilityBanner(total: total),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: items.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LiabilityTile(
                item: items[i],
                ref: ref,
                onEdit: () => _showEdit(ctx, items[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showEdit(BuildContext context, Liability item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _LiabilityForm(existing: item, ref: ref),
      ),
    );
  }
}

class _LiabilityBanner extends StatelessWidget {
  final double total;
  const _LiabilityBanner({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE65100), Color(0xFFFFA726)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Outstanding', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(AppFormatters.currency(total), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.credit_card, color: Colors.white38, size: 36),
        ],
      ),
    );
  }
}

class _LiabilityTile extends StatelessWidget {
  final Liability item;
  final WidgetRef ref;
  final VoidCallback onEdit;

  const _LiabilityTile({required this.item, required this.ref, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final progress = item.totalAmount > 0 ? (item.totalAmount - item.remainingAmount) / item.totalAmount : 0.0;
    final isOverdue = item.dueDate != null && item.dueDate!.isBefore(DateTime.now()) && item.status == 'active';

    Color statusColor;
    switch (item.status) {
      case 'paid': statusColor = Colors.green; break;
      case 'overdue': statusColor = Colors.red; break;
      default: statusColor = Colors.orange;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isOverdue ? Colors.red.shade200 : Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.personName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _TypeBadge(type: item.type),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(item.status.toUpperCase(), style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(AppFormatters.currencyCompact(item.remainingAmount),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: item.status == 'paid' ? Colors.green : Colors.orange)),
                      Text('of ${AppFormatters.currencyCompact(item.totalAmount)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    item.status == 'paid' ? Colors.green : Colors.orange,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (item.dueDate != null)
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: isOverdue ? Colors.red : Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          'Due: ${AppFormatters.date(item.dueDate!)}',
                          style: TextStyle(fontSize: 11, color: isOverdue ? Colors.red : Colors.grey.shade500),
                        ),
                      ],
                    ),
                  if (item.monthlyInstallment > 0)
                    Text('₨${AppFormatters.currencyCompact(item.monthlyInstallment)}/mo',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (item.status != 'paid')
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _addPayment(context),
                        icon: const Icon(Icons.payments, size: 16),
                        label: const Text('Pay', style: TextStyle(fontSize: 13)),
                        style: FilledButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, ctrl) => _LiabilityDetail(item: item, ref: ref, scrollCtrl: ctrl),
      ),
    );
  }

  void _addPayment(BuildContext context) {
    final amtCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Payment for ${item.personName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Remaining: ${AppFormatters.currency(item.remainingAmount)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: amtCtrl,
              decoration: const InputDecoration(
                labelText: 'Payment Amount (₨)',
                prefixText: '₨ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amtCtrl.text);
              if (amount == null || amount <= 0) return;
              await ref.read(liabilityDaoProvider).addPayment(
                LiabilityPaymentsCompanion.insert(
                  liabilityId: item.id,
                  amount: amount,
                  paymentDate: DateTime.now(),
                ),
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Payment of ${AppFormatters.currency(amount)} recorded'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );
  }
}

class _LiabilityDetail extends ConsumerWidget {
  final Liability item;
  final WidgetRef ref;
  final ScrollController scrollCtrl;

  const _LiabilityDetail({required this.item, required this.ref, required this.scrollCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(
      StreamProvider.autoDispose((r) => r.read(liabilityDaoProvider).watchPayments(item.id)),
    );

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(20),
      children: [
        Text(item.personName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        if (item.personPhone != null) Text(item.personPhone!, style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        _DetailRow('Type', AppConstants.liabilityTypeLabels[item.type] ?? item.type),
        _DetailRow('Total Amount', AppFormatters.currency(item.totalAmount)),
        _DetailRow('Remaining', AppFormatters.currency(item.remainingAmount)),
        _DetailRow('Paid', AppFormatters.currency(item.totalAmount - item.remainingAmount)),
        if (item.monthlyInstallment > 0)
          _DetailRow('Monthly', AppFormatters.currency(item.monthlyInstallment)),
        if (item.dueDate != null)
          _DetailRow('Due Date', AppFormatters.date(item.dueDate!)),
        if (item.notes != null) _DetailRow('Notes', item.notes!),
        const Divider(height: 24),
        const Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        paymentsAsync.when(
          data: (payments) => payments.isEmpty
              ? const Text('No payments recorded yet.', style: TextStyle(color: Colors.grey))
              : Column(
                  children: payments.map((p) => ListTile(
                    leading: const Icon(Icons.payments, color: Colors.green),
                    title: Text(AppFormatters.currency(p.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(AppFormatters.date(p.paymentDate)),
                    dense: true,
                  )).toList(),
                ),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'loan_taken': Colors.red, 'loan_given': Colors.blue,
      'committee': Colors.purple, 'debt': Colors.orange,
    };
    final color = colors[type] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(
        AppConstants.liabilityTypeLabels[type] ?? type,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _LiabilityForm extends ConsumerStatefulWidget {
  final Liability? existing;
  final WidgetRef ref;
  const _LiabilityForm({this.existing, required this.ref});

  @override
  ConsumerState<_LiabilityForm> createState() => _LiabilityFormState();
}

class _LiabilityFormState extends ConsumerState<_LiabilityForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _remainingCtrl = TextEditingController();
  final _installmentCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _type = 'loan_taken';
  DateTime _startDate = DateTime.now();
  DateTime? _dueDate;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final l = widget.existing!;
      _nameCtrl.text = l.personName;
      _phoneCtrl.text = l.personPhone ?? '';
      _totalCtrl.text = l.totalAmount.toStringAsFixed(0);
      _remainingCtrl.text = l.remainingAmount.toStringAsFixed(0);
      _installmentCtrl.text = l.monthlyInstallment.toStringAsFixed(0);
      _notesCtrl.text = l.notes ?? '';
      _type = l.type;
      _startDate = l.startDate;
      _dueDate = l.dueDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isEditing ? 'Edit Record' : 'Add Liability', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: _dec('Type', Icons.category),
              items: AppConstants.liabilityTypes.map((t) => DropdownMenuItem(value: t, child: Text(AppConstants.liabilityTypeLabels[t] ?? t))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _nameCtrl, decoration: _dec('Person Name', Icons.person), validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneCtrl, decoration: _dec('Phone (optional)', Icons.phone), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _totalCtrl, decoration: _dec('Total Amount', Icons.attach_money),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  onChanged: (v) { if (!_isEditing) _remainingCtrl.text = v; },
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _remainingCtrl, decoration: _dec('Remaining', Icons.money_off),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                )),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _installmentCtrl, decoration: _dec('Monthly Installment (optional)', Icons.event_repeat), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _DatePickerField(label: 'Start Date', date: _startDate, onPick: (d) => setState(() => _startDate = d), required: true)),
                const SizedBox(width: 12),
                Expanded(child: _DatePickerField(label: 'Due Date (opt.)', date: _dueDate, onPick: (d) => setState(() => _dueDate = d), required: false)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _notesCtrl, decoration: _dec('Notes (optional)', Icons.notes), maxLines: 2),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52), backgroundColor: Colors.orange),
              child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_isEditing ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true,
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final dao = ref.read(liabilityDaoProvider);
      final companion = LiabilitiesCompanion(
        uuid: _isEditing ? Value(widget.existing!.uuid) : Value(const Uuid().v4()),
        personName: Value(_nameCtrl.text.trim()),
        personPhone: Value(_phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()),
        type: Value(_type),
        totalAmount: Value(double.tryParse(_totalCtrl.text) ?? 0),
        remainingAmount: Value(double.tryParse(_remainingCtrl.text) ?? 0),
        monthlyInstallment: Value(double.tryParse(_installmentCtrl.text) ?? 0),
        startDate: Value(_startDate),
        dueDate: Value(_dueDate),
        notes: Value(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
        updatedAt: Value(DateTime.now()),
      );
      if (_isEditing) {
        await dao.updateLiability(companion.copyWith(id: Value(widget.existing!.id)));
      } else {
        await dao.insertLiability(companion);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final Function(DateTime) onPick;
  final bool required;

  const _DatePickerField({required this.label, required this.date, required this.onPick, required this.required});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2050),
        );
        if (d != null) onPick(d);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text(date != null ? AppFormatters.date(date!) : 'Tap to set', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: date != null ? null : Colors.grey)),
          ],
        ),
      ),
    );
  }
}
