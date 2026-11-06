import 'dart:async';

import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/core/utils/formatters.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/parser/merchant_normalizer.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
import 'package:dues/presentation/providers/reminder_sync_provider.dart';
import 'package:dues/presentation/widgets/dues_card.dart';
import 'package:dues/presentation/widgets/glyph_ring.dart';
import 'package:dues/presentation/widgets/subscription_editor_sheet.dart';
import 'package:dues/presentation/widgets/subscription_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubscriptionsPage extends ConsumerWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions =
        ref.watch(subscriptionsProvider).value ?? const <Subscription>[];
    final now = ref.watch(clockProvider);
    return CustomScrollView(
      key: const PageStorageKey('subscriptions-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
          sliver: SliverList.list(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SUBSCRIPTIONS',
                          style: Theme.of(context).textTheme.dotTitle
                              .copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${subscriptions.length} TRACKED LOCALLY',
                          style: Theme.of(context).textTheme.label,
                        ),
                      ],
                    ),
                  ),
                  _AddButton(onPressed: () => _showEditor(context, ref)),
                ],
              ),
              const SizedBox(height: 28),
              for (final subscription in subscriptions) ...[
                _SubscriptionCard(
                  subscription: subscription,
                  now: now,
                  onEdit: () => _showEditor(context, ref, subscription),
                  onTap: () => _showDetails(context, ref, subscription),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showEditor(
    BuildContext context,
    WidgetRef ref, [
    Subscription? subscription,
  ]) {
    ref.read(hapticsProvider).mediumImpact();
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DuesColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: DuesColors.outline),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: SubscriptionEditorSheet(subscription: subscription),
      ),
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
      backgroundColor: DuesColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: DuesColors.outline),
      ),
      builder: (context) => SubscriptionDetailSheet(subscription: subscription),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Add subscription',
    onPressed: onPressed,
    style: IconButton.styleFrom(
      fixedSize: const Size(44, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: DuesColors.outline),
      ),
    ),
    icon: const Icon(Icons.add),
  );
}

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard({
    required this.subscription,
    required this.now,
    required this.onEdit,
    required this.onTap,
  });
  final Subscription subscription;
  final DateTime now;
  final VoidCallback onEdit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = subscription.daysRemainingFrom(now);
    return AnimatedOpacity(
      opacity: subscription.isPaused ? .45 : 1,
      duration: const Duration(milliseconds: 180),
      child: DuesCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        child: Row(
          children: [
            GlyphRing(days: days, cycleDays: subscription.cycle.days, size: 62),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          subscription.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!subscription.isAutoDetected) ...[
                        const SizedBox(width: 7),
                        const Icon(
                          Icons.edit_outlined,
                          size: 12,
                          color: DuesColors.muted,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${formatMoney(subscription.amount, subscription.currency)} · ${subscription.cycle.label}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: DuesColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subscription.isPaused
                        ? 'PAUSED'
                        : 'DUE ${formatShortDate(subscription.nextDueDate)}',
                    style: TextStyle(
                      fontSize: 8,
                      letterSpacing: .8,
                      color: days <= 3 && !subscription.isPaused
                          ? DuesColors.red
                          : DuesColors.muted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              color: DuesColors.surfaceRaised,
              icon: const Icon(Icons.more_vert, color: DuesColors.muted),
              onSelected: (value) async {
                ref.read(hapticsProvider).selectionClick();
                if (value == 'edit') {
                  onEdit();
                  return;
                }
                if (value == 'delete' || value == 'ignore') {
                  final confirmed = await _confirmRemoval(
                    context,
                    ignore: value == 'ignore',
                  );
                  if (!confirmed) return;
                }
                try {
                  final repository = ref.read(repositoryProvider);
                  final sync = ref.read(reminderSyncProvider);
                  if (value == 'pause') {
                    await repository
                        .setPaused(
                          subscription.id,
                          paused: !subscription.isPaused,
                        )
                        .timeout(const Duration(seconds: 10));
                  } else if (value == 'ignore') {
                    final merchant =
                        subscription.normalizedMerchant ??
                        const MerchantNormalizer().normalize(subscription.name);
                    await repository
                        .ignoreMerchant(merchant)
                        .timeout(const Duration(seconds: 10));
                    await repository
                        .deleteSubscription(subscription.id)
                        .timeout(const Duration(seconds: 10));
                  } else if (value == 'delete') {
                    await repository
                        .deleteSubscription(subscription.id)
                        .timeout(const Duration(seconds: 10));
                  }
                  unawaited(sync.sync());
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not update this subscription. Please try again.',
                        ),
                      ),
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'pause',
                  child: Text(subscription.isPaused ? 'Resume' : 'Pause'),
                ),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'ignore',
                  child: Text('Not a subscription'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete',
                    style: TextStyle(color: DuesColors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmRemoval(
    BuildContext context, {
    required bool ignore,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              ignore ? 'Not a subscription?' : 'Delete ${subscription.name}?',
            ),
            content: Text(
              ignore
                  ? 'Remove this item and ignore future SMS from this merchant during scans. You can allow it again in Settings → Ignored merchants.'
                  : 'Remove this saved item. A future SMS scan may detect it again. To prevent that, choose “Not a subscription” instead.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  ignore ? 'REMOVE & IGNORE' : 'DELETE',
                  style: const TextStyle(color: DuesColors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}
