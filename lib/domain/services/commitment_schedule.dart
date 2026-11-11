import 'package:dues/domain/models/subscription.dart';

class CommitmentOccurrence {
  const CommitmentOccurrence({
    required this.subscription,
    required this.dueDate,
  });

  final Subscription subscription;
  final DateTime dueDate;
}

abstract final class CommitmentSchedule {
  static List<CommitmentOccurrence> forMonth(
    Iterable<Subscription> subscriptions,
    DateTime month,
  ) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final occurrences = <CommitmentOccurrence>[];

    for (final subscription in subscriptions.where((item) => !item.isPaused)) {
      final anchor = _dateOnly(subscription.nextDueDate);
      final step = _stepFor(subscription.cycle);
      var index = _initialIndex(anchor, start, subscription.cycle);
      var due = step(anchor, index);

      while (due.isBefore(start)) {
        index++;
        due = step(anchor, index);
      }

      var guard = 0;
      while (due.isBefore(end) && guard++ < 8) {
        occurrences.add(
          CommitmentOccurrence(subscription: subscription, dueDate: due),
        );
        index++;
        due = step(anchor, index);
      }
    }

    occurrences.sort((a, b) {
      final byDate = a.dueDate.compareTo(b.dueDate);
      if (byDate != 0) return byDate;
      return a.subscription.name.compareTo(b.subscription.name);
    });
    return occurrences;
  }

  static int _initialIndex(
    DateTime anchor,
    DateTime monthStart,
    BillingCycle cycle,
  ) {
    return switch (cycle) {
      BillingCycle.weekly =>
        monthStart.difference(anchor).inDays ~/ cycle.days - 1,
      BillingCycle.monthly =>
        (monthStart.year - anchor.year) * 12 +
            monthStart.month -
            anchor.month -
            1,
      BillingCycle.quarterly =>
        ((monthStart.year - anchor.year) * 12 +
                    monthStart.month -
                    anchor.month) ~/
                3 -
            1,
      BillingCycle.yearly => monthStart.year - anchor.year - 1,
    };
  }

  static DateTime Function(DateTime, int) _stepFor(BillingCycle cycle) {
    return switch (cycle) {
      BillingCycle.weekly => (anchor, index) => anchor.add(
        Duration(days: 7 * index),
      ),
      BillingCycle.monthly => (anchor, index) => _addMonths(anchor, index),
      BillingCycle.quarterly => (anchor, index) => _addMonths(
        anchor,
        index * 3,
      ),
      BillingCycle.yearly => (anchor, index) => _addMonths(anchor, index * 12),
    };
  }

  static DateTime _addMonths(DateTime anchor, int months) {
    final zeroBased = anchor.year * 12 + anchor.month - 1 + months;
    final year = zeroBased ~/ 12;
    final month = zeroBased % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, anchor.day.clamp(1, lastDay));
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
