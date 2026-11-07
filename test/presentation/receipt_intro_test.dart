import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/presentation/widgets/receipt_intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('prints letters then hands the title to the home header', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DuesTheme.light,
        home: const ReceiptIntro(
          ready: true,
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: DuesTitle(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.text('D'), findsOneWidget);
    expect(find.text('PRINTING...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();
    expect(find.text('PRINTING...'), findsNothing);
    expect(find.text('DUES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
