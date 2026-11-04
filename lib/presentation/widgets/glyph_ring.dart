import 'dart:math' as math;

import 'package:dues/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class GlyphRing extends StatelessWidget {
  const GlyphRing({
    required this.days,
    required this.cycleDays,
    this.size = 58,
    super.key,
  });
  final int days;
  final int cycleDays;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dueSoon = days <= 3;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: (days / cycleDays).clamp(0, 1),
          color: dueSoon ? DuesColors.red : DuesColors.offWhite,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$days',
                style: const TextStyle(
                  fontFamily: 'Doto',
                  fontVariations: [FontVariation('wght', 900)],
                  fontSize: 20,
                  height: .9,
                ),
              ),
              const Text(
                'DAYS',
                style: TextStyle(
                  color: DuesColors.muted,
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  letterSpacing: .6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = DuesColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
