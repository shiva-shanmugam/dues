enum RecurringSignal { freeTrial, autoDebit, mandate, renewal }

class ParsedTransaction {
  const ParsedTransaction({
    required this.messageId,
    required this.sender,
    required this.rawBody,
    required this.rawMerchant,
    required this.merchant,
    required this.amount,
    required this.currency,
    required this.occurredAt,
    required this.isDebit,
    this.signal,
  });

  final String messageId;
  final String sender;
  final String rawBody;
  final String rawMerchant;
  final String merchant;
  final double amount;
  final String currency;
  final DateTime occurredAt;
  final bool isDebit;
  final RecurringSignal? signal;
}
