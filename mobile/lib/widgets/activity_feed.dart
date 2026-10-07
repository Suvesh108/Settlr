import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import 'motion_wrapper.dart';

class ActivityFeed extends StatelessWidget {
  final List<ActivityItem> activity;

  const ActivityFeed({super.key, required this.activity});

  String _formatRelativeTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return timestamp;
    }
  }

  IconData _getIconForType(String type) {
    switch (type.toUpperCase()) {
      case 'EXPENSE_CREATED':
        return Icons.receipt_long_outlined;
      case 'EXPENSE_REVERSED':
        return Icons.undo;
      case 'SETTLEMENT_RECORDED':
        return Icons.payment_outlined;
      case 'SETTLEMENT_CONFIRMED':
        return Icons.check_circle_outline;
      case 'MEMBER_JOINED':
        return Icons.person_add_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  Color _getColorForType(String type) {
    switch (type.toUpperCase()) {
      case 'EXPENSE_CREATED':
        return SettlrColors.primary;
      case 'EXPENSE_REVERSED':
        return SettlrColors.negative;
      case 'SETTLEMENT_RECORDED':
        return Colors.amber.shade700;
      case 'SETTLEMENT_CONFIRMED':
        return SettlrColors.positive;
      case 'MEMBER_JOINED':
        return Colors.blue.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettlrPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Activity Log',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: SettlrColors.textMain,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${activity.length} updates',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (activity.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.timeline, size: 28, color: Colors.grey),
                  const SizedBox(height: 6),
                  const Text(
                    'No recent activity',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                  ),
                  Text(
                    'All group events will appear here in chronological order.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activity.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0x0F000000)),
              itemBuilder: (ctx, i) {
                final item = activity[i];
                final icon = _getIconForType(item.activity_type);
                final iconColor = _getColorForType(item.activity_type);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(icon, size: 16, color: iconColor),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.description,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: SettlrColors.textMain,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatRelativeTime(item.created_at),
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
