import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/presentation/widgets/receipt_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReceiptIntro extends StatefulWidget {
  const ReceiptIntro({required this.child, required this.ready, super.key});
  final Widget child;
  final bool ready;

  @override
  State<ReceiptIntro> createState() => _ReceiptIntroState();
}

class _ReceiptIntroState extends State<ReceiptIntro>
    with SingleTickerProviderStateMixin {
  static const _audioChannel = MethodChannel('com.duesapp.dues/receipt_audio');

  late final AnimationController controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          unawaited(_stopPrintSound());
          if (mounted) setState(() {});
        }
      });
  final titleKey = GlobalKey();
  final stackKey = GlobalKey();
  Rect? destination;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startWhenReady();
  }

  @override
  void didUpdateWidget(covariant ReceiptIntro oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready) _startWhenReady();
  }

  void _startWhenReady() {
    if (!widget.ready || controller.isAnimating || controller.isCompleted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final title = titleKey.currentContext?.findRenderObject() as RenderBox?;
      final stack = stackKey.currentContext?.findRenderObject() as RenderBox?;
      if (title != null && stack != null) {
        destination =
            title.localToGlobal(Offset.zero, ancestor: stack) & title.size;
      }
      if (MediaQuery.disableAnimationsOf(context)) {
        controller.value = 1;
      } else {
        unawaited(_playPrintSound());
        controller.forward();
      }
    });
  }

  Future<void> _playPrintSound() async {
    try {
      await _audioChannel.invokeMethod<void>('play');
    } on MissingPluginException {
      // The intro remains usable on platforms without the Android audio host.
    } on PlatformException {
      // Audio is decorative and must never block app startup.
    }
  }

  Future<void> _stopPrintSound() async {
    try {
      await _audioChannel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // The intro remains usable on platforms without the Android audio host.
    } on PlatformException {
      // Audio is decorative and must never block app startup.
    }
  }

  @override
  void dispose() {
    unawaited(_stopPrintSound());
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finished = controller.isCompleted;
    return _IntroScope(
      titleKey: titleKey,
      hideTitle: !finished,
      child: Stack(
        key: stackKey,
        fit: StackFit.expand,
        children: [
          widget.child,
          if (!finished)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    final t = controller.value;
                    final flight = Curves.easeInOutCubic.transform(
                      ((t - .7) / .3).clamp(0, 1),
                    );
                    final printed = ((t - .1) / .55).clamp(0.0, 1.0);
                    final target =
                        destination ??
                        Rect.fromLTWH(
                          20,
                          MediaQuery.paddingOf(context).top + 24,
                          90,
                          34,
                        );
                    final scale = lerpDouble(1.65, 1, flight)!;
                    final start = Offset(
                      (constraints.maxWidth - target.width * 1.65) / 2,
                      constraints.maxHeight * .31,
                    );
                    final position = Offset.lerp(
                      start,
                      target.topLeft,
                      flight,
                    )!;
                    final letters = (t / .12).floor().clamp(0, 4);
                    return AbsorbPointer(
                      child: DefaultTextStyle(
                        style: Theme.of(context).textTheme.bodyMedium!,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Opacity(
                                opacity: 1 - flight,
                                child: ColoredBox(color: context.receipt.paper),
                              ),
                            ),
                            Positioned(
                              top:
                                  constraints.maxHeight * .31 +
                                  target.height * 1.65 +
                                  20,
                              left: 40,
                              right: 40,
                              child: Opacity(
                                opacity: 1 - flight,
                                child: ClipRect(
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    heightFactor: printed,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.symmetric(
                                          vertical: BorderSide(
                                            color: context.receipt.divider,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const DashedDivider(),
                                          const SizedBox(height: 18),
                                          Text(
                                            'YOUR LOCAL STATEMENT',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .receiptLabel,
                                          ),
                                          const SizedBox(height: 14),
                                          const DashedDivider(
                                            height: 1,
                                            dash: 2,
                                            gap: 4,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'PRINTING...',
                                            style: TextStyle(
                                              color: context.receipt.muted,
                                              fontSize: 11,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          const DashedDivider(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: position.dx,
                              top: position.dy,
                              child: Transform.scale(
                                scale: scale,
                                alignment: Alignment.topLeft,
                                child: Text(
                                  'DUES'.substring(0, letters),
                                  style: Theme.of(context)
                                      .textTheme
                                      .receiptHeading
                                      .copyWith(color: context.receipt.ink),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IntroScope extends InheritedWidget {
  const _IntroScope({
    required this.titleKey,
    required this.hideTitle,
    required super.child,
  });
  final GlobalKey titleKey;
  final bool hideTitle;

  @override
  bool updateShouldNotify(_IntroScope oldWidget) =>
      hideTitle != oldWidget.hideTitle;
}

class DuesTitle extends StatelessWidget {
  const DuesTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final intro = context.dependOnInheritedWidgetOfExactType<_IntroScope>();
    return Align(
      alignment: Alignment.centerLeft,
      child: Opacity(
        opacity: intro?.hideTitle == true ? 0 : 1,
        child: Text(
          'DUES',
          key: intro?.titleKey,
          maxLines: 1,
          style: Theme.of(context).textTheme.receiptHeading,
        ),
      ),
    );
  }
}
