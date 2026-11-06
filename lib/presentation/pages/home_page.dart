import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/core/utils/formatters.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
import 'package:dues/presentation/widgets/dues_card.dart';
import 'package:dues/presentation/widgets/glyph_ring.dart';
import 'package:dues/presentation/widgets/subscription_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions =
        ref.watch(subscriptionsProvider).value ?? const <Subscription>[];
    final now = ref.watch(clockProvider);
    final active = subscriptions.where((item) => !item.isPaused).toList();
    final currency = ref.watch(appPreferencesProvider).value?.currency ?? 'INR';
    final inCurrency = active
        .where((item) => item.currency == currency)
        .toList();
    final monthly = inCurrency.fold<double>(
      0,
      (sum, item) => sum + item.monthlyEquivalent,
    );
    final upcoming =
        active.where((item) => item.daysRemainingFrom(now) <= 7).toList()
          ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    final costliest = [...inCurrency]
      ..sort((a, b) => b.monthlyEquivalent.compareTo(a.monthlyEquivalent));

    return CustomScrollView(
      key: const PageStorageKey('home-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
          sliver: SliverList.list(
            children: [
              _Header(count: active.length),
              const SizedBox(height: 28),
              _MonthlyHero(monthly: monthly, currency: currency),
              if (inCurrency.length != active.length) ...[
                const SizedBox(height: 8),
                Text(
                  'Totals and cost ranking are in $currency. Other currencies stay separate; no conversion is applied.',
                  style: const TextStyle(
                    color: DuesColors.muted,
                    fontSize: 9,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _MetricGrid(
                monthly: monthly,
                upcomingCount: upcoming.length,
                currency: currency,
              ),
              const SizedBox(height: 30),
              _SectionLabel(
                title: 'NEXT 7 DAYS',
                trailing: '${upcoming.length} DUE',
              ),
              const SizedBox(height: 12),
              if (upcoming.isEmpty)
                const _EmptyCard(message: 'No renewals in the next seven days.')
              else
                for (final item in upcoming) ...[
                  _UpcomingRow(subscription: item, now: now),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 20),
              const _SectionLabel(title: 'COSTLIEST', trailing: 'TOP 3'),
              const SizedBox(height: 12),
              DuesCard(
                child: Column(
                  children: [
                    for (var i = 0; i < costliest.take(3).length; i++) ...[
                      _CostRow(index: i + 1, subscription: costliest[i]),
                      if (i < costliest.take(3).length - 1)
                        const Divider(height: 26),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DUES', style: Theme.of(context).textTheme.dotTitle),
            const SizedBox(height: 5),
            Text(
              '$count ACTIVE SUBSCRIPTIONS',
              style: Theme.of(context).textTheme.label,
            ),
          ],
        ),
      ),
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: DuesColors.outline),
        ),
        child: const Icon(Icons.shield_outlined, size: 19),
      ),
    ],
  );
}

class _MonthlyHero extends StatelessWidget {
  const _MonthlyHero({required this.monthly, required this.currency});
  final double monthly;
  final String currency;

  @override
  Widget build(BuildContext context) => DuesCard(
    color: DuesColors.surfaceRaised,
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('MONTHLY OUTGO', style: Theme.of(context).textTheme.label),
            const _LivePill(),
          ],
        ),
        const SizedBox(height: 23),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatMoney(monthly, currency),
            style: Theme.of(context).textTheme.dotNumber.copyWith(fontSize: 52),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'ESTIMATED FROM RECURRING CHARGES',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: .8,
            color: DuesColors.muted,
          ),
        ),
      ],
    ),
  );
}

class _LivePill extends StatelessWidget {
  const _LivePill();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: DuesColors.outline),
    ),
    child: const Row(
      children: [
        SizedBox(
          width: 6,
          height: 6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: DuesColors.red,
              shape: BoxShape.circle,
            ),
          ),
        ),
        SizedBox(width: 6),
        Text(
          'LIVE',
          style: TextStyle(
            fontSize: 8,
            letterSpacing: 1,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.monthly,
    required this.upcomingCount,
    required this.currency,
  });
  final double monthly;
  final int upcomingCount;
  final String currency;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _MetricCard(
          label: 'YEARLY PROJECTION',
          value: formatMoney(monthly * 12, currency),
          icon: Icons.trending_up,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _MetricCard(
          label: 'DUE THIS WEEK',
          value: '$upcomingCount',
          icon: Icons.calendar_today_outlined,
          accent: upcomingCount > 0,
        ),
      ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool accent;

  @override
  Widget build(BuildContext context) => DuesCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accent ? DuesColors.red : DuesColors.muted, size: 18),
        const SizedBox(height: 24),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Doto',
              fontVariations: [FontVariation('wght', 800)],
              fontSize: 27,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 8,
            letterSpacing: .6,
            color: DuesColors.muted,
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.trailing});
  final String title;
  final String trailing;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.label
            .copyWith(color: DuesColors.offWhite),
      ),
      Text(
        trailing,
        style: Theme.of(context).textTheme.label.copyWith(fontSize: 9),
      ),
    ],
  );
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.subscription, required this.now});
  final Subscription subscription;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final days = subscription.daysRemainingFrom(now);
    return DuesCard(
      onTap: () => _showDetails(context, subscription),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          GlyphRing(days: days, cycleDays: subscription.cycle.days),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subscription.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${formatShortDate(subscription.nextDueDate)} · ${subscription.cycle.label}',
                  style: const TextStyle(
                    color: DuesColors.muted,
                    fontSize: 9,
                    letterSpacing: .5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatMoney(subscription.amount, subscription.currency),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({required this.index, required this.subscription});
  final int index;
  final Subscription subscription;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () => _showDetails(context, subscription),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            index.toString().padLeft(2, '0'),
            style: const TextStyle(color: DuesColors.muted, fontSize: 10),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              subscription.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Text(
            '${formatMoney(subscription.monthlyEquivalent, subscription.currency)}/MO',
            style: const TextStyle(fontSize: 10, color: DuesColors.muted),
          ),
        ],
      ),
    ),
  );
}

void _showDetails(BuildContext context, Subscription subscription) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DuesColors.surfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: DuesColors.outline),
    ),
    builder: (context) => SubscriptionDetailSheet(subscription: subscription),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => DuesCard(
    child: Text(
      message,
      style: const TextStyle(color: DuesColors.muted, fontSize: 11),
    ),
  );
}
