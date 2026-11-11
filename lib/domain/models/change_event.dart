enum ChangeEventType { added, deleted, ignored, priceChanged, paused, resumed }

class ChangeEvent {
  const ChangeEvent({
    required this.id,
    required this.merchant,
    required this.type,
    required this.currency,
    required this.occurredAt,
    this.subscriptionId,
    this.beforeAmount,
    this.afterAmount,
  });

  final String id;
  final String merchant;
  final ChangeEventType type;
  final String currency;
  final DateTime occurredAt;
  final String? subscriptionId;
  final double? beforeAmount;
  final double? afterAmount;
}
