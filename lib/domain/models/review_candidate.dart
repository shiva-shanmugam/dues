import 'package:dues/domain/models/subscription.dart';

class ReviewCandidate {
  const ReviewCandidate({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.currency,
    required this.cycle,
    required this.nextDueDate,
    required this.occurrences,
    this.signal,
  });

  final String id;
  final String merchant;
  final double amount;
  final String currency;
  final BillingCycle cycle;
  final DateTime nextDueDate;
  final int occurrences;
  final String? signal;
}
