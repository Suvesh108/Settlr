import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class ExpenseDetailsModal extends StatefulWidget {
  final Group group;
  final Expense expense;
  final VoidCallback onExpenseReversed;

  const ExpenseDetailsModal({
    super.key,
    required this.group,
    required this.expense,
    required this.onExpenseReversed,
  });

  @override
  State<ExpenseDetailsModal> createState() => _ExpenseDetailsModalState();
}

class _ExpenseDetailsModalState extends State<ExpenseDetailsModal> {
  bool _reversing = false;

  String _getMemberName(String userId) {
    final m = widget.group.members.firstWhere(
      (mem) => mem.userId == userId,
      orElse: () => GroupMember(userId: userId, name: 'Member', email: '', role: 'MEMBER', status: 'ACTIVE'),
    );
    return m.name;
  }

  Future<void> _handleReverse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reverse Transaction?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'Are you sure you want to reverse this expense? A ledger reversal entry will balance the books.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: SettlrColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SettlrColors.negative,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reverse', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _reversing = true);
    try {
      await ApiService.reverseExpense(widget.group.id, widget.expense.id);
      if (mounted) {
        Navigator.pop(context);
        widget.onExpenseReversed();
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _reversing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.expense;
    final currency = widget.group.currency;
    final symbol = currency == 'INR' ? '₹' : currency;
    final myId = ApiService.currentUser?.id;
    final canReverse = !exp.isReversed && !exp.isReversal && (exp.paidBy == myId || exp.createdBy == myId);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5E5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            exp.description,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (exp.isReversed) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: SettlrColors.negativeBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Reversed', style: TextStyle(fontSize: 10, color: SettlrColors.negative, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('Expense details & participant breakdown', style: TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.close, size: 16, color: SettlrColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Paid & Paid by card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Paid', style: TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      '$symbol${(exp.amount / 100).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: SettlrColors.textMain),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Paid by', style: TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      '${exp.payerName ?? _getMemberName(exp.paidBy)}${exp.paidBy == myId ? ' (You)' : ''}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Date & Category meta pills
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF0F0F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: SettlrColors.textMuted),
                      const SizedBox(width: 6),
                      Text(exp.expenseDate.isNotEmpty ? exp.expenseDate : 'Today', style: const TextStyle(fontSize: 12, color: SettlrColors.textMain, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF0F0F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer_outlined, size: 14, color: SettlrColors.textMuted),
                      const SizedBox(width: 6),
                      Text(exp.category, style: const TextStyle(fontSize: 12, color: SettlrColors.textMain, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Participant Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Participant Breakdown (${exp.shares.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SettlrColors.textMain)),
              Text('${exp.splitType} split', style: const TextStyle(fontSize: 11, color: SettlrColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E5E5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: exp.shares.map((s) {
                final isMe = s.userId == myId;
                final name = _getMemberName(s.userId);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$name${isMe ? ' (You)' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                            color: isMe ? SettlrColors.accent : SettlrColors.textMain,
                          ),
                        ),
                      ),
                      Text(
                        '$symbol${(s.shareAmount / 100).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Reversal Button if allowed
          if (canReverse)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: SettlrColors.negative,
                  side: const BorderSide(color: Color(0xFFFECDD3)),
                  backgroundColor: SettlrColors.negativeBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _reversing ? null : _handleReverse,
                icon: const Icon(Icons.undo, size: 16),
                label: Text(
                  _reversing ? 'Reversing...' : 'Reverse Expense (Undo)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
