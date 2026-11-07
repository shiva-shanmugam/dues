import 'dart:math' as math;

import 'package:dues/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class DashedDivider extends StatelessWidget {
  const DashedDivider({
    this.height = 2,
    this.dash = 7,
    this.gap = 5,
    super.key,
  });

  final double height;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: height,
    child: CustomPaint(
      painter: _DashedLinePainter(
        color: context.receipt.divider,
        dash: dash,
        gap: gap,
      ),
    ),
  );
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({
    required this.color,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.square;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap;
}

class LeaderLine extends StatelessWidget {
  const LeaderLine({
    required this.label,
    required this.amount,
    this.labelStyle,
    this.amountStyle,
    this.onTap,
    super.key,
  });

  final String label;
  final String amount;
  final TextStyle? labelStyle;
  final TextStyle? amountStyle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.receipt;
    final child = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle ?? TextStyle(color: tokens.ink, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final count = math.max(1, (constraints.maxWidth / 7).floor());
                return Text(
                  List.filled(count, '.').join(),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(color: tokens.muted, fontSize: 12),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            maxLines: 1,
            style:
                amountStyle ??
                TextStyle(
                  color: tokens.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: child,
    );
  }
}

class Stamp extends StatelessWidget {
  const Stamp({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -2 * math.pi / 180,
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.receipt.divider, width: 2),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: context.receipt.ink,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: .7,
        ),
        child: child,
      ),
    ),
  );
}

enum ReceiptButtonVariant { solid, dashed }

class ReceiptButton extends StatelessWidget {
  const ReceiptButton({
    required this.label,
    required this.onPressed,
    this.variant = ReceiptButtonVariant.solid,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final ReceiptButtonVariant variant;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final solid = variant == ReceiptButtonVariant.solid;
    final tokens = context.receipt;
    return Semantics(
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: CustomPaint(
          painter: solid
              ? null
              : _DashedBorderPainter(color: tokens.divider, radius: 4),
          child: Material(
            color: solid ? tokens.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              onTap: busy ? null : onPressed,
              borderRadius: BorderRadius.circular(4),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: busy
                      ? SizedBox(
                          key: const ValueKey('busy'),
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: solid ? tokens.paper : tokens.ink,
                          ),
                        )
                      : Text(
                          label.toUpperCase(),
                          key: const ValueKey('label'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: solid ? tokens.paper : tokens.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 12) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + 7, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class ReceiptNavBar extends StatelessWidget {
  const ReceiptNavBar({
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const labels = ['HOME', 'SUBS', 'CONFIG'];
    return ColoredBox(
      color: context.receipt.paper,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DashedDivider(),
            Row(
              children: [
                for (var index = 0; index < labels.length; index++)
                  Expanded(
                    child: Semantics(
                      selected: selected == index,
                      button: true,
                      child: InkWell(
                        key: ValueKey('nav-$index'),
                        onTap: () => onSelect(index),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Center(
                            child: Text(
                              selected == index
                                  ? '[${labels[index]}]'
                                  : labels[index],
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 1,
                                fontWeight: selected == index
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.receiptLabel,
      ),
      const SizedBox(height: 8),
      const DashedDivider(),
    ],
  );
}

String formatReceiptAmount(double amount, {String currency = 'INR'}) {
  final fixed = amount.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts.first;
  String grouped;
  if (currency == 'INR' && digits.length > 3) {
    final tail = digits.substring(digits.length - 3);
    var head = digits.substring(0, digits.length - 3);
    final chunks = <String>[];
    while (head.length > 2) {
      chunks.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) chunks.insert(0, head);
    grouped = '${chunks.join(',')},$tail';
  } else {
    grouped = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
  }
  const symbols = {'INR': '₹', 'USD': r'$', 'EUR': '€', 'GBP': '£'};
  final prefix = symbols[currency] ?? '$currency ';
  return '${amount < 0 ? '-' : ''}$prefix$grouped.${parts.last}';
}
