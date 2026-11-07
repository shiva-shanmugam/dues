import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/presentation/widgets/receipt_widgets.dart';
import 'package:dues/presentation/widgets/receipt_intro.dart';
import 'package:flutter/material.dart';

class SmsOnboardingPage extends StatelessWidget {
  const SmsOnboardingPage({
    required this.onContinue,
    required this.isLoading,
    super.key,
  });

  final VoidCallback onContinue;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          Row(
            children: [
              const Expanded(child: DuesTitle()),
              Text(
                'PRIVATE STATEMENT',
                style: TextStyle(
                  color: context.receipt.muted,
                  fontSize: 10,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const DashedDivider(),
          const SizedBox(height: 42),
          Text(
            'FIND RECURRING\nCHARGES, PRIVATELY.',
            style: Theme.of(context).textTheme.receiptHeading
                .copyWith(fontSize: 30, height: 1.2),
          ),
          const SizedBox(height: 20),
          Text(
            'DUES READS TRANSACTION MESSAGES FROM BANKS, CARDS AND UPI APPS TO FIND REPEATING PAYMENTS. PARSING HAPPENS ENTIRELY ON THIS DEVICE.',
            style: TextStyle(
              color: context.receipt.muted,
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          const SectionHeader('SMS ACCESS RECEIPT'),
          const SizedBox(height: 8),
          const LeaderLine(label: 'MESSAGES LEAVE PHONE', amount: 'NEVER'),
          const DashedDivider(height: 1, dash: 2, gap: 4),
          const LeaderLine(label: 'ACCOUNT / CLOUD', amount: 'NONE'),
          const DashedDivider(height: 1, dash: 2, gap: 4),
          const LeaderLine(label: 'ANALYTICS', amount: 'NONE'),
          const DashedDivider(height: 1, dash: 2, gap: 4),
          const LeaderLine(label: 'SAVED CONTENT', amount: 'TRANSACTIONS'),
          const SizedBox(height: 34),
          ReceiptButton(
            label: 'CONTINUE TO SMS ACCESS',
            onPressed: onContinue,
            busy: isLoading,
          ),
        ],
      ),
    ),
  );
}
