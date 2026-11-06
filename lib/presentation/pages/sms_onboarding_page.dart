import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/presentation/widgets/dues_card.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DUES', style: Theme.of(context).textTheme.dotTitle),
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: DuesColors.outline),
                ),
                child: const Icon(
                  Icons.sms_outlined,
                  size: 30,
                  color: DuesColors.red,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'FIND RECURRING\nCHARGES, PRIVATELY.',
                style: TextStyle(
                  fontFamily: 'Doto',
                  fontVariations: [FontVariation('wght', 900)],
                  fontSize: 35,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Dues reads transaction messages from banks, cards and UPI apps to spot repeating payments. Parsing happens entirely on this device.',
                style: TextStyle(
                  color: DuesColors.muted,
                  fontSize: 11,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 24),
              const DuesCard(
                child: Column(
                  children: [
                    _PrivacyRow(
                      icon: Icons.lock_outline,
                      text: 'MESSAGES NEVER LEAVE YOUR PHONE',
                    ),
                    Divider(height: 26),
                    _PrivacyRow(
                      icon: Icons.cloud_off_outlined,
                      text: 'NO ACCOUNT, CLOUD OR ANALYTICS',
                    ),
                    Divider(height: 26),
                    _PrivacyRow(
                      icon: Icons.visibility_off_outlined,
                      text: 'ONLY TRANSACTION SMS ARE SAVED',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: isLoading ? null : onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: DuesColors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: DuesColors.offWhite,
                          ),
                        )
                      : const Text(
                          'CONTINUE TO SMS ACCESS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: .8,
                            fontSize: 11,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: DuesColors.muted),
      const SizedBox(width: 13),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 9,
            letterSpacing: .6,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );
}
