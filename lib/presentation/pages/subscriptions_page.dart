import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/core/utils/formatters.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/widgets/dues_card.dart';
import 'package:dues/presentation/widgets/glyph_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubscriptionsPage extends ConsumerWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(subscriptionsProvider);
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
                  _AddButton(onPressed: () => _showAddPreview(context)),
                ],
              ),
              const SizedBox(height: 28),
              for (final subscription in subscriptions) ...[
                _SubscriptionCard(subscription: subscription, now: now),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showAddPreview(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: DuesColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: DuesColors.outline),
      ),
      builder: (context) => const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 36, child: Divider(thickness: 3)),
              SizedBox(height: 18),
              Icon(Icons.add_circle_outline, size: 32),
              SizedBox(height: 16),
              Text(
                'MANUAL ENTRY',
                style: TextStyle(
                  fontFamily: 'Doto',
                  fontVariations: [FontVariation('wght', 800)],
                  fontSize: 25,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'The add and edit form arrives with local persistence in the next build stage.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: DuesColors.muted,
                  height: 1.6,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
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
  const _SubscriptionCard({required this.subscription, required this.now});
  final Subscription subscription;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = subscription.daysRemainingFrom(now);
    return AnimatedOpacity(
      opacity: subscription.isPaused ? .45 : 1,
      duration: const Duration(milliseconds: 180),
      child: DuesCard(
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
                    '${formatInr(subscription.amount)} · ${subscription.cycle.label}',
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
              onSelected: (value) {
                HapticFeedback.selectionClick();
                if (value == 'pause') {
                  ref
                      .read(subscriptionsProvider.notifier)
                      .togglePaused(subscription.id);
                } else if (value == 'delete') {
                  ref
                      .read(subscriptionsProvider.notifier)
                      .remove(subscription.id);
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
}
