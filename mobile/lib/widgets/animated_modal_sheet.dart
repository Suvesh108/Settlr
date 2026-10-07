import 'dart:ui';
import 'package:flutter/material.dart';
import 'motion_wrapper.dart';

/// Shows a spring-animated modal bottom sheet matching web's AnimatedModal.tsx
Future<T?> showSettlrModalSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x66000000), // backdrop 40% opacity
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, anim, secAnim) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: child,
        ),
      );
    },
    transitionBuilder: (ctx, anim, secAnim, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: SettlrCurves.spring,
        reverseCurve: Curves.easeInCubic,
      );

      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 4.0 * anim.value,
          sigmaY: 4.0 * anim.value,
        ),
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// Modal wrapper container with top handle and keyboard avoidance
class SettlrModalContainer extends StatelessWidget {
  final Widget child;
  final double maxHeightRatio;

  const SettlrModalContainer({
    super.key,
    required this.child,
    this.maxHeightRatio = 0.92,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * maxHeightRatio;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      margin: EdgeInsets.only(
        left: 8,
        right: 8,
        bottom: media.viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x1F000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag / Handle Indicator
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD4D4D8),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
