import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math';

// ═══════════════════════════════════════════════════════
//  PARTICLE SHAPE ENUM
// ═══════════════════════════════════════════════════════

enum ParticleShape { circle, rect, star, triangle }

// ═══════════════════════════════════════════════════════
//  CELEBRATION PARTICLE
// ═══════════════════════════════════════════════════════

class CelebrationParticle {
  double x, y;
  double vx, vy;
  double gravity;
  double drag;
  double alpha;
  double life;
  double maxLife;
  double size;
  double rotation;
  double angularVelocity;
  Color color;
  ParticleShape shape;

  CelebrationParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    this.gravity = 400.0,
    this.drag = 0.98,
    this.alpha = 1.0,
    required this.life,
    required this.size,
    this.rotation = 0.0,
    this.angularVelocity = 0.0,
    required this.color,
    this.shape = ParticleShape.rect,
  }) : maxLife = life;

  bool get isDead => life <= 0 || alpha < 0.01;

  void update(double dt) {
    vx *= drag;
    vy *= drag;
    vy += gravity * dt;
    x += vx * dt;
    y += vy * dt;
    life -= dt;
    rotation += angularVelocity * dt;

    // Fade out in the last 40% of life
    double lifeRatio = (life / maxLife).clamp(0.0, 1.0);
    if (lifeRatio < 0.4) {
      alpha = (lifeRatio / 0.4).clamp(0.0, 1.0);
    }
  }
}

// ═══════════════════════════════════════════════════════
//  CELEBRATION OVERLAY WIDGET
// ═══════════════════════════════════════════════════════

class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({super.key});

  @override
  State<CelebrationOverlay> createState() => CelebrationOverlayState();
}

class CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  static const int _maxParticles = 200;
  final List<CelebrationParticle> _particles = [];
  final Random _rng = Random();
  late Ticker _ticker;
  Duration _lastTime = Duration.zero;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _ensureTickerRunning() {
    if (!_isActive && _particles.isNotEmpty) {
      _isActive = true;
      _lastTime = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastTime == Duration.zero) {
      _lastTime = elapsed;
      return;
    }

    double dt = (elapsed - _lastTime).inMicroseconds / 1000000.0;
    _lastTime = elapsed;

    // Clamp dt to avoid huge jumps if app was backgrounded
    dt = dt.clamp(0.0, 0.05);

    for (var p in _particles) {
      p.update(dt);
    }
    _particles.removeWhere((p) => p.isDead);

    if (_particles.isEmpty) {
      _isActive = false;
      _ticker.stop();
      _lastTime = Duration.zero;
    }

    setState(() {});
  }

  void _addParticle(CelebrationParticle p) {
    if (_particles.length >= _maxParticles) {
      _particles.removeAt(0); // Cull oldest
    }
    _particles.add(p);
  }

  // ─────────────────────────────────────────────────
  //  PUBLIC API
  // ─────────────────────────────────────────────────

  /// Burst particles from each cleared cell's screen position.
  void triggerLineClearBurst(List<Offset> cellCenters, List<Color> cellColors) {
    const shapes = ParticleShape.values;
    for (int i = 0; i < cellCenters.length; i++) {
      final center = cellCenters[i];
      int count = 6 + _rng.nextInt(4); // 6–9 particles per cell
      for (int j = 0; j < count; j++) {
        double angle = _rng.nextDouble() * 2 * pi;
        double speed = 100 + _rng.nextDouble() * 220;
        _addParticle(CelebrationParticle(
          x: center.dx,
          y: center.dy,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed - 80, // Upward bias
          gravity: 300 + _rng.nextDouble() * 200,
          drag: 0.96 + _rng.nextDouble() * 0.03,
          life: 0.6 + _rng.nextDouble() * 0.6,
          size: 6 + _rng.nextDouble() * 8, // Larger particles (6-14px)
          rotation: _rng.nextDouble() * 2 * pi,
          angularVelocity: (_rng.nextDouble() - 0.5) * 10,
          color: Colors.white,
          shape: shapes[_rng.nextInt(shapes.length)],
        ));
      }
    }
    _ensureTickerRunning();
    setState(() {});
  }

  /// Twin diagonal fountains from bottom corners. Intensity scales with combo.
  void triggerComboFountain(int comboCount) {
    final size = MediaQuery.of(context).size;
    int particlesPerSide = 12 + (comboCount - 1) * 6;
    particlesPerSide = particlesPerSide.clamp(12, 40);

    for (int side = 0; side < 2; side++) {
      double baseX = side == 0 ? 0 : size.width;
      double dirX = side == 0 ? 1.0 : -1.0;

      for (int i = 0; i < particlesPerSide; i++) {
        double angle = (pi / 4) + (_rng.nextDouble() - 0.5) * (pi / 6);
        double speed = 350 + _rng.nextDouble() * 350;
        _addParticle(CelebrationParticle(
          x: baseX + (_rng.nextDouble() - 0.5) * 20,
          y: size.height + 10,
          vx: cos(angle) * speed * dirX,
          vy: -sin(angle) * speed,
          gravity: 350 + _rng.nextDouble() * 150,
          drag: 0.97,
          life: 1.0 + _rng.nextDouble() * 0.8,
          size: 8 + _rng.nextDouble() * 10, // Larger size (8-18px)
          rotation: _rng.nextDouble() * 2 * pi,
          angularVelocity: (_rng.nextDouble() - 0.5) * 12,
          color: Colors.white,
          shape: ParticleShape.values[_rng.nextInt(ParticleShape.values.length)],
        ));
      }
    }
    _ensureTickerRunning();
    setState(() {});
  }

  /// Large radial starburst from board center.
  void triggerPerfectClear(Offset boardCenter) {
    int count = 70 + _rng.nextInt(30);

    for (int i = 0; i < count; i++) {
      double angle = (i / count) * 2 * pi + (_rng.nextDouble() - 0.5) * 0.3;
      double speed = 250 + _rng.nextDouble() * 450;
      _addParticle(CelebrationParticle(
        x: boardCenter.dx + (_rng.nextDouble() - 0.5) * 10,
        y: boardCenter.dy + (_rng.nextDouble() - 0.5) * 10,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        gravity: 120 + _rng.nextDouble() * 160,
        drag: 0.96,
        life: 1.0 + _rng.nextDouble() * 1.0,
        size: 8 + _rng.nextDouble() * 12, // Larger size (8-20px)
        rotation: _rng.nextDouble() * 2 * pi,
        angularVelocity: (_rng.nextDouble() - 0.5) * 15,
        color: Colors.white,
        shape: ParticleShape.values[_rng.nextInt(ParticleShape.values.length)],
      ));
    }
    _ensureTickerRunning();
    setState(() {});
  }

  /// Rising gold shimmer particles for level-up.
  void triggerLevelUp() {
    final size = MediaQuery.of(context).size;
    int count = 30 + _rng.nextInt(15);

    for (int i = 0; i < count; i++) {
      _addParticle(CelebrationParticle(
        x: _rng.nextDouble() * size.width,
        y: size.height + 10 + _rng.nextDouble() * 40,
        vx: (_rng.nextDouble() - 0.5) * 60,
        vy: -(180 + _rng.nextDouble() * 220),
        gravity: -30, // Negative gravity = floats up
        drag: 0.985,
        life: 1.5 + _rng.nextDouble() * 1.0,
        size: 5 + _rng.nextDouble() * 8, // Larger size (5-13px)
        rotation: _rng.nextDouble() * 2 * pi,
        angularVelocity: (_rng.nextDouble() - 0.5) * 6,
        color: Colors.white,
        shape: _rng.nextBool() ? ParticleShape.star : ParticleShape.circle,
      ));
    }
    _ensureTickerRunning();
    setState(() {});
  }

  /// Continuous confetti rain from top for ~3 seconds.
  void triggerHighScoreRain() {
    final size = MediaQuery.of(context).size;

    // Spawn particles in waves over 3 seconds
    for (int wave = 0; wave < 6; wave++) {
      Future.delayed(Duration(milliseconds: wave * 500), () {
        if (!mounted) return;
        int count = 20 + _rng.nextInt(15);
        for (int i = 0; i < count; i++) {
          _addParticle(CelebrationParticle(
            x: _rng.nextDouble() * size.width,
            y: -10 - _rng.nextDouble() * 40,
            vx: (_rng.nextDouble() - 0.5) * 100,
            vy: 80 + _rng.nextDouble() * 140,
            gravity: 80 + _rng.nextDouble() * 60,
            drag: 0.99,
            life: 2.2 + _rng.nextDouble() * 1.8,
            size: 8 + _rng.nextDouble() * 12, // Larger size (8-20px)
            rotation: _rng.nextDouble() * 2 * pi,
            angularVelocity: (_rng.nextDouble() - 0.5) * 8,
            color: Colors.white,
            shape: ParticleShape
                .values[_rng.nextInt(ParticleShape.values.length)],
          ));
        }
        _ensureTickerRunning();
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CelebrationPainter(_particles),
        size: Size.infinite,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  CELEBRATION PAINTER
// ═══════════════════════════════════════════════════════

class _CelebrationPainter extends CustomPainter {
  final List<CelebrationParticle> particles;

  _CelebrationPainter(this.particles);

  static final Path _unitStarPath = _buildUnitStarPath();
  static final Path _unitTrianglePath = _buildUnitTrianglePath();

  static Path _buildUnitStarPath() {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      double outerAngle = (i * 2 * pi / 5) - pi / 2;
      double innerAngle = outerAngle + pi / 5;
      double outerX = cos(outerAngle);
      double outerY = sin(outerAngle);
      double innerX = cos(innerAngle) * 0.45;
      double innerY = sin(innerAngle) * 0.45;
      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();
    return path;
  }

  static Path _buildUnitTrianglePath() {
    final path = Path();
    for (int i = 0; i < 3; i++) {
      double angle = (i * 2 * pi / 3) - pi / 2;
      double x = cos(angle);
      double y = sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  // Reusable paints to avoid dynamic allocations per-frame/per-particle
  final Paint _paint = Paint()..style = PaintingStyle.fill;
  final Paint _glowPaint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;

    for (var p in particles) {
      if (p.alpha <= 0) continue;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      _paint.color = p.color.withValues(alpha: p.alpha.clamp(0.0, 1.0));
      _glowPaint.color = p.color.withValues(alpha: (p.alpha * 0.25).clamp(0.0, 1.0));

      switch (p.shape) {
        case ParticleShape.circle:
          // Glow layer (1.4x scale)
          canvas.drawCircle(Offset.zero, p.size * 0.7, _glowPaint);
          // Main shape (1.0x scale)
          canvas.drawCircle(Offset.zero, p.size / 2, _paint);

        case ParticleShape.rect:
          // Glow layer (1.4x scale)
          final glowRect = Rect.fromCenter(
            center: Offset.zero,
            width: p.size * 1.4,
            height: p.size * 0.84,
          );
          canvas.drawRect(glowRect, _glowPaint);
          // Main shape (1.0x scale)
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          );
          canvas.drawRect(rect, _paint);

        case ParticleShape.star:
          // Glow layer (1.4x scale)
          canvas.save();
          canvas.scale(p.size * 0.7);
          canvas.drawPath(_unitStarPath, _glowPaint);
          canvas.restore();
          // Main shape (1.0x scale)
          canvas.save();
          canvas.scale(p.size / 2);
          canvas.drawPath(_unitStarPath, _paint);
          canvas.restore();

        case ParticleShape.triangle:
          // Glow layer (1.4x scale)
          canvas.save();
          canvas.scale(p.size * 0.7);
          canvas.drawPath(_unitTrianglePath, _glowPaint);
          canvas.restore();
          // Main shape (1.0x scale)
          canvas.save();
          canvas.scale(p.size / 2);
          canvas.drawPath(_unitTrianglePath, _paint);
          canvas.restore();
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) {
    return true;
  }
}
