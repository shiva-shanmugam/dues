import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/presentation/widgets/receipt_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('short and long leader rows share the right edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DuesTheme.light,
        home: const Scaffold(
          body: SizedBox(
            width: 320,
            child: Column(
              children: [
                LeaderLine(label: 'SMS ACCESS', amount: 'REQUIRED'),
                LeaderLine(
                  label: 'A MUCH LONGER MERCHANT NAME',
                  amount: '₹649.00',
                ),
                LeaderLine(label: 'N', amount: '₹1,299.00'),
              ],
            ),
          ),
        ),
      ),
    );
    for (final value in ['REQUIRED', '₹649.00', '₹1,299.00']) {
      expect(tester.getRect(find.text(value)).right, closeTo(320, .01));
    }
  });
  testWidgets('LeaderLine handles long names and large Indian amounts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const longName =
        'AN EXTREMELY LONG STREAMING MERCHANT NAME THAT MUST NOT OVERFLOW';
    final amount = formatReceiptAmount(123456789);
    expect(amount, '₹12,34,56,789.00');

    await tester.pumpWidget(
      MaterialApp(
        theme: DuesTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: LeaderLine(label: longName, amount: amount),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final label = tester.widget<Text>(find.text(longName));
    expect(label.overflow, TextOverflow.ellipsis);
    expect(find.text(amount), findsOneWidget);
  });
}
