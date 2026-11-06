import 'package:dues/domain/models/subscription.dart';
import 'package:dues/parser/models/parsed_transaction.dart';

class RecurringCandidate {
  const RecurringCandidate({
    required this.merchant,
    required this.amount,
    required this.currency,
    required this.cycle,
    required this.nextDueDate,
    required this.occurrences,
    required this.signal,
  });

  final String merchant;
  final double amount;
  final String currency;
  final BillingCycle cycle;
  final DateTime nextDueDate;
  final int occurrences;
  final RecurringSignal? signal;
}

class RecurrenceDetector {
  const RecurrenceDetector();

  List<RecurringCandidate> detect(Iterable<ParsedTransaction> transactions) {
    final grouped = <String, List<ParsedTransaction>>{};
    for (final transaction in transactions.where((item) => item.isDebit)) {
      grouped
          .putIfAbsent(transaction.merchant.toLowerCase(), () => [])
          .add(transaction);
    }

    final candidates = <RecurringCandidate>[];
    for (final group in grouped.values) {
      group.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      final clusters = _amountClusters(group);
      for (final cluster in clusters) {
        final signalled = cluster
            .map((item) => item.signal)
            .whereType<RecurringSignal>()
            .firstOrNull;
        if (cluster.length < 2 && signalled == null) continue;
        final cycle =
            _inferCycle(cluster) ??
            (signalled == null ? null : BillingCycle.monthly);
        if (cycle == null) continue;
        final latest = cluster.last;
        candidates.add(
          RecurringCandidate(
            merchant: latest.merchant,
            amount: _median(cluster.map((item) => item.amount).toList()),
            currency: latest.currency,
            cycle: cycle,
            nextDueDate: latest.occurredAt.add(Duration(days: cycle.days)),
            occurrences: cluster.length,
            signal: signalled,
          ),
        );
      }
    }
    candidates.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    return candidates;
  }

  List<List<ParsedTransaction>> _amountClusters(List<ParsedTransaction> group) {
    final clusters = <List<ParsedTransaction>>[];
    for (final transaction in group) {
      final match = clusters
          .where(
            (cluster) => _similar(cluster.first.amount, transaction.amount),
          )
          .firstOrNull;
      (match ?? (clusters..add(<ParsedTransaction>[])).last).add(transaction);
    }
    return clusters;
  }

  bool _similar(double a, double b) =>
      (a - b).abs() <= (a * .05).clamp(10, 250);

  BillingCycle? _inferCycle(List<ParsedTransaction> cluster) {
    if (cluster.length < 2) return null;
    final intervals = <double>[];
    for (var i = 1; i < cluster.length; i++) {
      intervals.add(
        cluster[i].occurredAt.difference(cluster[i - 1].occurredAt).inHours /
            24,
      );
    }
    final days = _median(intervals);
    if (days >= 5 && days <= 9) return BillingCycle.weekly;
    if (days >= 25 && days <= 35) return BillingCycle.monthly;
    if (days >= 80 && days <= 100) return BillingCycle.quarterly;
    if (days >= 350 && days <= 380) return BillingCycle.yearly;
    return null;
  }

  double _median(List<double> values) {
    values.sort();
    final middle = values.length ~/ 2;
    return values.length.isOdd
        ? values[middle]
        : (values[middle - 1] + values[middle]) / 2;
  }
}
