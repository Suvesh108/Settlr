import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import 'motion_wrapper.dart';
import 'confetti_overlay.dart';

class BilateralDebtMatrix extends StatelessWidget {
  final String groupId;
  final String currency;
  final String? creatorId;
  final String currentUserId;
  final List<UserBalance> balances;
  final List<RecommendedTransfer> transfers;
  final List<Settlement> settlements;
  final Function(RecommendedTransfer) onPayTransfer;
  final Function(UserBalance) onMemberTap;
  final Function(String settlementId) onConfirmSettlement;

  const BilateralDebtMatrix({
    super.key,
    required this.groupId,
    required this.currency,
    this.creatorId,
    required this.currentUserId,
    required this.balances,
    required this.transfers,
    required this.settlements,
    required this.onPayTransfer,
    required this.onMemberTap,
    required this.onConfirmSettlement,
  });

  String _formatMoney(double amount, String curr) {
    final sym = curr == 'INR' ? '₹' : curr == 'USD' ? '\$' : curr == 'EUR' ? '€' : '£';
    return '$sym${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final pendingSettlements = settlements.where((s) => s.status == 'PAYMENT_RECORDED').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Pending Confirmations Banner (if any)
        if (pendingSettlements.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7).withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_filled, size: 16, color: Color(0xFFB45309)),
                    const SizedBox(width: 6),
                    Text(
                      'PENDING SETTLEMENTS (${pendingSettlements.length})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...pendingSettlements.map((s) {
                  final isReceiver = s.to_user == currentUserId;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${s.from_user_name ?? "Member"} paid ${_formatMoney(s.amount / 100, currency)} to ${s.to_user_name ?? "Member"}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: SettlrColors.textMain,
                            ),
                          ),
                        ),
                        if (isReceiver)
                          BouncyPress(
                            onTap: () {
                              onConfirmSettlement(s.id);
                              ConfettiOverlayController.instance.blast();
                            },
                            scaleDown: 0.92,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: SettlrColors.positive,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, size: 13, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Confirm',
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
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 2. Settlement Plan Card
        SettlrPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settlement Plan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: SettlrColors.textMain,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Minimum cashflow transfers to balance all accounts to zero',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 14),

              if (transfers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 28, color: SettlrColors.positive),
                      const SizedBox(height: 6),
                      const Text(
                        'All accounts are settled',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                      ),
                      Text(
                        'No transfers are needed between group members.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
              else
                ...transfers.map((t) {
                  final isSender = t.from_user == currentUserId;
                  final isReceiver = t.to_user == currentUserId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x14000000)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Sender -> Receiver flow
                        Expanded(
                          child: Row(
                            children: [
                                CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFFE4E4E7),
                                child: Text(
                                  t.from_user_name.isNotEmpty
                                      ? t.from_user_name.substring(0, 1).toUpperCase()
                                      : 'F',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black89),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  '${t.from_user_name.isNotEmpty ? t.from_user_name : "Member"}${isSender ? " (You)" : ""}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
                              ),
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFFE4E4E7),
                                child: Text(
                                  t.to_user_name.isNotEmpty
                                      ? t.to_user_name.substring(0, 1).toUpperCase()
                                      : 'T',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black89),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  '${t.to_user_name.isNotEmpty ? t.to_user_name : "Member"}${isReceiver ? " (You)" : ""}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Right: Amount and Pay button
                        Row(
                          children: [
                            Text(
                              _formatMoney(t.amount / 100.0, currency),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: SettlrColors.textMain,
                              ),
                            ),
                            if (isSender) ...[
                              const SizedBox(width: 8),
                              BouncyPress(
                                onTap: () => onPayTransfer(t),
                                scaleDown: 0.92,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: SettlrColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Pay',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3. Member Standings Grid
        SettlrPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Member Standings',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: SettlrColors.textMain,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Click any member to inspect mutual expenses & bilateral history',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 14),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 3 : 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: isWide ? 2.2 : 2.0,
                    ),
                    itemCount: balances.length,
                    itemBuilder: (ctx, i) {
                      final m = balances[i];
                      final isMe = m.user_id == currentUserId;
                      final isCreditor = m.net_balance > 0.009;
                      final isDebtor = m.net_balance < -0.009;

                      return BouncyPress(
                        onTap: isMe ? null : () => onMemberTap(m),
                        scaleDown: isMe ? 1.0 : 0.95,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x14000000)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 11,
                                    backgroundColor: SettlrColors.primary,
                                    child: Text(
                                      m.name.isNotEmpty ? m.name.substring(0, 1).toUpperCase() : 'M',
                                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${m.name}${isMe ? " (You)" : ""}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: SettlrColors.textMain,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (creatorId != null && creatorId == m.user_id)
                                    const Text('★', style: TextStyle(color: Colors.amber, fontSize: 11)),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Balance',
                                    style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                                  ),
                                  Text(
                                    '${isCreditor ? "+" : isDebtor ? "-" : ""}${_formatMoney(m.net_balance.abs(), currency)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: isCreditor
                                          ? SettlrColors.positive
                                          : isDebtor
                                              ? SettlrColors.negative
                                              : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
