import 'dart:math' as math;
import 'package:flutter/material.dart';

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double rotation;
  double rotationSpeed;
  double size;
  Color color;
  double opacity;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.color,
    required this.opacity,
  });
}

class ConfettiOverlayController extends ChangeNotifier {
  static final ConfettiOverlayController instance = ConfettiOverlayController._();
  ConfettiOverlayController._();

  bool _isBlasting = false;
  bool get isBlasting => _isBlasting;

  void blast() {
    _isBlasting = true;
    notifyListeners();
  }

  void _finish() {
    _isBlasting = false;
    notifyListeners();
  }
}

class ConfettiOverlay extends StatefulWidget {
  final Widget child;

  const ConfettiOverlay({super.key, required this.child});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();

  final List<Color> _palette = const [
    Color(0xFF0EA5E9), // Sky 500
    Color(0xFF10B981), // Emerald 500
    Color(0xFFF59E0B), // Amber 500
    Color(0xFF8B5CF6), // Purple 500
    Color(0xFFEC4899), // Pink 500
    Color(0xFF3B82F6), // Blue 500
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _animController.addListener(() {
      _updateParticles();
      setState(() {});
    });

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _particles.clear();
        ConfettiOverlayController.instance._finish();
      }
    });

    ConfettiOverlayController.instance.addListener(_onBlastRequested);
  }

  @override
  void dispose() {
    ConfettiOverlayController.instance.removeListener(_onBlastRequested);
    _animController.dispose();
    super.dispose();
  }

  void _onBlastRequested() {
    if (ConfettiOverlayController.instance.isBlasting) {
      _initParticles();
      _animController.forward(from: 0.0);
    }
  }

  void _initParticles() {
    _particles.clear();
    const particleCount = 65;

    for (int i = 0; i < particleCount; i++) {
      final angle = -math.pi / 2 + (_random.nextDouble() - 0.5) * 1.6;
      final speed = 8.0 + _random.nextDouble() * 12.0;

      _particles.add(ConfettiParticle(
        x: 0.5, // Center origin
        y: 0.75, // Lower third origin
        vx: math.cos(angle) * speed * 0.003,
        vy: math.sin(angle) * speed * 0.003,
        rotation: _random.nextDouble() * math.pi * 2,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.3,
        size: 7.0 + _random.nextDouble() * 5.0,
        color: _palette[_random.nextInt(_palette.length)],
        opacity: 1.0,
      ));
    }
  }

  void _updateParticles() {
    final progress = _animController.value;
    for (var p in _particles) {
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.00015; // Gravity
      p.vx *= 0.985; // Air drag
      p.rotation += p.rotationSpeed;

      if (progress > 0.65) {
        p.opacity = ((1.0 - progress) / 0.35).clamp(0.0, 1.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_animController.isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ConfettiPainter(particles: _particles),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final px = p.x * size.width;
      final py = p.y * size.height;

      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: p.size,
        height: p.size * 0.6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
