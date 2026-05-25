// lib/ui/widgets/transaction_tile.dart
import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/formatters.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.category,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final color = isIncome ? Colors.green : Colors.red;
    final catColor = _hexToColor(category?.color ?? '#9E9E9E');

    return Dismissible(
      key: Key('txn_${transaction.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Transaction'),
            content: Text('Delete "${transaction.title}"?'),
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
      },
      onDismissed: (_) => onDelete?.call(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              // Category Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    _iconFromName(category?.icon ?? 'category'),
                    color: catColor,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Title + Meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          category?.name ?? 'Uncategorized',
                          style: TextStyle(fontSize: 11, color: catColor, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 6),
                        Container(width: 3, height: 3, decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(
                          AppFormatters.relativeDate(transaction.transactionDate),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        const SizedBox(width: 6),
                        _PaymentMethodBadge(method: transaction.paymentMethod),
                      ],
                    ),
                  ],
                ),
              ),
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'} ${AppFormatters.currencyCompact(transaction.amount)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (transaction.notes != null && transaction.notes!.isNotEmpty)
                    Icon(Icons.notes, size: 12, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  IconData _iconFromName(String name) {
    const map = {
      'work': Icons.work, 'business': Icons.business, 'trending_up': Icons.trending_up,
      'home': Icons.home, 'house': Icons.house, 'computer': Icons.computer,
      'card_giftcard': Icons.card_giftcard, 'attach_money': Icons.attach_money,
      'restaurant': Icons.restaurant, 'bolt': Icons.bolt, 'directions_car': Icons.directions_car,
      'local_hospital': Icons.local_hospital, 'school': Icons.school, 'checkroom': Icons.checkroom,
      'movie': Icons.movie, 'volunteer_activism': Icons.volunteer_activism,
      'more_horiz': Icons.more_horiz, 'category': Icons.category,
    };
    return map[name] ?? Icons.category;
  }
}

class _PaymentMethodBadge extends StatelessWidget {
  final String method;
  const _PaymentMethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    const icons = {
      'cash': Icons.money,
      'bank': Icons.account_balance,
      'mobile_wallet': Icons.phone_android,
    };
    return Icon(icons[method] ?? Icons.payment, size: 12, color: Colors.grey.shade400);
  }
}
