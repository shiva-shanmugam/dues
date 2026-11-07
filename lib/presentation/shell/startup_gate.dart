import 'package:dues/presentation/pages/sms_onboarding_page.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/shell/app_shell.dart';
import 'package:dues/presentation/widgets/receipt_intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({super.key});

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  bool? _seenOnboarding;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final seen = await ref
        .read(localSettingsProvider)
        .getBool('smsOnboardingSeen');
    if (mounted) setState(() => _seenOnboarding = seen);
  }

  Future<void> _continue() async {
    setState(() => _loading = true);
    await ref
        .read(localSettingsProvider)
        .setBool('smsOnboardingSeen', value: true);
    final granted = await ref.read(smsInboxProvider).requestPermission();
    if (granted) {
      await ref.read(smsImportServiceProvider).import();
      final notificationsGranted = await ref
          .read(notificationServiceProvider)
          .requestPermission();
      if (notificationsGranted) {
        final subscriptions = await ref
            .read(repositoryProvider)
            .getSubscriptions();
        await ref
            .read(notificationServiceProvider)
            .scheduleRenewals(subscriptions);
      }
    }
    if (mounted) setState(() => _seenOnboarding = true);
  }

  @override
  Widget build(BuildContext context) {
    return ReceiptIntro(ready: _seenOnboarding != null, child: _content());
  }

  Widget _content() {
    if (_seenOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_seenOnboarding!) {
      return SmsOnboardingPage(onContinue: _continue, isLoading: _loading);
    }
    return const AppShell();
  }
}
