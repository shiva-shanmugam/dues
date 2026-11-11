import 'dart:async';

import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/services/spending_insights_service.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
import 'package:dues/presentation/providers/reminder_sync_provider.dart';
import 'package:dues/presentation/widgets/commitment_calendar.dart';
import 'package:dues/presentation/widgets/receipt_widgets.dart';
import 'package:dues/presentation/widgets/receipt_intro.dart';
import 'package:dues/presentation/widgets/spending_insights_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(subscriptionsProvider);
    final subscriptions = subscriptionsAsync.value ?? const <Subscription>[];
    final transactions = ref.watch(transactionsProvider).value ?? const [];
    final now = ref.watch(clockProvider);
    final active = subscriptions.where((item) => !item.isPaused).toList()
      ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    final currency = ref.watch(appPreferencesProvider).value?.currency ?? 'INR';
    final inCurrency = active
        .where((item) => item.currency == currency)
        .toList();
    final monthly = inCurrency.fold<double>(
      0,
      (sum, item) => sum + item.monthlyEquivalent,
    );
    final insights = SpendingInsightsService.calculate(
      subscriptions: subscriptions,
      transactions: transactions,
      now: now,
      currency: currency,
    );

    return CustomScrollView(
      key: const PageStorageKey('home-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
          sliver: SliverList.list(
            children: [
              _StatementHeader(
                now: now,
                onCalendar: () =>
                    _showCalendar(context, ref, subscriptions, now),
              ),
              const SizedBox(height: 16),
              const DashedDivider(),
              if (subscriptionsAsync.isLoading && subscriptions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (active.isEmpty)
                _EmptyStatement(onScan: () => _scanSms(context, ref))
              else ...[
                const SizedBox(height: 8),
                for (final item in active)
                  LeaderLine(
                    label: item.name.toUpperCase(),
                    amount: formatReceiptAmount(
                      item.amount,
                      currency: item.currency,
                    ),
                  ),
                const SizedBox(height: 8),
                const DashedDivider(),
                const SizedBox(height: 28),
                _Totals(monthly: monthly, currency: currency),
                if (inCurrency.length != active.length) ...[
                  const SizedBox(height: 10),
                  Text(
                    'TOTALS USE $currency. OTHER CURRENCIES ARE LISTED WITHOUT CONVERSION.',
                    style: TextStyle(
                      color: context.receipt.muted,
                      fontSize: 10,
                      height: 1.5,
                      letterSpacing: .5,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                _NextDueStamp(subscription: active.first, now: now),
                const SizedBox(height: 44),
                SpendingInsightsSection(insights: insights, currency: currency),
              ],
              if (subscriptionsAsync.hasError) ...[
                const SizedBox(height: 24),
                Text(
                  'COULD NOT READ THE LOCAL STATEMENT.',
                  style: TextStyle(color: context.receipt.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showCalendar(
    BuildContext context,
    WidgetRef ref,
    List<Subscription> subscriptions,
    DateTime now,
  ) {
    ref.read(hapticsProvider).selectionClick();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .58),
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: CommitmentCalendar(
              subscriptions: subscriptions,
              now: now,
              onInteraction: () => ref.read(hapticsProvider).selectionClick(),
              onClose: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _scanSms(BuildContext context, WidgetRef ref) async {
    ref.read(hapticsProvider).selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    try {
      var granted = await ref.read(smsInboxProvider).hasPermission();
      if (!granted) {
        granted = await ref.read(smsInboxProvider).requestPermission();
      }
      if (!granted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('SMS ACCESS IS NEEDED TO SCAN FOR SUBSCRIPTIONS.'),
          ),
        );
        return;
      }
      final result = await ref.read(smsImportServiceProvider).import();
      ref.invalidate(transactionsProvider);
      unawaited(ref.read(reminderSyncProvider).sync());
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'SCAN COMPLETE / ${result.subscriptionsFound} SUBSCRIPTIONS FOUND',
            ),
          ),
        );
      }
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('SMS SCAN COULD NOT BE COMPLETED.')),
        );
      }
    }
  }
}

class _StatementHeader extends StatelessWidget {
  const _StatementHeader({required this.now, required this.onCalendar});

  final DateTime now;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      const Expanded(child: DuesTitle()),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          '${HomePage._months[now.month - 1]} ${now.year} STATEMENT',
          maxLines: 2,
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.receipt.muted,
            fontSize: 11,
            letterSpacing: .8,
            height: 1.4,
          ),
        ),
      ),
      const SizedBox(width: 10),
      _CalendarNoteButton(now: now, onTap: onCalendar),
    ],
  );
}

class _CalendarNoteButton extends StatelessWidget {
  const _CalendarNoteButton({required this.now, required this.onTap});

  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open commitment calendar',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('home-calendar-button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 42,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: context.receipt.divider),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 9,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(height: 1, color: context.receipt.ink),
                    ),
                    for (final left in [10.0, 27.0])
                      Positioned(
                        left: left,
                        top: -3,
                        child: Container(
                          width: 3,
                          height: 7,
                          color: context.receipt.ink,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    now.day.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Totals extends StatelessWidget {
  const _Totals({required this.monthly, required this.currency});

  final double monthly;
  final String currency;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('TOTAL/MO', style: Theme.of(context).textTheme.receiptLabel),
      const SizedBox(height: 8),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          formatReceiptAmount(monthly, currency: currency),
          style: Theme.of(context).textTheme.receiptTotal,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'PROJECTED / YEAR  ${formatReceiptAmount(monthly * 12, currency: currency)}',
        maxLines: 2,
        style: TextStyle(
          color: context.receipt.muted,
          fontSize: 12,
          letterSpacing: .5,
        ),
      ),
    ],
  );
}

class _NextDueStamp extends StatelessWidget {
  const _NextDueStamp({required this.subscription, required this.now});

  final Subscription subscription;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final days = subscription.daysRemainingFrom(now);
    final timing = days < 0
        ? '${days.abs()} DAYS OVERDUE'
        : days == 0
        ? 'TODAY'
        : 'IN $days DAYS';
    return Stamp(
      child: Text(
        'NEXT DUE: ${subscription.name.toUpperCase()} / $timing · '
        '${formatReceiptAmount(subscription.amount, currency: subscription.currency)}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _EmptyStatement extends StatelessWidget {
  const _EmptyStatement({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Column(
      children: [
        Text(
          'NO SUBSCRIPTIONS FOUND',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.receiptLabel,
        ),
        const SizedBox(height: 12),
        Text(
          'SCAN YOUR LOCAL SMS INBOX OR ADD ONE MANUALLY.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.receipt.muted,
            fontSize: 11,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        ReceiptButton(
          label: 'SCAN SMS',
          variant: ReceiptButtonVariant.dashed,
          onPressed: onScan,
        ),
      ],
    ),
  );
}
