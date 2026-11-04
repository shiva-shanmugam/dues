import 'package:dues/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard renders fake subscription summary', (tester) async {
    await tester.pumpWidget(const DuesApp());
    await tester.pumpAndSettle();

    expect(find.text('DUES'), findsOneWidget);
    expect(find.text('5 ACTIVE SUBSCRIPTIONS'), findsOneWidget);
    expect(find.text('MONTHLY OUTGO'), findsOneWidget);
    expect(find.text('Netflix'), findsWidgets);
  });

  testWidgets('bottom navigation opens subscriptions and settings', (
    tester,
  ) async {
    await tester.pumpWidget(const DuesApp());

    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('SUBSCRIPTIONS'), findsWidgets);
    expect(find.text('5 TRACKED LOCALLY'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE BY DESIGN'), findsOneWidget);
    expect(find.text('STAYS ON THIS DEVICE'), findsOneWidget);
  });
}
