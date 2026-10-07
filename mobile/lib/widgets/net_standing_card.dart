import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import 'motion_wrapper.dart';

class NetStandingCard extends StatelessWidget {
  final Group group;
  final List<UserBalance> balances;
  final double totalSpending;
  final String currentUserId;
  final VoidCallback onAddExpense;
  final VoidCallback onRecordSettlement;
  final VoidCallback onOpenSettings;

  const NetStandingCard({
    super.key,
    required this.group,
    required this.balances,
    required this.totalSpending,
    required this.currentUserId,
    required this.onAddExpense,
    required this.onRecordSettlement,
    required this.onOpenSettings,
  });

  String _formatMoney(double amount, String currency) {
    final sym = currency == 'INR' ? '₹' : currency == 'USD' ? '\$' : currency == 'EUR' ? '€' : '£';
    return '$sym${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final myBalanceObj = balances.firstWhere(
      (b) => b.user_id == currentUserId,
      orElse: () => UserBalance(userId: currentUserId, name: 'You', netBalance: 0),
    );
    final myBalance = myBalanceObj.net_balance;
    final isCreditor = myBalance > 0.009;
    final isDebtor = myBalance < -0.009;
    final isSettled = !isCreditor && !isDebtor;

    return SettlrPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Group Title, Ledger Version Badge, Settings Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: SettlrColors.textMain,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F4F5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0x14000000)),
                          ),
                          child: Text(
                            'v${group.ledger_version}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      group.description.isNotEmpty
                          ? group.description
                          : 'Automated bilateral settlement and shared expense ledger.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BouncyPress(
                onTap: onOpenSettings,
                scaleDown: 0.90,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x1A000000)),
                  ),
                  child: const Icon(Icons.settings_outlined, size: 18, color: Colors.grey),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Centerpiece: Fluid Standing Display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x14000000)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Balance in this Group',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),

                // Amount & Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${isCreditor ? '+' : isDebtor ? '-' : ''}${_formatMoney(myBalance.abs(), group.currency)}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: isCreditor
                            ? SettlrColors.positive
                            : isDebtor
                                ? SettlrColors.negative
                                : SettlrColors.textMain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSettled
                            ? SettlrColors.positiveBg
                            : isCreditor
                                ? SettlrColors.positiveBg
                                : SettlrColors.negativeBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSettled || isCreditor
                              ? SettlrColors.positive.withOpacity(0.3)
                              : SettlrColors.negative.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSettled
                                ? Icons.check_circle_outline
                                : isCreditor
                                    ? Icons.arrow_outward
                                    : Icons.arrow_downward,
                            size: 12,
                            color: isSettled || isCreditor
                                ? SettlrColors.positive
                                : SettlrColors.negative,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isSettled
                                ? 'All settled up'
                                : isCreditor
                                    ? 'You are owed'
                                    : 'You owe money',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSettled || isCreditor
                                  ? SettlrColors.positive
                                  : SettlrColors.negative,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),
                Text(
                  isSettled
                      ? 'Zero pending dues. All your group expenses are fully squared.'
                      : isCreditor
                          ? 'Members with pending balances will transfer funds to square accounts.'
                          : 'Use Settle Up to transfer your dues and zero out accounts.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0x14000000)),
                const SizedBox(height: 12),

                // Group Total Spending & Quick Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Group Spending',
                          style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          _formatMoney(totalSpending, group.currency),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: SettlrColors.textMain,
                          ),
                        ),
                        Text(
                          '${group.members?.length ?? 0} active members',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        BouncyPress(
                          onTap: onAddExpense,
                          scaleDown: 0.94,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: SettlrColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.add, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Add Expense',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        BouncyPress(
                          onTap: onRecordSettlement,
                          scaleDown: 0.94,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0x1F000000)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.payment, size: 14, color: SettlrColors.textMain),
                                SizedBox(width: 4),
                                Text(
                                  'Settle Up',
                                  style: TextStyle(
                                    color: SettlrColors.textMain,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
