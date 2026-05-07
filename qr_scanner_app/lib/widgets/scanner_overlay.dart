import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ScannerOverlay extends StatefulWidget {
  final double size;

  const ScannerOverlay({super.key, this.size = 280});

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _laserAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _laserAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _laserAnim,
        builder: (context, _) {
          return CustomPaint(
            painter: _ScannerFramePainter(laserPosition: _laserAnim.value),
          );
        },
      ),
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  final double laserPosition;
  static const double cornerLength = 36;
  static const double cornerRadius = 12;
  static const double strokeWidth = 3.0;

  const _ScannerFramePainter({required this.laserPosition});

  @override
  void paint(Canvas canvas, Size size) {
    _drawCorners(canvas, size);
    _drawLaser(canvas, size);
  }

  void _drawCorners(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..color = AppTheme.accent.withValues(alpha: 0.35)
      ..strokeWidth = strokeWidth + 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final mainPaint = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    const r = cornerRadius;
    const cl = cornerLength;

    final corners = <List<Offset>>[
      // Top-left
      [Offset(0, cl + r), Offset(0, r), Offset(r, 0), Offset(cl + r, 0)],
      // Top-right
      [
        Offset(w - cl - r, 0),
        Offset(w - r, 0),
        Offset(w, r),
        Offset(w, cl + r)
      ],
      // Bottom-right
      [
        Offset(w, h - cl - r),
        Offset(w, h - r),
        Offset(w - r, h),
        Offset(w - cl - r, h)
      ],
      // Bottom-left
      [Offset(cl + r, h), Offset(r, h), Offset(0, h - r), Offset(0, h - cl - r)],
    ];

    for (final pts in corners) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..quadraticBezierTo(pts[1].dx, pts[1].dy, pts[2].dx, pts[2].dy)
        ..lineTo(pts[3].dx, pts[3].dy);

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, mainPaint);
    }
  }

  void _drawLaser(Canvas canvas, Size size) {
    final y = laserPosition * size.height;
    final clampedY = y.clamp(4.0, size.height - 4.0);

    // Outer glow
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppTheme.accent.withValues(alpha: 0.15),
          AppTheme.accent.withValues(alpha: 0.6),
          AppTheme.accent.withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, clampedY - 12, size.width, 24))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawRect(
      Rect.fromLTWH(0, clampedY - 12, size.width, 24),
      glowPaint,
    );

    // Core laser line
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppTheme.accent.withValues(alpha: 0.8),
          AppTheme.accent,
          AppTheme.accent.withValues(alpha: 0.8),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, clampedY - 1, size.width, 2))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawLine(Offset(0, clampedY), Offset(size.width, clampedY), laserPaint);

    // Bright center dot
    final dotPaint = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(size.width / 2, clampedY), 2, dotPaint);
  }

  @override
  bool shouldRepaint(_ScannerFramePainter old) =>
      old.laserPosition != laserPosition;
}

class ScannerDimOverlay extends StatelessWidget {
  final double frameSize;

  const ScannerDimOverlay({super.key, required this.frameSize});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DimOverlayPainter(frameSize: frameSize),
      child: const SizedBox.expand(),
    );
  }
}

class _DimOverlayPainter extends CustomPainter {
  final double frameSize;
  const _DimOverlayPainter({required this.frameSize});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final half = frameSize / 2;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - half, cy - half, frameSize, frameSize),
          const Radius.circular(12),
        ),
      );
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = const Color(0xCC0A0A0F),
    );
  }

  @override
  bool shouldRepaint(_DimOverlayPainter old) => old.frameSize != frameSize;
}

/// Animated rotating arc for scanning feedback
class PulseRing extends StatefulWidget {
  const PulseRing({super.key});

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _anim = Tween<double>(begin: 0, end: 2 * math.pi).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => CustomPaint(
        painter: _PulseRingPainter(angle: _anim.value),
        size: const Size(316, 316),
      ),
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  final double angle;
  const _PulseRingPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = SweepGradient(
        startAngle: angle,
        endAngle: angle + math.pi * 0.8,
        colors: [
          Colors.transparent,
          AppTheme.accent.withValues(alpha: 0.15),
          AppTheme.accent.withValues(alpha: 0.4),
        ],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      angle,
      math.pi * 0.8,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) => old.angle != angle;
}
