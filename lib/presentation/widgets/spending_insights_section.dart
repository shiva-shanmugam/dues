import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/domain/services/spending_insights_service.dart';
import 'package:dues/presentation/widgets/receipt_widgets.dart';
import 'package:flutter/material.dart';

class SpendingInsightsSection extends StatelessWidget {
  const SpendingInsightsSection({
    required this.insights,
    required this.currency,
    super.key,
  });

  final SpendingInsights insights;
  final String currency;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('LOCAL INSIGHTS', style: Theme.of(context).textTheme.receiptLabel),
      const SizedBox(height: 10),
      const DashedDivider(),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InsightBox(
                width: width,
                label: 'ACTIVE',
                value: insights.activeCount.toString().padLeft(2, '0'),
                detail: 'COMMITMENTS',
              ),
              _InsightBox(
                width: width,
                label: 'FIXED / MO',
                value: formatReceiptAmount(
                  insights.monthlyCommitments,
                  currency: currency,
                ),
                detail:
                    '${formatReceiptAmount(insights.yearlyProjection, currency: currency)} / YEAR',
              ),
            ],
          );
        },
      ),
      if (insights.hasTransactionHistory) ...[
        const SizedBox(height: 18),
        _CompletedMonthChange(insights: insights, currency: currency),
        if (insights.priceChanges.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'PRICE CHANGES / THIS YEAR',
            style: Theme.of(context).textTheme.receiptLabel,
          ),
          const SizedBox(height: 6),
          for (final change in insights.priceChanges.take(3))
            LeaderLine(
              label: change.name.toUpperCase(),
              amount:
                  '${change.difference > 0 ? '+' : '-'}${formatReceiptAmount(change.difference.abs(), currency: currency)}',
            ),
        ],
        if (insights.newRecurringNames.isNotEmpty) ...[
          const SizedBox(height: 18),
          _NameList(
            label: 'NEW RECURRING / THIS MONTH',
            names: insights.newRecurringNames,
          ),
        ],
        if (insights.staleNames.isNotEmpty) ...[
          const SizedBox(height: 18),
          _NameList(label: 'NO RECENT CHARGE', names: insights.staleNames),
        ],
      ] else ...[
        const SizedBox(height: 14),
        Text(
          'MORE INSIGHTS APPEAR AS LOCAL SMS HISTORY BUILDS UP.',
          style: TextStyle(
            color: context.receipt.muted,
            fontSize: 10,
            height: 1.5,
            letterSpacing: .4,
          ),
        ),
      ],
    ],
  );
}

class _InsightBox extends StatelessWidget {
  const _InsightBox({
    required this.width,
    required this.label,
    required this.value,
    required this.detail,
  });

  final double width;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    constraints: const BoxConstraints(minHeight: 104),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: context.receipt.divider),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.receipt.muted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 14),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.receipt.muted, fontSize: 8),
        ),
      ],
    ),
  );
}

class _CompletedMonthChange extends StatelessWidget {
  const _CompletedMonthChange({required this.insights, required this.currency});

  final SpendingInsights insights;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final change = insights.completedMonthChange;
    final direction = change > 0
        ? 'UP'
        : change < 0
        ? 'DOWN'
        : 'UNCHANGED';
    return Stamp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RECURRING SPEND / LAST COMPLETE MONTH'),
          const SizedBox(height: 5),
          Text(
            '${formatReceiptAmount(insights.lastMonthSpend, currency: currency)} · '
            '$direction ${formatReceiptAmount(change.abs(), currency: currency)} VS PRIOR',
          ),
        ],
      ),
    );
  }
}

class _NameList extends StatelessWidget {
  const _NameList({required this.label, required this.names});

  final String label;
  final List<String> names;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.receiptLabel),
      const SizedBox(height: 6),
      Text(
        names.take(4).map((name) => name.toUpperCase()).join(' · '),
        style: TextStyle(
          color: context.receipt.muted,
          fontSize: 11,
          height: 1.5,
        ),
      ),
    ],
  );
}
