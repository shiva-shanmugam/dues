import 'package:dues/presentation/pages/home_page.dart';
import 'package:dues/presentation/pages/settings_page.dart';
import 'package:dues/presentation/pages/subscriptions_page.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
import 'package:dues/presentation/widgets/receipt_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const pages = [HomePage(), SubscriptionsPage(), SettingsPage()];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTabProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: selected, children: pages),
      ),
      bottomNavigationBar: ReceiptNavBar(
        selected: selected,
        onSelect: (index) {
          ref.read(hapticsProvider).selectionClick();
          ref.read(selectedTabProvider.notifier).select(index);
        },
      ),
    );
  }
}
