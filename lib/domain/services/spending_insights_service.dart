import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/models/transaction_record.dart';

class PriceChangeInsight {
  const PriceChangeInsight({
    required this.name,
    required this.previousAmount,
    required this.currentAmount,
    required this.changedAt,
  });

  final String name;
  final double previousAmount;
  final double currentAmount;
  final DateTime changedAt;

  double get difference => currentAmount - previousAmount;
}

class SpendingInsights {
  const SpendingInsights({
    required this.activeCount,
    required this.monthlyCommitments,
    required this.yearlyProjection,
    required this.lastMonthSpend,
    required this.previousMonthSpend,
    required this.priceChanges,
    required this.newRecurringNames,
    required this.staleNames,
  });

  final int activeCount;
  final double monthlyCommitments;
  final double yearlyProjection;
  final double lastMonthSpend;
  final double previousMonthSpend;
  final List<PriceChangeInsight> priceChanges;
  final List<String> newRecurringNames;
  final List<String> staleNames;

  double get completedMonthChange => lastMonthSpend - previousMonthSpend;
  bool get hasTransactionHistory =>
      lastMonthSpend != 0 ||
      previousMonthSpend != 0 ||
      priceChanges.isNotEmpty ||
      newRecurringNames.isNotEmpty ||
      staleNames.isNotEmpty;
}

abstract final class SpendingInsightsService {
  static SpendingInsights calculate({
    required Iterable<Subscription> subscriptions,
    required Iterable<TransactionRecord> transactions,
    required DateTime now,
    required String currency,
  }) {
    final active = subscriptions
        .where((item) => !item.isPaused && item.currency == currency)
        .toList();
    final matches = <String, Subscription>{
      for (final subscription in active) ...{
        _key(subscription.name): subscription,
        if (subscription.normalizedMerchant != null)
          _key(subscription.normalizedMerchant!): subscription,
      },
    };
    final relevant = transactions
        .where((record) => record.isDebit && record.currency == currency)
        .map(
          (record) => (record: record, match: matches[_key(record.merchant)]),
        )
        .where((entry) => entry.match != null)
        .toList();

    final lastMonthStart = DateTime(now.year, now.month - 1);
    final thisMonthStart = DateTime(now.year, now.month);
    final previousMonthStart = DateTime(now.year, now.month - 2);
    double spendBetween(DateTime start, DateTime end) => relevant
        .where(
          (entry) =>
              !entry.record.occurredAt.isBefore(start) &&
              entry.record.occurredAt.isBefore(end),
        )
        .fold(0, (sum, entry) => sum + entry.record.amount);

    final grouped = <String, List<TransactionRecord>>{};
    for (final entry in relevant) {
      grouped.putIfAbsent(entry.match!.id, () => []).add(entry.record);
    }

    final priceChanges = <PriceChangeInsight>[];
    final newNames = <String>[];
    final staleNames = <String>[];
    for (final subscription in active) {
      final history = [...?grouped[subscription.id]]
        ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      if (history.isEmpty) continue;

      if (!history.first.occurredAt.isBefore(thisMonthStart)) {
        newNames.add(subscription.name);
      }

      final last = history.last;
      final staleAfter = Duration(
        days: (subscription.cycle.days * 1.5).round(),
      );
      if (now.difference(last.occurredAt) > staleAfter) {
        staleNames.add(subscription.name);
      }

      for (var index = 1; index < history.length; index++) {
        final previous = history[index - 1];
        final current = history[index];
        if (current.occurredAt.year == now.year &&
            (current.amount - previous.amount).abs() >= .01) {
          priceChanges.add(
            PriceChangeInsight(
              name: subscription.name,
              previousAmount: previous.amount,
              currentAmount: current.amount,
              changedAt: current.occurredAt,
            ),
          );
        }
      }
    }

    priceChanges.sort((a, b) => b.changedAt.compareTo(a.changedAt));
    final monthly = active.fold<double>(
      0,
      (sum, item) => sum + item.monthlyEquivalent,
    );
    return SpendingInsights(
      activeCount: active.length,
      monthlyCommitments: monthly,
      yearlyProjection: monthly * 12,
      lastMonthSpend: spendBetween(lastMonthStart, thisMonthStart),
      previousMonthSpend: spendBetween(previousMonthStart, lastMonthStart),
      priceChanges: priceChanges,
      newRecurringNames: newNames..sort(),
      staleNames: staleNames..sort(),
    );
  }

  static String _key(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
