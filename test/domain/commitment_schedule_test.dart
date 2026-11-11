import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/services/commitment_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Subscription subscription({
    required String id,
    required BillingCycle cycle,
    required DateTime due,
    bool paused = false,
  }) => Subscription(
    id: id,
    name: id,
    amount: 100,
    cycle: cycle,
    nextDueDate: due,
    isPaused: paused,
  );

  test('projects monthly commitments without losing the anchor day', () {
    final item = subscription(
      id: 'month-end',
      cycle: BillingCycle.monthly,
      due: DateTime(2026, 1, 31),
    );

    expect(
      CommitmentSchedule.forMonth([item], DateTime(2026, 2)).single.dueDate,
      DateTime(2026, 2, 28),
    );
    expect(
      CommitmentSchedule.forMonth([item], DateTime(2026, 3)).single.dueDate,
      DateTime(2026, 3, 31),
    );
  });

  test('returns every weekly occurrence in a month', () {
    final item = subscription(
      id: 'weekly',
      cycle: BillingCycle.weekly,
      due: DateTime(2026, 11, 2),
    );

    final dates = CommitmentSchedule.forMonth([
      item,
    ], DateTime(2026, 11)).map((item) => item.dueDate.day);
    expect(dates, [2, 9, 16, 23, 30]);
  });

  test('excludes paused commitments and sorts shared due dates by name', () {
    final occurrences = CommitmentSchedule.forMonth([
      subscription(
        id: 'zeta',
        cycle: BillingCycle.monthly,
        due: DateTime(2026, 11, 10),
      ),
      subscription(
        id: 'alpha',
        cycle: BillingCycle.monthly,
        due: DateTime(2026, 11, 10),
      ),
      subscription(
        id: 'paused',
        cycle: BillingCycle.monthly,
        due: DateTime(2026, 11, 10),
        paused: true,
      ),
    ], DateTime(2026, 11));

    expect(occurrences.map((item) => item.subscription.name), [
      'alpha',
      'zeta',
    ]);
  });
}
