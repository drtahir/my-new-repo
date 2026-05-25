// lib/ui/screens/bc_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/database/app_database.dart';
import 'bc_group_form_screen.dart';
import 'bc_detail_screen.dart';

class BcScreen extends ConsumerWidget {
  const BcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(bcGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Committee (BC)', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('بیسی / کمیٹی', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BcGroupFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New Committee'),
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (groups) {
          if (groups.isEmpty) return _EmptyState();
          final active = groups.where((g) => g.status == 'active').toList();
          final completed = groups.where((g) => g.status != 'active').toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              if (active.isNotEmpty) ...[
                _SectionHeader(title: 'Active Committees', count: active.length, color: Colors.blue),
                const SizedBox(height: 10),
                ...active.map((g) => _GroupCard(group: g)),
              ],
              if (completed.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionHeader(title: 'Completed / Archived', count: completed.length, color: Colors.grey),
                const SizedBox(height: 10),
                ...completed.map((g) => _GroupCard(group: g, isCompleted: true)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  const _SectionHeader({required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ),
    ]);
  }
}

class _GroupCard extends ConsumerWidget {
  final BcGroup group;
  final bool isCompleted;
  const _GroupCard({required this.group, this.isCompleted = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(bcGroupStatsProvider(group.id));
    final color = isCompleted ? Colors.grey : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BcDetailScreen(groupId: group.id))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.groups_rounded, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.people_outline, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text('${group.totalSlots} members', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(width: 10),
                      Icon(Icons.repeat, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text(_freqLabel(group.frequency), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ]),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₨${_compact(group.contributionAmount)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                  Text('/ ${group.frequency == 'weekly' ? 'week' : group.frequency == 'biweekly' ? 'bi-wk' : 'month'}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ]),
              ]),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Stats row
              statsAsync.when(
                loading: () => const SizedBox(height: 28, child: Center(child: LinearProgressIndicator())),
                error: (_, __) => const SizedBox(),
                data: (stats) => Row(children: [
                  _StatBadge(label: 'Total Pool', value: '₨${_compact(group.contributionAmount * group.totalSlots)}', color: Colors.purple),
                  const SizedBox(width: 8),
                  _StatBadge(label: 'Collected', value: '₨${_compact(stats.totalCollected)}', color: Colors.green),
                  const SizedBox(width: 8),
                  _StatBadge(label: 'Rounds Done', value: '${stats.drawnRounds}/${stats.totalRounds}', color: color),
                ]),
              ),

              if (!isCompleted) ...[
                const SizedBox(height: 10),
                statsAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (stats) {
                    final progress = stats.totalRounds == 0 ? 0.0 : stats.drawnRounds / stats.totalRounds;
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Progress', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        Text('${(progress * 100).toInt()}%', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: color.withOpacity(0.1), valueColor: AlwaysStoppedAnimation(color)),
                      ),
                    ]);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _freqLabel(String f) => switch (f) { 'weekly' => 'Weekly', 'biweekly' => 'Bi-Weekly', _ => 'Monthly' };
  String _compact(double v) => v >= 100000 ? '${(v / 100000).toStringAsFixed(1)}L' : v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.groups_outlined, size: 72, color: Colors.blue),
          ),
          const SizedBox(height: 24),
          const Text('No Committees Yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            'Create a BC or Committee to track member contributions, payment collection, and run lucky draws for each round.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BcGroupFormScreen())),
            icon: const Icon(Icons.add),
            label: const Text('Create First Committee'),
          ),
        ]),
      ),
    );
  }
}
