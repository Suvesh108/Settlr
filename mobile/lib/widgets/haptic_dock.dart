import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import 'motion_wrapper.dart';

class HapticDockItem {
  final String id;
  final IconData icon;

  const HapticDockItem({
    required this.id,
    required this.icon,
  });
}

class HapticDock extends StatelessWidget {
  final String activeTab;
  final ValueChanged<String> onTabChanged;

  const HapticDock({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
  });

  static const List<HapticDockItem> items = [
    HapticDockItem(
      id: 'overview',
      icon: Icons.dashboard_outlined,
    ),
    HapticDockItem(
      id: 'expenses',
      icon: Icons.receipt_long_outlined,
    ),
    HapticDockItem(
      id: 'settlements',
      icon: Icons.payments_outlined,
    ),
    HapticDockItem(
      id: 'activity',
      icon: Icons.history_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final activeIndex = items.indexWhere((it) => it.id == activeTab);
    final safeActiveIndex = activeIndex >= 0 ? activeIndex : 0;

    return Container(
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
          height: 52,
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

                  // Minimal icon-only navigation items (no redundant text)
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
                          child: Center(
                            child: Icon(
                              item.icon,
                              size: 22,
                              color: isActive
                                  ? SettlrColors.primary
                                  : Colors.grey.shade400,
                            ),
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
    );
  }
}
