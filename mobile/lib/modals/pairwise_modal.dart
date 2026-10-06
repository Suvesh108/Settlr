import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class PairwiseModal extends StatelessWidget {
  final Group group;
  final String targetUserId;
  final String targetUserName;
  final List<PairwiseDebt> pairwise;
  final void Function(String toUserId, int amountPaise) onSettleUp;

  const PairwiseModal({
    super.key,
    required this.group,
    required this.targetUserId,
    required this.targetUserName,
    required this.pairwise,
    required this.onSettleUp,
  });

  @override
  Widget build(BuildContext context) {
    final currency = group.currency;
    final symbol = currency == 'INR' ? '₹' : currency;
    final myId = ApiService.currentUser?.id ?? '';

    // Find bilateral record
    PairwiseDebt? debtRecord;
    for (final p in pairwise) {
      if ((p.userA == targetUserId && p.userB == myId) ||
          (p.userB == targetUserId && p.userA == myId)) {
        debtRecord = p;
        break;
      }
    }

    int netDebt = 0; // > 0: myId owes targetUserId; < 0: targetUserId owes myId
    if (debtRecord != null) {
      if (debtRecord.userA == targetUserId) {
        netDebt = debtRecord.netDebt;
      } else {
        netDebt = -debtRecord.netDebt;
      }
    }

    final youOwe = netDebt > 0;
    final theyOwe = netDebt < 0;
    final isSquared = netDebt == 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: SettlrColors.primary,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Center(
                      child: Text(
                        targetUserName.isNotEmpty ? targetUserName.substring(0, 1).toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        targetUserName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                      ),
                      const Text(
                        'Mutual Bilateral Standing',
                        style: TextStyle(fontSize: 11, color: SettlrColors.textMuted),
                      ),
                    ],
                  ),
                ],
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
          const SizedBox(height: 20),

          // Standing display card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Direct Mutual Debt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettlrColors.textMuted)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$symbol${(netDebt.abs() / 100).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: youOwe ? SettlrColors.negative : theyOwe ? SettlrColors.positive : SettlrColors.textMain,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSquared
                            ? SettlrColors.positiveBg
                            : youOwe
                                ? SettlrColors.negativeBg
                                : SettlrColors.positiveBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isSquared
                            ? 'All settled up'
                            : youOwe
                                ? 'You owe $targetUserName'
                                : '$targetUserName owes you',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSquared ? SettlrColors.positive : youOwe ? SettlrColors.negative : SettlrColors.positive,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isSquared
                    ? 'No pending mutual debts between you and $targetUserName.'
                    : youOwe
                        ? 'Transfer funds to zero out your mutual account with $targetUserName.'
                        : '$targetUserName has outstanding balances to settle with you.',
                  style: const TextStyle(fontSize: 11, color: SettlrColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (youOwe)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SettlrColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onSettleUp(targetUserId, netDebt);
                },
                icon: const Icon(Icons.send, size: 16, color: Colors.white),
                label: Text(
                  'Settle Up with $targetUserName',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
