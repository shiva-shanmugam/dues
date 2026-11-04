import 'package:dues/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class DotGrid extends StatelessWidget {
  const DotGrid({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: const _DotGridPainter(), child: child);
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = DuesColors.gridDot;
    const spacing = 18.0;
    for (double x = 9; x < size.width; x += spacing) {
      for (double y = 9; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.65, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
