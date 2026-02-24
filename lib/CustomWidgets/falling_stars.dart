import 'dart:math';
import 'package:flutter/material.dart';

class MeteorShower extends StatefulWidget {
  final int meteorCount;
  final double maxSpeed;
  final double minSize;
  final double maxSize;
  final Color meteorColor;

  const MeteorShower({
    super.key,
    this.meteorCount = 10,
    this.maxSpeed = 8.0,
    this.minSize = 1.0,
    this.maxSize = 3.0,
    this.meteorColor = Colors.white,
  });

  @override
  State<MeteorShower> createState() => _MeteorShowerState();
}

class _MeteorShowerState extends State<MeteorShower>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Meteor> _meteors;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() {
        _updateMeteors();
      });
    _controller.repeat();
    _meteors = [];
  }

  void _initMeteors(Size size) {
    if (_meteors.isNotEmpty) return;
    for (int i = 0; i < widget.meteorCount; i++) {
      _meteors.add(_spawnMeteor(size, true));
    }
  }

  Meteor _spawnMeteor(Size size, bool initial) {
    double startX = _random.nextDouble() * size.width * 1.5 - size.width * 0.5;
    double startY = initial ? _random.nextDouble() * size.height : -100 - _random.nextDouble() * 500;
    
    // Diagonal movement (top-left to bottom-right or top-right to bottom-left)
    // Let's go top-right to bottom-left as requested "white comet" usually implies diagonal
    return Meteor(
      x: startX,
      y: startY,
      speed: (_random.nextDouble() * widget.maxSpeed) + 4.0,
      size: (_random.nextDouble() * (widget.maxSize - widget.minSize)) + widget.minSize,
      length: (_random.nextDouble() * 50) + 50, // Tail length
      angle: pi / 4, // 45 degrees
      opacity: _random.nextDouble() * 0.6 + 0.4,
    );
  }

  void _updateMeteors() {
    setState(() {
      for (var meteor in _meteors) {
        meteor.x -= meteor.speed * cos(meteor.angle); // Move left
        meteor.y += meteor.speed * sin(meteor.angle); // Move down

        if (meteor.y > MediaQuery.of(context).size.height + 100 || meteor.x < -100) {
          // Reset meteor
           double startX = _random.nextDouble() * MediaQuery.of(context).size.width * 1.5;
           meteor.x = startX;
           meteor.y = -100 - _random.nextDouble() * 500;
           meteor.speed = (_random.nextDouble() * widget.maxSpeed) + 4.0;
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _initMeteors(Size(constraints.maxWidth, constraints.maxHeight));
        return CustomPaint(
          size: Size.infinite,
          painter: MeteorPainter(_meteors, widget.meteorColor),
        );
      },
    );
  }
}

class Meteor {
  double x;
  double y;
  double speed;
  double size;
  double length;
  double angle;
  double opacity;

  Meteor({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.length,
    required this.angle,
    required this.opacity,
  });
}

class MeteorPainter extends CustomPainter {
  final List<Meteor> meteors;
  final Color meteorColor;

  MeteorPainter(this.meteors, this.meteorColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (var meteor in meteors) {
      // Draw tail vertically fading
      final tailPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            meteorColor.withOpacity(0.0),
            meteorColor.withOpacity(meteor.opacity),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ).createShader(Rect.fromPoints(
          Offset(meteor.x + meteor.length * cos(meteor.angle), meteor.y - meteor.length * sin(meteor.angle)),
          Offset(meteor.x, meteor.y),
        ));

      tailPaint.strokeWidth = meteor.size;
      
      // Calculate tail end point based on angle (opposite direction of movement)
      // Moving moving down-left, tail points up-right
      double tailEndX = meteor.x + meteor.length * cos(meteor.angle);
      double tailEndY = meteor.y - meteor.length * sin(meteor.angle);

      canvas.drawLine(
        Offset(tailEndX, tailEndY),
        Offset(meteor.x, meteor.y),
        tailPaint,
      );

      // Draw head
      paint.color = meteorColor.withOpacity(meteor.opacity);
      canvas.drawCircle(Offset(meteor.x, meteor.y), meteor.size, paint);
      
       // Glow
      canvas.drawCircle(
        Offset(meteor.x, meteor.y),
        meteor.size * 2,
        Paint()..color = meteorColor.withOpacity(meteor.opacity * 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
