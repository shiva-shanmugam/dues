import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/core/utils/formatters.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
import 'package:dues/presentation/widgets/receipt_widgets.dart';
import 'package:dues/presentation/widgets/subscription_detail_sheet.dart';
import 'package:dues/presentation/widgets/subscription_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubscriptionsPage extends ConsumerWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions =
        ref.watch(subscriptionsProvider).value ?? const <Subscription>[];
    final sorted = [...subscriptions]
      ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    return CustomScrollView(
      key: const PageStorageKey('subscriptions-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
          sliver: SliverList.list(
            children: [
              Text(
                'SUBSCRIPTIONS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.receiptHeading,
              ),
              const SizedBox(height: 16),
              const DashedDivider(),
              const SizedBox(height: 8),
              if (sorted.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'NO SUBSCRIPTIONS ON FILE.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.receipt.muted,
                      fontSize: 12,
                      letterSpacing: .8,
                    ),
                  ),
                )
              else
                for (final subscription in sorted)
                  _SubscriptionLine(
                    subscription: subscription,
                    onTap: () => _showDetails(context, ref, subscription),
                  ),
              const SizedBox(height: 24),
              ReceiptButton(
                label: '+ ADD MANUALLY',
                variant: ReceiptButtonVariant.dashed,
                onPressed: () => _showEditor(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditor(BuildContext context, WidgetRef ref) {
    ref.read(hapticsProvider).selectionClick();
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          const SafeArea(top: false, child: SubscriptionEditorSheet()),
    );
  }

  void _showDetails(
    BuildContext context,
    WidgetRef ref,
    Subscription subscription,
  ) {
    ref.read(hapticsProvider).selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SubscriptionDetailSheet(subscription: subscription),
    );
  }
}

class _SubscriptionLine extends StatelessWidget {
  const _SubscriptionLine({required this.subscription, required this.onTap});

  final Subscription subscription;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: subscription.isPaused ? .55 : 1,
    duration: const Duration(milliseconds: 150),
    child: Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscription.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subscription.isPaused
                              ? '${subscription.cycle.label.toUpperCase()} · PAUSED'
                              : '${subscription.cycle.label.toUpperCase()} · NEXT ${formatShortDate(subscription.nextDueDate)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.receipt.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatReceiptAmount(
                      subscription.amount,
                      currency: subscription.currency,
                    ),
                    maxLines: 1,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const DashedDivider(height: 1, dash: 2, gap: 4),
      ],
    ),
  );
}
