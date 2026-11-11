import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/presentation/widgets/commitment_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping a due day opens its receipt details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DuesTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CommitmentCalendar(
              now: DateTime(2026, 11, 11),
              onInteraction: () {},
              subscriptions: [
                Subscription(
                  id: 'netflix',
                  name: 'Netflix',
                  amount: 649,
                  cycle: BillingCycle.monthly,
                  nextDueDate: DateTime(2026, 11, 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-11-14')));
    await tester.pumpAndSettle();

    expect(find.text('SATURDAY / 14 NOV 2026'), findsOneWidget);
    expect(find.text('NETFLIX'), findsOneWidget);
    expect(find.textContaining('MONTHLY'), findsOneWidget);
    expect(find.textContaining('DETECTED FROM SMS'), findsOneWidget);
  });
}
