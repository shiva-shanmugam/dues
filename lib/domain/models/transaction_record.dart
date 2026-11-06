class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.sender,
    required this.body,
    required this.merchant,
    required this.amount,
    required this.currency,
    required this.occurredAt,
    required this.isDebit,
    this.signal,
  });

  final String id;
  final String sender;
  final String body;
  final String merchant;
  final double amount;
  final String currency;
  final DateTime occurredAt;
  final bool isDebit;
  final String? signal;
}
