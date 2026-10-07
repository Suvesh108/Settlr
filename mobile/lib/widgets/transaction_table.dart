import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import 'motion_wrapper.dart';

class TransactionTable extends StatefulWidget {
  final String groupId;
  final String currency;
  final List<Expense> expenses;
  final String currentUserId;
  final Function(Expense) onSelectExpense;
  final Function(Expense) onReverseExpense;

  const TransactionTable({
    super.key,
    required this.groupId,
    required this.currency,
    required this.expenses,
    required this.currentUserId,
    required this.onSelectExpense,
    required this.onReverseExpense,
  });

  @override
  State<TransactionTable> createState() => _TransactionTableState();
}

class _TransactionTableState extends State<TransactionTable> {
  String _selectedCategory = 'ALL';

  static const List<String> categories = ['ALL', 'FOOD', 'GROCERIES', 'RENT', 'TRAVEL'];

  String _formatMoney(double amount, String curr) {
    final sym = curr == 'INR' ? '₹' : curr == 'USD' ? '\$' : curr == 'EUR' ? '€' : '£';
    return '$sym${amount.toStringAsFixed(2)}';
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d, y').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeExpenses = widget.expenses.where((e) => !e.is_reversed && !e.is_reversal).toList();
    final filtered = _selectedCategory == 'ALL'
        ? activeExpenses
        : activeExpenses.where((e) => e.category?.toUpperCase() == _selectedCategory).toList();

    return SettlrPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction Activity',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: SettlrColors.textMain,
                    ),
                  ),
                  Text(
                    'Immutable expense ledger entries',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${filtered.length} entries',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Category Pill Filter bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: BouncyPress(
                    onTap: () => setState(() => _selectedCategory = cat),
                    scaleDown: 0.92,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? SettlrColors.primary : const Color(0xFFF4F4F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        cat == 'ALL' ? 'All' : cat[0] + cat.substring(1).toLowerCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // Transaction list
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 28, color: Colors.grey),
                  const SizedBox(height: 6),
                  const Text(
                    'No transactions recorded',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                  ),
                  Text(
                    'Use Add Expense to log group payments.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0x0F000000)),
              itemBuilder: (ctx, i) {
                final exp = filtered[i];
                final isPayer = exp.paid_by == widget.currentUserId;
                final myPart = exp.participants.where((p) => p.user_id == widget.currentUserId).firstOrNull;
                final myShare = myPart != null ? (myPart.share_amount / 100) : 0.0;

                return BouncyPress(
                  onTap: () => widget.onSelectExpense(exp),
                  scaleDown: 0.98,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        // Category Icon box
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F4F5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0x14000000)),
                          ),
                          child: Center(
                            child: Text(
                              (exp.category != null && exp.category!.isNotEmpty)
                                  ? exp.category!.substring(0, 1).toUpperCase()
                                  : 'E',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: SettlrColors.textMain),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Title and paid by subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exp.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: SettlrColors.textMain,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Paid by ${isPayer ? "You" : exp.payer_name ?? "Member"} · ${_formatDate(exp.expense_date)}',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Amount & Lent / Borrowed Tag
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatMoney(exp.amount / 100, widget.currency),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: SettlrColors.textMain,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (isPayer)
                              Text(
                                '+${_formatMoney((exp.amount / 100) - myShare, widget.currency)} lent',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: SettlrColors.positive,
                                ),
                              )
                            else if (myShare > 0)
                              Text(
                                '-${_formatMoney(myShare, widget.currency)} share',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: SettlrColors.negative,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
