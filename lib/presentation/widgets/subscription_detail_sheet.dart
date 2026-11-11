import 'dart:async';

import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/core/utils/formatters.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/models/transaction_record.dart';
import 'package:dues/parser/merchant_normalizer.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
import 'package:dues/presentation/providers/reminder_sync_provider.dart';
import 'package:dues/presentation/widgets/receipt_widgets.dart';
import 'package:dues/presentation/widgets/subscription_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubscriptionDetailSheet extends ConsumerStatefulWidget {
  const SubscriptionDetailSheet({required this.subscription, super.key});

  final Subscription subscription;

  @override
  ConsumerState<SubscriptionDetailSheet> createState() =>
      _SubscriptionDetailSheetState();
}

class _SubscriptionDetailSheetState
    extends ConsumerState<SubscriptionDetailSheet> {
  late Future<List<TransactionRecord>> _history;
  late bool _paused;
  bool _changingPause = false;

  @override
  void initState() {
    super.initState();
    _paused = widget.subscription.isPaused;
    _history = _loadHistory();
  }

  Future<List<TransactionRecord>> _loadHistory() {
    final merchant = widget.subscription.normalizedMerchant;
    if (merchant == null || merchant.isEmpty) return Future.value(const []);
    return ref
        .read(repositoryProvider)
        .getRecentTransactionsForMerchant(merchant)
        .timeout(const Duration(seconds: 10));
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message.toUpperCase())));
  }

  Future<void> _togglePause() async {
    if (_changingPause) return;
    ref.read(hapticsProvider).selectionClick();
    setState(() => _changingPause = true);
    try {
      await ref
          .read(repositoryProvider)
          .setPaused(widget.subscription.id, paused: !_paused)
          .timeout(const Duration(seconds: 10));
      if (mounted) setState(() => _paused = !_paused);
      unawaited(ref.read(reminderSyncProvider).sync());
    } catch (_) {
      _message('Could not update reminders. Please try again.');
    } finally {
      if (mounted) setState(() => _changingPause = false);
    }
  }

  Future<void> _edit() async {
    ref.read(hapticsProvider).selectionClick();
    final saved = await showSubscriptionEditor(
      context,
      subscription: widget.subscription.copyWith(isPaused: _paused),
    );
    if (saved == true && mounted) Navigator.pop(context);
  }

  Future<void> _remove({required bool ignore}) async {
    ref.read(hapticsProvider).selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ignore ? 'NOT A SUBSCRIPTION?' : 'DELETE ENTRY?'),
        content: Text(
          ignore
              ? 'THIS REMOVES THE ENTRY AND TEACHES FUTURE SMS SCANS TO IGNORE THIS MERCHANT. YOU CAN RESTORE IT IN CONFIG.'
              : 'THIS ONLY REMOVES THE SAVED ENTRY. A FUTURE SMS SCAN MAY DETECT IT AGAIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(ignore ? 'REMOVE + IGNORE' : 'DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final repository = ref.read(repositoryProvider);
      final reminderSync = ref.read(reminderSyncProvider);
      if (ignore) {
        final merchant =
            widget.subscription.normalizedMerchant ??
            const MerchantNormalizer().normalize(widget.subscription.name);
        await repository
            .ignoreMerchant(merchant)
            .timeout(const Duration(seconds: 10));
      }
      await repository
          .deleteSubscription(widget.subscription.id)
          .timeout(const Duration(seconds: 10));
      unawaited(reminderSync.sync());
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _message('Could not remove this subscription. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = widget.subscription;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .92,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '< ALL SUBSCRIPTIONS',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: .7,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subscription.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.receiptHeading,
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    text: formatReceiptAmount(
                      subscription.amount,
                      currency: subscription.currency,
                    ),
                    children: [
                      TextSpan(
                        text: '/${subscription.cycle.label.toUpperCase()}',
                        style: TextStyle(
                          color: context.receipt.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  style: Theme.of(context).textTheme.receiptTotal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${subscription.isAutoDetected ? 'DETECTED FROM SMS' : 'SAVED LOCALLY'} · ${subscription.category.label} · NEXT ${formatShortDate(subscription.nextDueDate)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.receipt.muted,
                  fontSize: 11,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 14),
              const SectionHeader('CHARGE HISTORY'),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<TransactionRecord>>(
                  future: _history,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return _HistoryMessage(
                        message: 'COULD NOT LOAD SAVED MESSAGES.',
                        action: () => setState(() => _history = _loadHistory()),
                      );
                    }
                    final messages = snapshot.data ?? const [];
                    if (subscription.normalizedMerchant == null) {
                      return const _HistoryMessage(
                        message: 'Added manually. This subscription has no linked SMS history.',
                      );
                    }
                    if (messages.isEmpty) {
                      return const _HistoryMessage(
                        message: 'NO SAVED TRANSACTION MESSAGES MATCH THIS MERCHANT YET.',
                      );
                    }
                    return ListView(
                      key: const ValueKey('sms-history-scroll'),
                      padding: EdgeInsets.zero,
                      children: [
                        for (final message in messages) ...[
                          LeaderLine(
                            label:
                                '${formatShortDate(message.occurredAt)} ${message.occurredAt.year}',
                            amount: formatReceiptAmount(
                              message.amount,
                              currency: message.currency,
                            ),
                          ),
                          Text(
                            'SOURCE SMS · ${message.sender.toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.receipt.muted,
                              fontSize: 10,
                              letterSpacing: .5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            message.body,
                            style: TextStyle(
                              color: context.receipt.muted,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const DashedDivider(height: 1, dash: 2, gap: 4),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const DashedDivider(),
              const SizedBox(height: 10),
              ReceiptButton(
                label: _paused ? 'RESUME REMINDERS' : 'PAUSE REMINDERS',
                onPressed: _togglePause,
                busy: _changingPause,
              ),
              const SizedBox(height: 8),
              ReceiptButton(
                label: 'NOT A SUBSCRIPTION',
                variant: ReceiptButtonVariant.dashed,
                onPressed: () => _remove(ignore: true),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _TextAction(label: 'EDIT DETAILS', onTap: _edit),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TextAction(
                      label: 'DELETE',
                      onTap: () => _remove(ignore: false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({required this.message, this.action});

  final String message;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.receipt.muted,
            fontSize: 11,
            height: 1.5,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 10),
          TextButton(onPressed: action, child: const Text('TRY AGAIN')),
        ],
      ],
    ),
  );
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
            fontSize: 11,
            letterSpacing: .7,
          ),
        ),
      ),
    ),
  );
}
