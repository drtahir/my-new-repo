// lib/ui/screens/bc_detail_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/formatters.dart';
import 'package:drift/drift.dart' show Value;

class BcDetailScreen extends ConsumerStatefulWidget {
  final int groupId;
  const BcDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<BcDetailScreen> createState() => _BcDetailScreenState();
}

class _BcDetailScreenState extends ConsumerState<BcDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _deleteGroup(BcGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Committee'),
        content: Text('Delete "${group.name}"? All rounds, payments and history will be lost.'),
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
      await ref.read(bcDaoProvider).softDeleteGroup(widget.groupId);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _markGroupComplete(BcGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Completed'),
        content: const Text('Mark this committee as completed? It will move to archive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Complete')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(bcDaoProvider).updateGroup(
        group.toCompanion(true).copyWith(status: const Value('completed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(bcGroupsProvider).whenData(
          (groups) => groups.where((g) => g.id == widget.groupId).firstOrNull,
        );

    return groupAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (group) {
        if (group == null) return const Scaffold(body: Center(child: Text('Committee not found')));
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(_freqLabel(group.frequency), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'complete') _markGroupComplete(group);
                  if (v == 'delete') _deleteGroup(group);
                },
                itemBuilder: (_) => [
                  if (group.status == 'active')
                    const PopupMenuItem(value: 'complete', child: Row(children: [Icon(Icons.check_circle_outline, size: 18), SizedBox(width: 8), Text('Mark Complete')])),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(icon: Icon(Icons.format_list_numbered, size: 18), text: 'Rounds'),
                Tab(icon: Icon(Icons.people, size: 18), text: 'Members'),
                Tab(icon: Icon(Icons.history, size: 18), text: 'History'),
              ],
            ),
          ),
          body: Column(
            children: [
              _GroupStatsHeader(group: group),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _RoundsTab(groupId: widget.groupId, group: group),
                    _MembersTab(groupId: widget.groupId),
                    _HistoryTab(groupId: widget.groupId),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _freqLabel(String f) => switch (f) { 'weekly' => 'Weekly BC', 'biweekly' => 'Bi-Weekly BC', _ => 'Monthly BC' };
}

// ─── GROUP STATS HEADER ───────────────────────────────────────────────────────

class _GroupStatsHeader extends ConsumerWidget {
  final BcGroup group;
  const _GroupStatsHeader({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(bcGroupStatsProvider(group.id));
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: statsAsync.when(
        loading: () => const SizedBox(height: 56, child: Center(child: CircularProgressIndicator(color: Colors.white))),
        error: (_, __) => const SizedBox(),
        data: (stats) {
          final totalPool = group.contributionAmount * group.totalSlots;
          final progress = stats.totalRounds == 0 ? 0.0 : stats.drawnRounds / stats.totalRounds;
          return Column(children: [
            Row(children: [
              _HeaderStat(label: 'Total Pool', value: '₨${_compact(totalPool)}'),
              _HeaderStat(label: 'Collected', value: '₨${_compact(stats.totalCollected)}'),
              _HeaderStat(label: 'Pending', value: '₨${_compact(stats.totalPending)}'),
              _HeaderStat(label: 'Members', value: '${stats.totalMembers}'),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Rounds: ${stats.drawnRounds}/${stats.totalRounds}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text('${(progress * 100).toInt()}% complete', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ]);
        },
      ),
    );
  }

  String _compact(double v) => v >= 100000 ? '${(v / 100000).toStringAsFixed(1)}L' : v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}K' : v.toStringAsFixed(0);
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]),
    );
  }
}

// ─── ROUNDS TAB ───────────────────────────────────────────────────────────────

class _RoundsTab extends ConsumerWidget {
  final int groupId;
  final BcGroup group;
  const _RoundsTab({required this.groupId, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roundsAsync = ref.watch(bcRoundsProvider(groupId));
    return roundsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rounds) {
        if (rounds.isEmpty) return const Center(child: Text('No rounds yet.'));
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: rounds.length,
          itemBuilder: (ctx, i) => _RoundCard(round: rounds[i], group: group),
        );
      },
    );
  }
}

class _RoundCard extends ConsumerWidget {
  final BcRound round;
  final BcGroup group;
  const _RoundCard({required this.round, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(bcPaymentsForRoundProvider(round.id));
    final isPending = round.status == 'pending';
    final isDrawn = round.status == 'drawn';
    final isPaidOut = round.status == 'paid_out';

    final statusColor = isPending ? Colors.orange : isDrawn ? Colors.blue : Colors.green;
    final statusLabel = isPending ? 'Pending Draw' : isDrawn ? 'Winner Drawn' : 'Paid Out';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openRoundSheet(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Round header
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: statusColor.withOpacity(0.12), shape: BoxShape.circle),
                child: Center(child: Text('${round.roundNumber}', style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 16))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(round.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (round.scheduledDate != null)
                  Text(AppFormatters.date(round.scheduledDate!), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ]),

            // Winner row
            if (round.winnerName != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.shade200)),
                child: Row(children: [
                  const Text('🏆', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Winner: ${round.winnerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  if (round.drawDate != null)
                    Text(AppFormatters.shortDate(round.drawDate!), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ]),
              ),
            ],

            // Payments progress
            paymentsAsync.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (payments) {
                final paid = payments.where((p) => p.status == 'paid').length;
                final total = payments.length;
                final paidAmount = payments.where((p) => p.status == 'paid').fold(0.0, (s, p) => s + p.amount);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Payments: $paid/$total collected', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    Text('₨${_compact(paidAmount)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  ]),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : paid / total,
                      minHeight: 5,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(total == 0 || paid < total ? Colors.orange : Colors.green),
                    ),
                  ),
                ]);
              },
            ),

            // Quick actions
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (isPending)
                _ActionChip(icon: Icons.casino_outlined, label: 'Draw Winner', color: Colors.purple, onTap: () => _openRoundSheet(context, ref)),
              if (isDrawn)
                _ActionChip(icon: Icons.check_circle_outline, label: 'Mark Paid Out', color: Colors.green, onTap: () => _markPaidOut(ref)),
              const SizedBox(width: 8),
              _ActionChip(icon: Icons.payments_outlined, label: 'Payments', color: Colors.blue, onTap: () => _openRoundSheet(context, ref)),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _markPaidOut(WidgetRef ref) async {
    await ref.read(bcDaoProvider).markRoundPaidOut(round.id);
  }

  void _openRoundSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoundDetailSheet(round: round, group: group),
    );
  }

  String _compact(double v) => v >= 100000 ? '${(v / 100000).toStringAsFixed(1)}L' : v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}K' : v.toStringAsFixed(0);
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─── ROUND DETAIL BOTTOM SHEET ────────────────────────────────────────────────

class _RoundDetailSheet extends ConsumerStatefulWidget {
  final BcRound round;
  final BcGroup group;
  const _RoundDetailSheet({required this.round, required this.group});

  @override
  ConsumerState<_RoundDetailSheet> createState() => _RoundDetailSheetState();
}

class _RoundDetailSheetState extends ConsumerState<_RoundDetailSheet> {
  bool _runningDraw = false;

  Future<void> _togglePayment(BcPayment payment) async {
    final dao = ref.read(bcDaoProvider);
    if (payment.status == 'paid') {
      await dao.markPaymentPending(payment.id);
    } else {
      await dao.markPaymentPaid(payment.id);
      // Update round total
      final payments = await dao.getPaymentsForRound(widget.round.id);
      final total = payments.where((p) => p.status == 'paid' || p.id == payment.id).fold(0.0, (s, p) => s + p.amount);
      await dao.updateRoundTotal(widget.round.id, total);
    }
  }

  void _startLuckyDraw(BuildContext context, List<BcMember> eligible) {
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No eligible members for draw — all have already won!'), backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.pop(context); // close sheet
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LuckyDrawDialog(roundId: widget.round.id, eligible: eligible),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(bcPaymentsForRoundProvider(widget.round.id));
    final membersAsync = ref.watch(bcMembersProvider(widget.group.id));
    final isPending = widget.round.status == 'pending';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Drag handle
          Container(margin: const EdgeInsets.only(top: 10, bottom: 6), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.round.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (widget.round.scheduledDate != null)
                  Text(AppFormatters.date(widget.round.scheduledDate!), style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ])),
              if (widget.round.winnerName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Text('🏆 ${widget.round.winnerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
            ]),
          ),

          const Divider(),

          // Lucky Draw button
          if (isPending)
            membersAsync.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (members) => FutureBuilder<List<BcMember>>(
                future: ref.read(bcDaoProvider).getEligibleDrawMembers(widget.group.id),
                builder: (ctx, snap) {
                  final eligible = snap.data ?? members;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: FilledButton.icon(
                      onPressed: () => _startLuckyDraw(context, eligible),
                      icon: const Icon(Icons.casino),
                      label: Text('🎰 Start Lucky Draw (${eligible.length} eligible)'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.purple,
                      ),
                    ),
                  );
                },
              ),
            ),

          // Payments list header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(children: [
              const Text('Member Payments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              paymentsAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (payments) {
                  final paid = payments.where((p) => p.status == 'paid').length;
                  return Text('$paid/${payments.length} paid', style: TextStyle(color: Colors.grey.shade600, fontSize: 13));
                },
              ),
            ]),
          ),

          // Payments list
          Expanded(
            child: paymentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (payments) => ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: payments.length,
                itemBuilder: (ctx, i) {
                  final p = payments[i];
                  final isPaid = p.status == 'paid';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isPaid ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.12),
                        child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: isPaid ? Colors.green : Colors.grey)),
                      ),
                      title: Text(p.memberName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        isPaid && p.paidAt != null ? 'Paid on ${AppFormatters.shortDate(p.paidAt!)}' : 'Payment pending',
                        style: TextStyle(fontSize: 12, color: isPaid ? Colors.green.shade700 : Colors.orange.shade700),
                      ),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('₨${p.amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: isPaid ? Colors.green : Colors.grey)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _togglePayment(p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: isPaid ? Colors.green : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(isPaid ? Icons.check : Icons.radio_button_unchecked, size: 18, color: isPaid ? Colors.white : Colors.grey),
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── LUCKY DRAW DIALOG ────────────────────────────────────────────────────────

class _LuckyDrawDialog extends ConsumerStatefulWidget {
  final int roundId;
  final List<BcMember> eligible;
  const _LuckyDrawDialog({required this.roundId, required this.eligible});

  @override
  ConsumerState<_LuckyDrawDialog> createState() => _LuckyDrawDialogState();
}

class _LuckyDrawDialogState extends ConsumerState<_LuckyDrawDialog>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  Timer? _spinTimer;
  int _displayIndex = 0;
  bool _spinning = false;
  bool _revealed = false;
  BcMember? _winner;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startSpin() {
    if (widget.eligible.isEmpty) return;
    setState(() { _spinning = true; _revealed = false; });

    final rng = Random();
    int speed = 60;
    int ticks = 0;
    const totalTicks = 35;

    _spinTimer = Timer.periodic(Duration(milliseconds: speed), (timer) {
      ticks++;
      setState(() => _displayIndex = rng.nextInt(widget.eligible.length));

      // Slow down near end
      if (ticks > totalTicks * 0.6) {
        timer.cancel();
        speed = 120;
        _spinTimer = Timer.periodic(Duration(milliseconds: speed), (t2) {
          ticks++;
          setState(() => _displayIndex = rng.nextInt(widget.eligible.length));
          if (ticks > totalTicks * 0.8) {
            t2.cancel();
            speed = 220;
            _spinTimer = Timer.periodic(Duration(milliseconds: speed), (t3) {
              ticks++;
              setState(() => _displayIndex = rng.nextInt(widget.eligible.length));
              if (ticks >= totalTicks) {
                t3.cancel();
                // Pick final winner
                final winnerIdx = rng.nextInt(widget.eligible.length);
                setState(() {
                  _winner = widget.eligible[winnerIdx];
                  _displayIndex = winnerIdx;
                  _spinning = false;
                  _revealed = true;
                });
              }
            });
          }
        });
      }
    });
  }

  Future<void> _confirmWinner() async {
    if (_winner == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(bcDaoProvider).setRoundWinner(widget.roundId, _winner!.id, _winner!.name);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🏆 ${_winner!.name} is the winner!'), backgroundColor: Colors.green, duration: const Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayMember = widget.eligible.isEmpty ? null : widget.eligible[_displayIndex % widget.eligible.length];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Title
          const Text('🎰 Lucky Draw', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${widget.eligible.length} eligible members', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 28),

          // Name display box
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (ctx, child) => Transform.scale(
              scale: _spinning ? _pulseAnim.value : (_revealed ? 1.05 : 1.0),
              child: child,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                gradient: _revealed
                    ? LinearGradient(colors: [Colors.amber.shade400, Colors.orange.shade500], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : LinearGradient(colors: [Colors.purple.shade400, Colors.blue.shade500], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: (_revealed ? Colors.amber : Colors.purple).withOpacity(0.4), blurRadius: 20, spreadRadius: 2)],
              ),
              child: Column(children: [
                if (_revealed) const Text('🏆', style: TextStyle(fontSize: 36)),
                if (!_spinning && !_revealed)
                  const Icon(Icons.casino_outlined, color: Colors.white54, size: 40),
                const SizedBox(height: 8),
                Text(
                  _spinning || _revealed ? (displayMember?.name ?? '...') : 'Press DRAW to start',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                if (_revealed && displayMember?.phone != null) ...[
                  const SizedBox(height: 6),
                  Text(displayMember!.phone!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ]),
            ),
          ),

          const SizedBox(height: 28),

          // Buttons
          if (!_revealed) ...[
            FilledButton.icon(
              onPressed: _spinning ? null : _startSpin,
              icon: _spinning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.casino),
              label: Text(_spinning ? 'Drawing...' : '🎲 DRAW!'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: Colors.purple,
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: _spinning ? null : () => Navigator.pop(context), child: const Text('Cancel')),
          ] else ...[
            FilledButton.icon(
              onPressed: _saving ? null : _confirmWinner,
              icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle),
              label: const Text('Confirm Winner'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: Colors.green,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => setState(() { _revealed = false; _spinning = false; }),
              icon: const Icon(Icons.refresh),
              label: const Text('Draw Again'),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── MEMBERS TAB ──────────────────────────────────────────────────────────────

class _MembersTab extends ConsumerWidget {
  final int groupId;
  const _MembersTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(bcMembersProvider(groupId));
    final roundsAsync = ref.watch(bcRoundsProvider(groupId));

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (members) {
        final winnerIds = roundsAsync.valueOrNull?.where((r) => r.winnerMemberId != null).map((r) => r.winnerMemberId!).toSet() ?? {};
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: members.length,
          itemBuilder: (ctx, i) {
            final m = members[i];
            final hasWon = winnerIds.contains(m.id);
            final colors = [Colors.blue, Colors.purple, Colors.teal, Colors.orange, Colors.green, Colors.red, Colors.indigo];
            final color = colors[i % colors.length];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Text('${m.slotNumber}', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                ),
                title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: m.phone != null ? Text(m.phone!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)) : null,
                trailing: hasWon
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber.shade300)),
                        child: const Text('🏆 Won', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber)),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Eligible', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500)),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── HISTORY TAB ──────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  final int groupId;
  const _HistoryTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roundsAsync = ref.watch(bcRoundsProvider(groupId));
    return roundsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rounds) {
        final done = rounds.where((r) => r.status != 'pending').toList();
        if (done.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.history, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No rounds completed yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Completed draws will appear here', style: TextStyle(color: Colors.grey.shade600)),
            ]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: done.length,
          itemBuilder: (ctx, i) {
            final r = done[i];
            final isPaidOut = r.status == 'paid_out';
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: (isPaidOut ? Colors.green : Colors.blue).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Text(isPaidOut ? '✅' : '🏆', style: const TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (r.winnerName != null)
                      Text('Winner: ${r.winnerName}', style: TextStyle(color: Colors.amber.shade700, fontWeight: FontWeight.w600, fontSize: 13)),
                    if (r.drawDate != null)
                      Text('Drawn: ${AppFormatters.date(r.drawDate!)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('₨${_compact(r.totalCollected)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isPaidOut ? Colors.green.shade700 : Colors.blue)),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isPaidOut ? Colors.green : Colors.blue).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(isPaidOut ? 'Paid Out' : 'Drawn', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPaidOut ? Colors.green : Colors.blue)),
                    ),
                  ]),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  String _compact(double v) => v >= 100000 ? '${(v / 100000).toStringAsFixed(1)}L' : v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}K' : v.toStringAsFixed(0);
}
