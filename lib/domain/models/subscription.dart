enum BillingCycle {
  weekly('WEEKLY', 7),
  monthly('MONTHLY', 30),
  quarterly('QUARTERLY', 91),
  yearly('YEARLY', 365);

  const BillingCycle(this.label, this.days);
  final String label;
  final int days;
}

class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.cycle,
    required this.nextDueDate,
    this.currency = 'INR',
    this.normalizedMerchant,
    this.isPaused = false,
    this.isAutoDetected = true,
  });

  final String id;
  final String name;
  final double amount;
  final BillingCycle cycle;
  final DateTime nextDueDate;
  final String currency;
  final String? normalizedMerchant;
  final bool isPaused;
  final bool isAutoDetected;

  int daysRemainingFrom(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    return due.difference(today).inDays;
  }

  double get monthlyEquivalent => switch (cycle) {
    BillingCycle.weekly => amount * 52 / 12,
    BillingCycle.monthly => amount,
    BillingCycle.quarterly => amount / 3,
    BillingCycle.yearly => amount / 12,
  };

  Subscription copyWith({
    String? name,
    double? amount,
    BillingCycle? cycle,
    DateTime? nextDueDate,
    String? currency,
    String? normalizedMerchant,
    bool? isPaused,
    bool? isAutoDetected,
  }) => Subscription(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    cycle: cycle ?? this.cycle,
    nextDueDate: nextDueDate ?? this.nextDueDate,
    currency: currency ?? this.currency,
    normalizedMerchant: normalizedMerchant ?? this.normalizedMerchant,
    isPaused: isPaused ?? this.isPaused,
    isAutoDetected: isAutoDetected ?? this.isAutoDetected,
  );
}
