import 'package:dues/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class DuesCard extends StatelessWidget {
  const DuesCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = DuesColors.surface,
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: DuesColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
