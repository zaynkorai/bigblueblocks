import 'package:flutter/material.dart';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:bigblueblocks/main.dart';

class TrailPoint {
  final Offset position;
  final double rotation;
  final double opacity;
  TrailPoint({
    required this.position,
    required this.rotation,
    required this.opacity,
  });
}

class SparkParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double life; // 1.0 down to 0.0

  SparkParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.life,
  });
}

class CustomSplashScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const CustomSplashScreen({
    super.key,
    required this.onFinished,
  });

  @override
  State<CustomSplashScreen> createState() => _CustomSplashScreenState();
}

class _CustomSplashScreenState extends State<CustomSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<TrailPoint> _trail = [];
  final List<SparkParticle> _particles = [];
  final List<double> _rotations = [0.0];
  final Random _rnd = Random();

  List<Offset> _points = [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    // Remove the native splash screen as soon as this widget is presented
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    // Generate cumulative rotations: at each leg, rotate by 180 (pi) or 360 (2*pi) randomly
    double currentAngle = 0.0;
    for (int i = 0; i < 4; i++) {
      double step = _rnd.nextBool() ? pi : 2 * pi;
      currentAngle += step;
      _rotations.add(currentAngle);
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _controller.addListener(_onAnimationTick);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnimationTick);
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationTick() {
    if (!mounted || _points.isEmpty) return;

    double t = _controller.value;
    int segment = (t * 4).floor().clamp(0, 3);
    double segmentT = (t * 4) - segment;
    double curvedT = Curves.easeInOut.transform(segmentT);

    Offset startPoint = _points[segment];
    Offset endPoint = _points[segment + 1];
    Offset currentPosition = Offset.lerp(startPoint, endPoint, curvedT)!;

    double startAngle = _rotations[segment];
    double endAngle = _rotations[segment + 1];
    double currentAngle = startAngle + (endAngle - startAngle) * curvedT;

    // 1. Add current state to trail
    _trail.add(TrailPoint(
      position: currentPosition,
      rotation: currentAngle,
      opacity: 0.6,
    ));

    // Limit trail length
    if (_trail.length > 15) {
      _trail.removeAt(0);
    }

    // Decay older trail points
    for (int i = 0; i < _trail.length; i++) {
      _trail[i] = TrailPoint(
        position: _trail[i].position,
        rotation: _trail[i].rotation,
        opacity: (_trail[i].opacity - 0.04).clamp(0.0, 1.0),
      );
    }

    // 2. Spawn sparks near the Z-tetromino center
    if (_rnd.nextDouble() < 0.6) {
      final Color sparkColor = _rnd.nextBool()
          ? gameYellow // Electric Yellow
          : const Color(0xFF2E7DFF); // Glowing Cyan/Blue

      _particles.add(SparkParticle(
        position: currentPosition +
            Offset(
              (_rnd.nextDouble() - 0.5) * 30,
              (_rnd.nextDouble() - 0.5) * 30,
            ),
        velocity: Offset(
          (_rnd.nextDouble() - 0.5) * 120,
          (_rnd.nextDouble() - 0.5) * 120,
        ),
        color: sparkColor,
        size: _rnd.nextDouble() * 3.5 + 1.5,
        life: 1.0,
      ));
    }

    // 3. Update sparks
    const double dt = 0.016; // Approx. 60fps tick rate
    for (int i = _particles.length - 1; i >= 0; i--) {
      var p = _particles[i];
      p.position += p.velocity * dt;
      p.velocity *= 0.94; // friction
      p.life -= dt * 2.2; // decay life
      if (p.life <= 0) {
        _particles.removeAt(i);
      }
    }

    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final size = MediaQuery.of(context).size;
      final w = size.width;
      final h = size.height;

      // Define a 5-point zig-zag trajectory down the screen
      _points = [
        Offset(w * 0.15, h * 0.15),
        Offset(w * 0.85, h * 0.32),
        Offset(w * 0.15, h * 0.50),
        Offset(w * 0.85, h * 0.68),
        Offset(w * 0.15, h * 0.85),
      ];
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;

    // Calculate current positions & rotation
    double t = _controller.value;
    int segment = (t * 4).floor().clamp(0, 3);
    double segmentT = (t * 4) - segment;
    double curvedT = Curves.easeInOut.transform(segmentT);

    Offset currentPosition = Offset.zero;
    double currentAngle = 0.0;

    if (_points.isNotEmpty) {
      Offset startPoint = _points[segment];
      Offset endPoint = _points[segment + 1];
      currentPosition = Offset.lerp(startPoint, endPoint, curvedT)!;

      double startAngle = _rotations[segment];
      double endAngle = _rotations[segment + 1];
      currentAngle = startAngle + (endAngle - startAngle) * curvedT;
    }

    // Pulse value for the logo text
    double pulse = 1.0 + 0.02 * sin(t * 2 * pi * 3);

    return Scaffold(
      backgroundColor: const Color(0xFF010816), // Matching bgDarkBlue
      body: Stack(
        children: [

          // Custom Painter for trails, particles, and the Z-tetromino block
          Positioned.fill(
            child: CustomPaint(
              painter: SplashAnimationPainter(
                trail: _trail,
                particles: _particles,
                currentPos: currentPosition,
                currentRot: currentAngle,
                cellSize: (w * 0.082).clamp(24.0, 36.0),
              ),
            ),
          ),

          // Logo and Tagline Centered
          Center(
            child: Transform.scale(
              scale: pulse,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'BIG BLUE BLOCKS',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.orbitron(
                      fontSize: (w * 0.075).clamp(24.0, 36.0),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.0,

                    ),
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SplashAnimationPainter extends CustomPainter {
  final List<TrailPoint> trail;
  final List<SparkParticle> particles;
  final Offset currentPos;
  final double currentRot;
  final double cellSize;

  SplashAnimationPainter({
    required this.trail,
    required this.particles,
    required this.currentPos,
    required this.currentRot,
    required this.cellSize,
  });

  // Relative coordinates of cells for a Z-tetromino centered at (0,0)
  static final List<Offset> zCells = [
    const Offset(-1.0, -0.5),
    const Offset(0.0, -0.5),
    const Offset(0.0, 0.5),
    const Offset(1.0, 0.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw trail
    for (int i = 0; i < trail.length; i++) {
      final pt = trail[i];
      // Fade out and scale down slightly for older trail points
      final double trailScale = 0.5 + 0.5 * (i / trail.length);
      final double opacity = pt.opacity * (i / trail.length);
      _drawZPiece(canvas, pt.position, pt.rotation, cellSize * trailScale,
          opacity: opacity, drawNeonBorderOnly: true);
    }

    // 2. Draw spark particles
    for (var p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.life)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p.position, p.size * p.life, paint);
    }

    // 3. Draw current active Z-tetromino block
    _drawZPiece(canvas, currentPos, currentRot, cellSize, opacity: 1.0);
  }

  void _drawZPiece(
    Canvas canvas,
    Offset position,
    double rotation,
    double cs, {
    required double opacity,
    bool drawNeonBorderOnly = false,
  }) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);

    for (var cellOffset in zCells) {
      final double rx = cellOffset.dx * cs;
      final double ry = cellOffset.dy * cs;
      final Rect rect = Rect.fromLTWH(rx, ry, cs, cs).deflate(1.5);
      final RRect rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.22));

      if (drawNeonBorderOnly) {
        // Draw outline for trail
        final Paint strokePaint = Paint()
          ..color = const Color(0xFF2E7DFF).withValues(alpha: opacity * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawRRect(rrect, strokePaint);
      } else {
        // Draw solid glowing block with linear gradient
        final Paint fillPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2E7DFF).withValues(alpha: opacity), // Blue
              gameYellow.withValues(alpha: opacity), // Yellow
            ],
          ).createShader(rect);

        // Background block shadow/glow
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = const Color(0xFF2E7DFF).withValues(alpha: opacity * 0.3)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, cs * 0.3),
        );
        
        canvas.drawRRect(rrect, fillPaint);

        // White inner border highlight
        final Paint highlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              rect.deflate(0.8), Radius.circular(cs * 0.18)),
          highlightPaint,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
