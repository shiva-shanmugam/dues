import 'package:dues/domain/models/subscription.dart';
import 'package:dues/parser/models/parsed_transaction.dart';
import 'package:dues/parser/recurrence_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const detector = RecurrenceDetector();

  ParsedTransaction transaction(
    String merchant,
    double amount,
    DateTime date, {
    RecurringSignal? signal,
  }) {
    return ParsedTransaction(
      messageId: '$merchant-${date.millisecondsSinceEpoch}',
      sender: 'BANK',
      rawBody: 'test',
      rawMerchant: merchant,
      merchant: merchant,
      amount: amount,
      currency: 'INR',
      occurredAt: date,
      isDebit: true,
      signal: signal,
    );
  }

  test('detects monthly recurrence with similar amounts', () {
    final candidates = detector.detect([
      transaction('Netflix', 649, DateTime(2026, 8, 5)),
      transaction('Netflix', 649, DateTime(2026, 9, 5)),
      transaction('Netflix', 669, DateTime(2026, 10, 5)),
    ]);

    expect(candidates, hasLength(1));
    expect(candidates.single.cycle, BillingCycle.monthly);
    expect(candidates.single.occurrences, 3);
    expect(candidates.single.nextDueDate, DateTime(2026, 11, 4));
  });

  test('detects weekly, quarterly, and yearly intervals', () {
    final candidates = detector.detect([
      transaction('Milk', 700, DateTime(2026, 10, 1)),
      transaction('Milk', 700, DateTime(2026, 10, 8)),
      transaction('Adobe', 1800, DateTime(2026, 1, 1)),
      transaction('Adobe', 1800, DateTime(2026, 4, 1)),
      transaction('Notion', 3999, DateTime(2025, 5, 1)),
      transaction('Notion', 3999, DateTime(2026, 5, 1)),
    ]);

    expect(
      candidates.map((item) => item.cycle),
      containsAll([
        BillingCycle.weekly,
        BillingCycle.quarterly,
        BillingCycle.yearly,
      ]),
    );
  });

  test('does not classify two unrelated intervals or dissimilar amounts', () {
    final candidates = detector.detect([
      transaction('Amazon', 200, DateTime(2026, 1, 1)),
      transaction('Amazon', 900, DateTime(2026, 2, 1)),
      transaction('Store', 300, DateTime(2026, 1, 1)),
      transaction('Store', 300, DateTime(2026, 1, 14)),
    ]);

    expect(candidates, isEmpty);
  });

  test('keyword signal creates a monthly candidate from one transaction', () {
    final candidates = detector.detect([
      transaction(
        'Netflix',
        649,
        DateTime(2026, 10, 5),
        signal: RecurringSignal.autoDebit,
      ),
    ]);

    expect(candidates.single.cycle, BillingCycle.monthly);
    expect(candidates.single.occurrences, 1);
  });
}
