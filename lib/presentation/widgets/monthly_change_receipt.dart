import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/domain/models/change_event.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/services/currency_converter.dart';
import 'package:dues/presentation/widgets/receipt_widgets.dart';
import 'package:flutter/material.dart';

class MonthlyChangeReceipt extends StatelessWidget {
  const MonthlyChangeReceipt({
    required this.events,
    required this.subscriptions,
    required this.now,
    required this.currency,
    super.key,
  });

  final List<ChangeEvent> events;
  final List<Subscription> subscriptions;
  final DateTime now;
  final String currency;

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final monthEvents = events
        .where(
          (event) =>
              event.occurredAt.year == now.year &&
              event.occurredAt.month == now.month,
        )
        .toList();
    final missed = subscriptions
        .where((item) => !item.isPaused && item.daysRemainingFrom(now) < 0)
        .toList();
    final visible = monthEvents
        .where(
          (event) =>
              event.type == ChangeEventType.added ||
              event.type == ChangeEventType.deleted ||
              event.type == ChangeEventType.priceChanged ||
              event.type == ChangeEventType.paused ||
              event.type == ChangeEventType.resumed,
        )
        .toList();
    final net = visible.fold<double>(0, (sum, event) {
      final original = switch (event.type) {
        ChangeEventType.added => event.afterAmount ?? 0.0,
        ChangeEventType.deleted => -(event.beforeAmount ?? 0.0),
        ChangeEventType.priceChanged =>
          (event.afterAmount ?? 0.0) - (event.beforeAmount ?? 0.0),
        ChangeEventType.paused => -(event.beforeAmount ?? 0.0),
        ChangeEventType.resumed => event.afterAmount ?? 0.0,
        _ => 0.0,
      };
      return sum +
          CurrencyConverter.convert(
            original,
            from: event.currency,
            to: currency,
          );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'WHAT CHANGED?',
                style: Theme.of(context).textTheme.receiptLabel,
              ),
            ),
            Text(
              '${_months[now.month - 1]} ${now.year}',
              style: TextStyle(color: context.receipt.muted, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const DashedDivider(),
        const SizedBox(height: 8),
        if (visible.isEmpty && missed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'NO RECORDED CHANGES THIS MONTH.',
              style: TextStyle(color: context.receipt.muted, fontSize: 11),
            ),
          )
        else ...[
          for (final event in visible.take(6))
            LeaderLine(
              label:
                  '${_eventLabel(event.type)} · ${event.merchant.toUpperCase()}',
              amount: _eventAmount(event, currency),
            ),
          for (final item in missed.take(3))
            LeaderLine(
              label: 'MISSED? · ${item.name.toUpperCase()}',
              amount: '${item.daysRemainingFrom(now).abs()}D LATE',
            ),
          const SizedBox(height: 8),
          Stamp(
            child: Text(
              'RECORDED NET CHANGE  ${net >= 0 ? '+' : '-'}${formatReceiptAmount(net.abs(), currency: currency)}',
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'BUILT ONLY FROM CHANGES SAVED ON THIS DEVICE.',
          style: TextStyle(
            color: context.receipt.muted,
            fontSize: 9,
            letterSpacing: .4,
          ),
        ),
      ],
    );
  }

  String _eventLabel(ChangeEventType type) => switch (type) {
    ChangeEventType.added => 'ADDED',
    ChangeEventType.deleted => 'REMOVED',
    ChangeEventType.priceChanged => 'PRICE',
    ChangeEventType.paused => 'PAUSED',
    ChangeEventType.resumed => 'RESUMED',
    _ => type.name.toUpperCase(),
  };

  String _eventAmount(ChangeEvent event, String displayCurrency) {
    final difference = switch (event.type) {
      ChangeEventType.added => event.afterAmount ?? 0.0,
      ChangeEventType.deleted => -(event.beforeAmount ?? 0.0),
      ChangeEventType.priceChanged =>
        (event.afterAmount ?? 0.0) - (event.beforeAmount ?? 0.0),
      ChangeEventType.paused => -(event.beforeAmount ?? 0.0),
      ChangeEventType.resumed => event.afterAmount ?? 0.0,
      _ => 0.0,
    };
    final converted = CurrencyConverter.convert(
      difference,
      from: event.currency,
      to: displayCurrency,
    );
    return '${converted >= 0 ? '+' : '-'}${formatReceiptAmount(converted.abs(), currency: displayCurrency)}';
  }
}
