import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class OnboardingEntry extends StatefulWidget {
  final VoidCallback onContinue;
  const OnboardingEntry({super.key, required this.onContinue});

  @override
  State<OnboardingEntry> createState() => _OnboardingEntryState();
}

class _OnboardingEntryState extends State<OnboardingEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  static const Color _glowColor = Color(0xFFD6FF00);

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 20),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 20),
    ]).animate(_glowController);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visualCorrection = _triangleVisualCorrection(300, -15);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text(
              'Let’s personalize\nyour experience',
              style: AppTextStyles.headingText.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You can choose one role or both.',
              style: AppTextStyles.regularText.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            Expanded(
              child: Center(
                child: Transform.translate(
                  offset: visualCorrection,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipPath(
                        clipper: const _RoundedTriangleClipper(
                          cornerRadius: 16,
                          rotationDeg: -15,
                        ),
                        child: SizedBox(
                          width: 300,
                          height: 300,
                          child: Stack(
                            children: [
                              const SizedBox.expand(
                                child: CustomPaint(
                                  painter: _RoundedTrianglePainter(
                                    color: Color(0x40D6FF00),
                                    cornerRadius: 16,
                                    rotationDeg: -15,
                                  ),
                                ),
                              ),
                              AnimatedBuilder(
                                animation: _glowAnimation,
                                builder: (context, child) {
                                  final t = _glowAnimation.value;
                                  return Opacity(
                                    opacity: t,
                                    child: Transform.scale(
                                      scale: 0.98 + (t * 0.04),
                                      child: child,
                                    ),
                                  );
                                },
                                child: ImageFiltered(
                                  imageFilter: ImageFilter.blur(
                                    sigmaX: 20,
                                    sigmaY: 20,
                                  ),
                                  child: const SizedBox.expand(
                                    child: CustomPaint(
                                      painter: _RoundedTrianglePainter(
                                        color: _glowColor,
                                        cornerRadius: 16,
                                        rotationDeg: -15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ClipPath(
                        clipper: const _RoundedTriangleClipper(
                          cornerRadius: 16,
                          rotationDeg: -15,
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            width: 350,
                            height: 350,
                            decoration: BoxDecoration(
                              color: _glowColor.withValues(alpha: 0.2),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    textStyle: AppTextStyles.boldText,
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Offset _triangleVisualCorrection(double referenceSize, double rotationDeg) {
  final radius = referenceSize / 2;
  final rotationRad = rotationDeg * math.pi / 180;

  final vertices = List.generate(3, (i) {
    final angle = -math.pi / 2 + i * (2 * math.pi / 3) + rotationRad;
    return Offset(math.cos(angle), math.sin(angle)) * radius;
  });

  final path =
      Path()
        ..moveTo(vertices[0].dx, vertices[0].dy)
        ..lineTo(vertices[1].dx, vertices[1].dy)
        ..lineTo(vertices[2].dx, vertices[2].dy)
        ..close();

  return -path.getBounds().center;
}

Path _roundedTrianglePath(Size size, double cornerRadius, double rotationDeg) {
  final center = Offset(size.width / 2, size.height / 2);
  final radius = size.width / 2;
  final rotationRad = rotationDeg * math.pi / 180;

  final vertices = List.generate(3, (i) {
    final angle = -math.pi / 2 + i * (2 * math.pi / 3) + rotationRad;
    return center + Offset(math.cos(angle), math.sin(angle)) * radius;
  });

  return _roundedPolygonPath(vertices, cornerRadius);
}

Path _roundedPolygonPath(List<Offset> vertices, double cornerRadius) {
  final path = Path();
  final n = vertices.length;

  for (int i = 0; i < n; i++) {
    final curr = vertices[i];
    final prev = vertices[(i - 1 + n) % n];
    final next = vertices[(i + 1) % n];

    final toPrev = prev - curr;
    final toNext = next - curr;

    final r = math.min(
      cornerRadius,
      math.min(toPrev.distance, toNext.distance) / 2,
    );

    final p1 = curr + toPrev / toPrev.distance * r;
    final p2 = curr + toNext / toNext.distance * r;

    if (i == 0) {
      path.moveTo(p1.dx, p1.dy);
    } else {
      path.lineTo(p1.dx, p1.dy);
    }
    path.arcToPoint(p2, radius: Radius.circular(r), clockwise: true);
  }
  path.close();
  return path;
}

class _RoundedTriangleClipper extends CustomClipper<Path> {
  final double cornerRadius;
  final double rotationDeg;

  const _RoundedTriangleClipper({
    required this.cornerRadius,
    required this.rotationDeg,
  });

  @override
  Path getClip(Size size) =>
      _roundedTrianglePath(size, cornerRadius, rotationDeg);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _RoundedTrianglePainter extends CustomPainter {
  final Color color;
  final double cornerRadius;
  final double rotationDeg;

  const _RoundedTrianglePainter({
    required this.color,
    required this.cornerRadius,
    required this.rotationDeg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _roundedTrianglePath(size, cornerRadius, rotationDeg);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RoundedTrianglePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.cornerRadius != cornerRadius ||
      oldDelegate.rotationDeg != rotationDeg;
}