import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import 'motion_wrapper.dart';

class HapticDockItem {
  final String id;
  final String label;
  final IconData icon;

  const HapticDockItem({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class HapticDock extends StatelessWidget {
  final String activeTab;
  final ValueChanged<String> onTabChanged;
  final VoidCallback onAddExpense;
  final bool showFab;

  const HapticDock({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    required this.onAddExpense,
    this.showFab = true,
  });

  static const List<HapticDockItem> items = [
    HapticDockItem(
      id: 'overview',
      label: 'Overview',
      icon: Icons.dashboard_outlined,
    ),
    HapticDockItem(
      id: 'expenses',
      label: 'Expenses',
      icon: Icons.receipt_long_outlined,
    ),
    HapticDockItem(
      id: 'settlements',
      label: 'Settle',
      icon: Icons.payment_outlined,
    ),
    HapticDockItem(
      id: 'activity',
      label: 'Activity',
      icon: Icons.timeline_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final activeIndex = items.indexWhere((it) => it.id == activeTab);
    final safeActiveIndex = activeIndex >= 0 ? activeIndex : 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Bottom Navigation Bar with fluid gliding indicator
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            border: const Border(
              top: BorderSide(color: Color(0x1A000000)),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / items.length;
                  final pillHeight = constraints.maxHeight;

                  return Stack(
                    children: [
                      // Gliding active indicator pill
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 240),
                        curve: SettlrCurves.spring,
                        left: safeActiveIndex * itemWidth,
                        top: 0,
                        width: itemWidth,
                        height: pillHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F4F5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      // Navigation items
                      Row(
                        children: List.generate(items.length, (i) {
                          final item = items[i];
                          final isActive = i == safeActiveIndex;

                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (activeTab != item.id) {
                                  HapticFeedback.selectionClick();
                                  onTabChanged(item.id);
                                }
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 20,
                                    color: isActive
                                        ? SettlrColors.primary
                                        : Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isActive
                                          ? SettlrColors.primary
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),

        // Floating Action Button (+ Add Expense) in bottom right above dock
        if (showFab)
          Positioned(
            right: 16,
            top: -52,
            child: BouncyPress(
              onTap: onAddExpense,
              scaleDown: 0.92,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: SettlrColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.add, size: 14, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Add Expense',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
