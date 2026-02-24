import 'dart:math';
import 'package:flutter/material.dart';

class OrbitAnimation extends StatefulWidget {
  final int ringCount;
  final int particlesPerRing;
  final double baseRadius;
  final double strokeWidth;
  final Color ringColor;
  final Color particleColor;

  const OrbitAnimation({
    super.key,
    this.ringCount = 3,
    this.particlesPerRing = 2,
    this.baseRadius = 100.0,
    this.strokeWidth = 1.0,
    this.ringColor = Colors.white10,
    this.particleColor = Colors.white,
  });

  @override
  State<OrbitAnimation> createState() => _OrbitAnimationState();
}

class _OrbitAnimationState extends State<OrbitAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: OrbitPainter(
            animationValue: _controller.value,
            ringCount: widget.ringCount,
            particlesPerRing: widget.particlesPerRing,
            baseRadius: widget.baseRadius,
            strokeWidth: widget.strokeWidth,
            ringColor: widget.ringColor,
            particleColor: widget.particleColor,
          ),
        );
      },
    );
  }
}

class OrbitPainter extends CustomPainter {
  final double animationValue;
  final int ringCount;
  final int particlesPerRing;
  final double baseRadius;
  final double strokeWidth;
  final Color ringColor;
  final Color particleColor;

  OrbitPainter({
    required this.animationValue,
    required this.ringCount,
    required this.particlesPerRing,
    required this.baseRadius,
    required this.strokeWidth,
    required this.ringColor,
    required this.particleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final particlePaint = Paint()
      ..color = particleColor
      ..style = PaintingStyle.fill;

    // Responsive radius scaling
    double maxRadius = min(size.width, size.height) * 0.8;
    double radiusStep = (maxRadius - baseRadius) / max(1, ringCount - 1);

    for (int i = 0; i < ringCount; i++) {
      double currentRadius = baseRadius + (i * radiusStep);
      
      // Draw ring
      canvas.drawCircle(center, currentRadius, ringPaint);

      // Draw particles on ring
      // Vary speed based on ring index (closer rings faster or slower as needed, usually closer = faster)
      double speedMultiplier = 1.0 + ((ringCount - 1 - i) * 0.5); 
      double ringRotation = (animationValue * 2 * pi * speedMultiplier);
      
      // Also randomize start angle per ring slightly or offset
      double offset = i * (pi / 4); 

      for (int p = 0; p < particlesPerRing; p++) {
        double angle = ringRotation + offset + (p * (2 * pi / particlesPerRing));
        double x = center.dx + currentRadius * cos(angle);
        double y = center.dy + currentRadius * sin(angle);

        // Particle size can vary slightly
        double particleSize = 2.0 + (i * 0.5);
        
        // Draw glow
        canvas.drawCircle(
          Offset(x, y),
          particleSize * 2.5,
          Paint()..color = particleColor.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );

        canvas.drawCircle(Offset(x, y), particleSize, particlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant OrbitPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
