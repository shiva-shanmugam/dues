import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/core/utils/formatters.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/models/transaction_record.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/widgets/dues_card.dart';
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

  @override
  void initState() {
    super.initState();
    _history = _loadHistory();
  }

  Future<List<TransactionRecord>> _loadHistory() {
    final merchant = widget.subscription.normalizedMerchant;
    if (merchant == null || merchant.isEmpty) {
      return Future.value(const []);
    }
    return ref
        .read(repositoryProvider)
        .getRecentTransactionsForMerchant(merchant)
        .timeout(const Duration(seconds: 10));
  }

  @override
  Widget build(BuildContext context) {
    final subscription = widget.subscription;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 10),
                child: SizedBox(width: 36, child: Divider(thickness: 3)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 12, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscription.name,
                          style: Theme.of(context).textTheme.dotTitle
                              .copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${formatMoney(subscription.amount, subscription.currency)} · ${subscription.cycle.label}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: DuesColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close details',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<TransactionRecord>>(
                future: _history,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Could not load saved messages.',
                            style: TextStyle(color: DuesColors.muted),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _history = _loadHistory();
                            }),
                            child: const Text('TRY AGAIN'),
                          ),
                        ],
                      ),
                    );
                  }
                  final messages = snapshot.data ?? const [];
                  return ListView(
                    padding: const EdgeInsets.all(22),
                    children: [
                      Text(
                        'SOURCE SMS',
                        style: Theme.of(context).textTheme.label,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        subscription.normalizedMerchant == null
                            ? 'Added manually. This subscription has no linked SMS history.'
                            : messages.isEmpty
                            ? 'No saved transaction messages match this merchant yet.'
                            : 'Latest ${messages.length} saved transaction messages for ${subscription.normalizedMerchant}.',
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.6,
                          color: DuesColors.muted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (final message in messages) ...[
                        _SmsCard(message: message),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmsCard extends StatelessWidget {
  const _SmsCard({required this.message});
  final TransactionRecord message;

  @override
  Widget build(BuildContext context) => DuesCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                message.sender,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              formatMoney(message.amount, message.currency),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${formatShortDate(message.occurredAt)} ${message.occurredAt.year} · ${message.occurredAt.hour.toString().padLeft(2, '0')}:${message.occurredAt.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 9, color: DuesColors.muted),
        ),
        const Divider(height: 24),
        SelectableText(
          message.body,
          style: const TextStyle(fontSize: 11, height: 1.65),
        ),
      ],
    ),
  );
}
