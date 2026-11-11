import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/models/transaction_record.dart';
import 'package:dues/domain/services/spending_insights_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'calculates local totals, price changes and completed-month movement',
    () {
      final subscriptions = [
        Subscription(
          id: 'netflix',
          name: 'Netflix',
          normalizedMerchant: 'NETFLIX.COM',
          amount: 799,
          cycle: BillingCycle.monthly,
          nextDueDate: DateTime(2026, 11, 12),
        ),
        Subscription(
          id: 'spotify',
          name: 'Spotify',
          amount: 119,
          cycle: BillingCycle.monthly,
          nextDueDate: DateTime(2026, 11, 14),
        ),
      ];
      final transactions = [
        _transaction('n1', 'Netflix.com', 649, DateTime(2026, 9, 12)),
        _transaction('n2', 'Netflix.com', 799, DateTime(2026, 10, 12)),
        _transaction('s1', 'Spotify', 119, DateTime(2026, 10, 14)),
      ];

      final insights = SpendingInsightsService.calculate(
        subscriptions: subscriptions,
        transactions: transactions,
        now: DateTime(2026, 11, 11),
        currency: 'INR',
      );

      expect(insights.activeCount, 2);
      expect(insights.monthlyCommitments, 918);
      expect(insights.lastMonthSpend, 918);
      expect(insights.previousMonthSpend, 649);
      expect(insights.completedMonthChange, 269);
      expect(insights.priceChanges, hasLength(1));
      expect(insights.priceChanges.single.name, 'Netflix');
      expect(insights.priceChanges.single.difference, 150);
    },
  );

  test('reports new and stale recurring charges from local history', () {
    final subscriptions = [
      Subscription(
        id: 'new',
        name: 'New Service',
        amount: 100,
        cycle: BillingCycle.monthly,
        nextDueDate: DateTime(2026, 11, 20),
      ),
      Subscription(
        id: 'stale',
        name: 'Old Service',
        amount: 200,
        cycle: BillingCycle.monthly,
        nextDueDate: DateTime(2026, 11, 5),
      ),
    ];
    final insights = SpendingInsightsService.calculate(
      subscriptions: subscriptions,
      transactions: [
        _transaction('new-1', 'New Service', 100, DateTime(2026, 11, 2)),
        _transaction('old-1', 'Old Service', 200, DateTime(2026, 7, 5)),
      ],
      now: DateTime(2026, 11, 11),
      currency: 'INR',
    );

    expect(insights.newRecurringNames, ['New Service']);
    expect(insights.staleNames, ['Old Service']);
  });
}

TransactionRecord _transaction(
  String id,
  String merchant,
  double amount,
  DateTime occurredAt,
) => TransactionRecord(
  id: id,
  sender: 'BANK',
  body: 'INR $amount debited at $merchant',
  merchant: merchant,
  amount: amount,
  currency: 'INR',
  occurredAt: occurredAt,
  isDebit: true,
);
