// lib/ui/screens/bc_group_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/database/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

class BcGroupFormScreen extends ConsumerStatefulWidget {
  final BcGroup? existing;
  const BcGroupFormScreen({super.key, this.existing});

  @override
  ConsumerState<BcGroupFormScreen> createState() => _BcGroupFormScreenState();
}

class _BcGroupFormScreenState extends ConsumerState<BcGroupFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _uuid = const Uuid();

  String _frequency = 'monthly';
  int _totalSlots = 10;
  DateTime _startDate = DateTime.now();
  bool _saving = false;
  int _step = 0; // 0 = group info, 1 = add members

  // Member fields
  final List<Map<String, TextEditingController>> _memberCtrls = [];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final g = widget.existing!;
      _nameCtrl.text = g.name;
      _amountCtrl.text = g.contributionAmount.toStringAsFixed(0);
      _notesCtrl.text = g.notes ?? '';
      _frequency = g.frequency;
      _totalSlots = g.totalSlots;
      _startDate = g.startDate;
    }
    _initMemberControllers(_totalSlots);
  }

  void _initMemberControllers(int count) {
    // Preserve existing data, add/remove as needed
    while (_memberCtrls.length < count) {
      _memberCtrls.add({'name': TextEditingController(), 'phone': TextEditingController()});
    }
    while (_memberCtrls.length > count) {
      final removed = _memberCtrls.removeLast();
      removed['name']?.dispose();
      removed['phone']?.dispose();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _memberCtrls) {
      c['name']?.dispose();
      c['phone']?.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  void _goToMembers() {
    if (_formKey.currentState!.validate()) {
      setState(() => _step = 1);
    }
  }

  Future<void> _save() async {
    // Validate at least member names filled
    final emptyNames = _memberCtrls.where((c) => (c['name']?.text ?? '').trim().isEmpty).length;
    if (emptyNames > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all $emptyNames member name(s)'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final dao = ref.read(bcDaoProvider);
      final amount = double.parse(_amountCtrl.text);

      // Insert BC group
      final groupId = await dao.insertGroup(BcGroupsCompanion.insert(
        uuid: _uuid.v4(),
        name: _nameCtrl.text.trim(),
        contributionAmount: amount,
        frequency: _frequency,
        totalSlots: _totalSlots,
        startDate: _startDate,
        notes: drift.Value(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
      ));

      // Insert members
      final members = <BcMember>[];
      for (int i = 0; i < _memberCtrls.length; i++) {
        final name = _memberCtrls[i]['name']!.text.trim();
        final phone = _memberCtrls[i]['phone']!.text.trim();
        final memberId = await dao.insertMember(BcMembersCompanion.insert(
          uuid: _uuid.v4(),
          bcGroupId: groupId,
          name: name,
          phone: drift.Value(phone.isEmpty ? null : phone),
          slotNumber: i + 1,
        ));
        final member = await dao.getMemberById(memberId);
        if (member != null) members.add(member);
      }

      // Initialize all rounds + payment records
      await dao.initializeGroupData(
        groupId: groupId,
        totalSlots: _totalSlots,
        frequency: _frequency,
        startDate: _startDate,
        members: members,
        contributionAmount: amount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Committee created successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 0 ? 'New Committee' : 'Add Members'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _step == 0 ? () => Navigator.pop(context) : () => setState(() => _step = 0),
        ),
      ),
      body: _step == 0 ? _buildStep0() : _buildStep1(),
    );
  }

  Widget _buildStep0() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Progress indicator
          _StepIndicator(currentStep: 0),
          const SizedBox(height: 24),

          // Committee Name
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Committee Name *', prefixIcon: Icon(Icons.groups_outlined), hintText: 'e.g. Office BC 2025'),
            textCapitalization: TextCapitalization.words,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),

          // Contribution Amount
          TextFormField(
            controller: _amountCtrl,
            decoration: const InputDecoration(labelText: 'Contribution Amount (₨) *', prefixIcon: Icon(Icons.monetization_on_outlined), hintText: 'e.g. 5000'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Amount is required';
              final val = double.tryParse(v);
              if (val == null || val <= 0) return 'Enter a valid amount';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Frequency
          DropdownButtonFormField<String>(
            value: _frequency,
            decoration: const InputDecoration(labelText: 'Draw Frequency', prefixIcon: Icon(Icons.repeat)),
            items: const [
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              DropdownMenuItem(value: 'biweekly', child: Text('Bi-Weekly (every 2 weeks)')),
            ],
            onChanged: (v) => setState(() => _frequency = v!),
          ),
          const SizedBox(height: 16),

          // Total Slots / Members
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(children: [
                const Icon(Icons.people_outline, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Number of Members', style: TextStyle(fontSize: 14)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('$_totalSlots', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                ),
              ]),
            ),
            Slider(
              value: _totalSlots.toDouble(),
              min: 2,
              max: 50,
              divisions: 48,
              label: '$_totalSlots members',
              onChanged: (v) {
                setState(() {
                  _totalSlots = v.round();
                  _initMemberControllers(_totalSlots);
                });
              },
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('2', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              Text('50', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ]),
          const SizedBox(height: 16),

          // Start Date
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Start Date', prefixIcon: Icon(Icons.calendar_today_outlined)),
              child: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}', style: const TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 16),

          // Summary Card
          _SummaryPreviewCard(
            frequency: _frequency,
            slots: _totalSlots,
            amount: double.tryParse(_amountCtrl.text) ?? 0,
            startDate: _startDate,
          ),
          const SizedBox(height: 16),

          // Notes
          TextFormField(
            controller: _notesCtrl,
            decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.notes_outlined)),
            maxLines: 2,
          ),
          const SizedBox(height: 28),

          FilledButton.icon(
            onPressed: _goToMembers,
            icon: const Icon(Icons.arrow_forward),
            label: Text('Next: Add $_totalSlots Members'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      children: [
        _StepIndicator(currentStep: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Add names and phone numbers for all $_totalSlots members. Slot number = draw order.',
                style: const TextStyle(fontSize: 13, color: Colors.blue),
              )),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: _totalSlots,
            itemBuilder: (ctx, i) => _MemberInput(index: i, ctrls: _memberCtrls[i]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: _saving
              ? const CircularProgressIndicator()
              : FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: Text('Create Committee with $_totalSlots Members'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
        ),
      ],
    );
  }
}

class _MemberInput extends StatelessWidget {
  final int index;
  final Map<String, TextEditingController> ctrls;
  const _MemberInput({required this.index, required this.ctrls});

  @override
  Widget build(BuildContext context) {
    final colors = [Colors.blue, Colors.purple, Colors.teal, Colors.orange, Colors.green, Colors.red, Colors.indigo];
    final color = colors[index % colors.length];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(children: [
          Row(children: [
            CircleAvatar(radius: 16, backgroundColor: color.withOpacity(0.15), child: Text('${index + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color))),
            const SizedBox(width: 10),
            Expanded(child: TextField(
              controller: ctrls['name'],
              decoration: InputDecoration(hintText: 'Member ${index + 1} name *', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontWeight: FontWeight.w500),
            )),
          ]),
          const Divider(height: 12),
          Row(children: [
            const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: ctrls['phone'],
              decoration: const InputDecoration(hintText: 'Phone (optional)', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 13),
            )),
          ]),
        ]),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        _Step(label: '1. Info', active: currentStep == 0, done: currentStep > 0),
        Expanded(child: Container(height: 2, color: currentStep > 0 ? Colors.blue : Colors.grey.shade300)),
        _Step(label: '2. Members', active: currentStep == 1, done: currentStep > 1),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;
  const _Step({required this.label, required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.blue : done ? Colors.green : Colors.grey.shade400;
    return Column(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
        child: Icon(done ? Icons.check : Icons.circle, size: 14, color: color),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
    ]);
  }
}

class _SummaryPreviewCard extends StatelessWidget {
  final String frequency;
  final int slots;
  final double amount;
  final DateTime startDate;
  const _SummaryPreviewCard({required this.frequency, required this.slots, required this.amount, required this.startDate});

  @override
  Widget build(BuildContext context) {
    final totalPool = amount * slots;
    final freqLabel = switch (frequency) { 'weekly' => 'week', 'biweekly' => 'bi-week', _ => 'month' };
    final duration = switch (frequency) {
      'weekly' => '${slots} weeks',
      'biweekly' => '${slots * 2} weeks',
      _ => '$slots months',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade500], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Committee Preview', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _PreviewStat(label: 'Each Pays', value: amount == 0 ? '₨ -' : '₨${_fmt(amount)}/$freqLabel')),
          Expanded(child: _PreviewStat(label: 'Total Pool', value: amount == 0 ? '₨ -' : '₨${_fmt(totalPool)}')),
          Expanded(child: _PreviewStat(label: 'Duration', value: duration)),
        ]),
      ]),
    );
  }

  String _fmt(double v) => v >= 100000 ? '${(v / 100000).toStringAsFixed(1)}L' : v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);
}

class _PreviewStat extends StatelessWidget {
  final String label;
  final String value;
  const _PreviewStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }
}
