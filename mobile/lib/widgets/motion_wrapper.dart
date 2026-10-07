import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Framer Motion cubic-bezier(0.16, 1, 0.3, 1) and spring physics for Settlr
class SettlrCurves {
  static const Curve spring = Cubic(0.16, 1.0, 0.3, 1.0);
  static const Curve snappy = Cubic(0.2, 0.8, 0.2, 1.0);
  static const Duration fastDuration = Duration(milliseconds: 160);
  static const Duration normalDuration = Duration(milliseconds: 240);
  static const Duration smoothDuration = Duration(milliseconds: 320);
}

/// Interactive micro-interaction wrapper matching web's whileTap={{ scale: 0.94 }}
/// Provides instantaneous spring downscale and tactile haptic feedback.
class BouncyPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final bool enableHaptics;
  final HitTestBehavior behavior;

  const BouncyPress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.94,
    this.enableHaptics = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<BouncyPress> createState() => _BouncyPressState();
}

class _BouncyPressState extends State<BouncyPress> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: SettlrCurves.spring,
    ));
  }

  @override
  void didUpdateWidget(covariant BouncyPress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scaleDown != widget.scaleDown) {
      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: widget.scaleDown,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: SettlrCurves.spring,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Standardized card panel surface matching CSS .settlr-panel
class SettlrPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color backgroundColor;
  final double borderRadius;
  final Border? border;
  final VoidCallback? onTap;

  const SettlrPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.backgroundColor = Colors.white,
    this.borderRadius = 20.0,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return BouncyPress(
        onTap: onTap,
        scaleDown: 0.98,
        child: container,
      );
    }
    return container;
  }
}

/// Sliding animated pill indicator for tab bars and segmented controls
class SlidingPillSegment extends StatelessWidget {
  final int selectedIndex;
  final int itemCount;
  final List<Widget> children;
  final ValueChanged<int> onSelected;
  final Color activeColor;
  final Color inactiveBackgroundColor;
  final double height;
  final EdgeInsets padding;

  const SlidingPillSegment({
    super.key,
    required this.selectedIndex,
    required this.itemCount,
    required this.children,
    required this.onSelected,
    this.activeColor = Colors.white,
    this.inactiveBackgroundColor = const Color(0xFFF4F4F5),
    this.height = 38.0,
    this.padding = const EdgeInsets.all(3.0),
  });

  @override
  Widget build(BuildContext context) {
    assert(children.length == itemCount);
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: inactiveBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth) / itemCount;
          final pillHeight = constraints.maxHeight;

          return Stack(
            children: [
              // Gliding active pill indicator with Framer Motion spring physics
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: SettlrCurves.spring,
                left: selectedIndex * itemWidth,
                top: 0,
                width: itemWidth,
                height: pillHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),

              // Item buttons
              Row(
                children: List.generate(itemCount, (index) {
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (index != selectedIndex) {
                          HapticFeedback.selectionClick();
                          onSelected(index);
                        }
                      },
                      child: Center(
                        child: children[index],
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
