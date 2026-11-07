import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/core/utils/formatters.dart';
import 'package:dues/domain/models/transaction_record.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/widgets/receipt_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IgnoredMerchantSummary extends ConsumerStatefulWidget {
  const IgnoredMerchantSummary({required this.merchant, super.key});
  final String merchant;

  @override
  ConsumerState<IgnoredMerchantSummary> createState() =>
      _IgnoredMerchantSummaryState();
}

class _IgnoredMerchantSummaryState
    extends ConsumerState<IgnoredMerchantSummary> {
  late final Future<List<TransactionRecord>> history = ref
      .read(repositoryProvider)
      .getRecentTransactionsForMerchant(widget.merchant)
      .timeout(const Duration(seconds: 10));

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.merchant.toUpperCase(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    content: SizedBox(
      width: double.maxFinite,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'IGNORED DURING SMS SCANS',
              style: TextStyle(color: context.receipt.muted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            const DashedDivider(),
            FutureBuilder<List<TransactionRecord>>(
              future: history,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('SAVED HISTORY IS UNAVAILABLE.'),
                  );
                }
                final records = snapshot.data ?? [];
                if (records.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No saved payment history. This merchant is excluded from future scans.',
                    ),
                  );
                }
                final latest = records.first;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LeaderLine(
                      label: 'LATEST PAYMENT',
                      amount: formatReceiptAmount(
                        latest.amount,
                        currency: latest.currency,
                      ),
                    ),
                    LeaderLine(
                      label: 'PAID ON',
                      amount: formatShortDate(latest.occurredAt),
                    ),
                    LeaderLine(
                      label: 'RECENT MESSAGES',
                      amount: '${records.length}',
                    ),
                    Text(
                      'SOURCE: ${latest.sender}',
                      style: TextStyle(
                        color: context.receipt.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Restore only removes the ignore rule. Scan SMS again to detect this merchant.',
                      style: TextStyle(
                        color: context.receipt.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('CLOSE'),
      ),
    ],
  );
}
