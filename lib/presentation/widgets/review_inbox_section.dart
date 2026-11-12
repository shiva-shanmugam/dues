import 'dart:async';

import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/domain/models/review_candidate.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/services/currency_converter.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
import 'package:dues/presentation/providers/reminder_sync_provider.dart';
import 'package:dues/presentation/widgets/receipt_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReviewInboxSection extends ConsumerWidget {
  const ReviewInboxSection({required this.displayCurrency, super.key});

  final String displayCurrency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(reviewCandidatesProvider).value ?? const [];
    if (candidates.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'REVIEW INBOX',
                style: Theme.of(context).textTheme.receiptLabel,
              ),
            ),
            Text(
              '${candidates.length.toString().padLeft(2, '0')} PENDING',
              style: TextStyle(color: context.receipt.muted, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const DashedDivider(),
        const SizedBox(height: 8),
        for (final candidate in candidates)
          LeaderLine(
            key: ValueKey('review-${candidate.id}'),
            label: candidate.merchant.toUpperCase(),
            amount: '${candidate.occurrences}× · REVIEW >',
            onTap: () => _openReview(context, ref, candidate),
          ),
        const SizedBox(height: 8),
        Text(
          'DUES FOUND A REPEATING PAYMENT. REVIEW IT BEFORE IT JOINS YOUR LIST.',
          style: TextStyle(
            color: context.receipt.muted,
            fontSize: 10,
            height: 1.5,
            letterSpacing: .35,
          ),
        ),
      ],
    );
  }

  void _openReview(
    BuildContext context,
    WidgetRef ref,
    ReviewCandidate candidate,
  ) {
    ref.read(hapticsProvider).selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _ReviewSheet(candidate: candidate, displayCurrency: displayCurrency),
    );
  }
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.candidate, required this.displayCurrency});
  final ReviewCandidate candidate;
  final String displayCurrency;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  CommitmentCategory _category = CommitmentCategory.subscription;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'REPEATING PAYMENT?',
                style: Theme.of(context).textTheme.receiptHeading,
              ),
              const SizedBox(height: 8),
              LeaderLine(
                label: candidate.merchant.toUpperCase(),
                amount: formatReceiptAmount(
                  CurrencyConverter.convert(
                    candidate.amount,
                    from: candidate.currency,
                    to: widget.displayCurrency,
                  ),
                  currency: widget.displayCurrency,
                ),
              ),
              LeaderLine(label: 'PATTERN', amount: candidate.cycle.label),
              LeaderLine(
                label: 'EVIDENCE',
                amount: '${candidate.occurrences} MATCHES',
              ),
              if (candidate.signal != null)
                LeaderLine(
                  label: 'SMS SIGNAL',
                  amount: candidate.signal!.toUpperCase(),
                ),
              const SizedBox(height: 16),
              Text(
                'WHAT IS IT?',
                style: Theme.of(context).textTheme.receiptLabel,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in CommitmentCategory.values)
                    ChoiceChip(
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: _busy
                          ? null
                          : (_) {
                              ref.read(hapticsProvider).selectionClick();
                              setState(() => _category = category);
                            },
                    ),
                ],
              ),
              const SizedBox(height: 22),
              ReceiptButton(
                label: 'TRACK THIS',
                busy: _busy,
                onPressed: _busy ? null : _track,
              ),
              const SizedBox(height: 10),
              ReceiptButton(
                label: 'NOT RECURRING',
                variant: ReceiptButtonVariant.dashed,
                onPressed: _busy ? null : _ignore,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _track() async {
    setState(() => _busy = true);
    ref.read(hapticsProvider).selectionClick();
    final candidate = widget.candidate;
    try {
      await ref
          .read(repositoryProvider)
          .saveSubscription(
            Subscription(
              id: 'sms:${candidate.id.substring('review:'.length)}',
              name: candidate.merchant,
              normalizedMerchant: candidate.merchant,
              amount: candidate.amount,
              currency: candidate.currency,
              cycle: candidate.cycle,
              nextDueDate: candidate.nextDueDate,
              category: _category,
              isAutoDetected: true,
            ),
          );
      await ref.read(reviewRepositoryProvider).removeCandidate(candidate.id);
      unawaited(ref.read(reminderSyncProvider).sync());
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ignore() async {
    setState(() => _busy = true);
    ref.read(hapticsProvider).selectionClick();
    final candidate = widget.candidate;
    try {
      await ref.read(repositoryProvider).ignoreMerchant(candidate.merchant);
      await ref.read(reviewRepositoryProvider).removeCandidate(candidate.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }
}
