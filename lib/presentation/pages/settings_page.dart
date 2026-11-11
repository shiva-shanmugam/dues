import 'dart:io';

import 'package:csv/csv.dart';
import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/core/utils/formatters.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
import 'package:dues/presentation/providers/reminder_sync_provider.dart';
import 'package:dues/presentation/providers/theme_mode_provider.dart';
import 'package:dues/presentation/widgets/receipt_widgets.dart';
import 'package:dues/presentation/widgets/ignored_merchant_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool smsGranted = false;
  bool scanning = false;
  bool changingAlerts = false;

  static const _currencyNames = {
    'INR': 'INDIAN RUPEE',
    'USD': 'US DOLLAR',
    'EUR': 'EURO',
    'GBP': 'BRITISH POUND',
  };

  @override
  void initState() {
    super.initState();
    _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    try {
      final granted = await ref.read(smsInboxProvider).hasPermission();
      if (mounted) setState(() => smsGranted = granted);
    } catch (_) {
      // SMS support is Android-only; manual tracking remains available.
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(appPreferencesProvider);
    final current = preferences.value;
    final ignored = ref.watch(ignoredMerchantsProvider);
    final ignoredCount = ignored.value?.length;

    return CustomScrollView(
      key: const PageStorageKey('settings-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'CONFIG',
                      style: Theme.of(context).textTheme.receiptHeading,
                    ),
                  ),
                  const _ThemeCycleButton(),
                ],
              ),
              const SizedBox(height: 16),
              const DashedDivider(),
              const SizedBox(height: 28),
              const SectionHeader('DATA & PERMISSIONS'),
              const SizedBox(height: 4),
              LeaderLine(
                label: 'SMS ACCESS',
                amount: scanning
                    ? 'SCANNING...'
                    : smsGranted
                    ? 'GRANTED'
                    : 'REQUIRED',
                onTap: scanning ? null : _scanSms,
              ),
              const DashedDivider(height: 1, dash: 2, gap: 4),
              LeaderLine(
                label: 'RENEWAL ALERTS',
                amount: changingAlerts
                    ? 'SAVING...'
                    : current?.renewalAlertsEnabled == true
                    ? 'ON'
                    : 'OFF',
                onTap: current == null || changingAlerts
                    ? null
                    : () => _setAlerts(!current.renewalAlertsEnabled),
              ),
              const DashedDivider(height: 1, dash: 2, gap: 4),
              const LeaderLine(label: 'REMINDER TIMING', amount: '3D + 1D'),
              const DashedDivider(height: 1, dash: 2, gap: 4),
              LeaderLine(
                label: 'EXPORT CSV',
                amount: 'SHARE',
                onTap: _exportCsv,
              ),
              const SizedBox(height: 30),
              const SectionHeader('PREFERENCES'),
              const SizedBox(height: 4),
              LeaderLine(
                label: 'CURRENCY',
                amount: current?.currency ?? '...',
                onTap: current == null ? null : _chooseCurrency,
              ),
              const DashedDivider(height: 1, dash: 2, gap: 4),
              LeaderLine(
                key: const ValueKey('haptic-row'),
                label: 'HAPTIC TICKS',
                amount: current?.hapticsEnabled == true ? 'ON' : 'OFF',
                onTap: current == null
                    ? null
                    : () => _setHaptics(!current.hapticsEnabled),
              ),
              const DashedDivider(height: 1, dash: 2, gap: 4),
              LeaderLine(
                label: 'IGNORED MERCHANTS',
                amount: ignoredCount == null ? '...' : '$ignoredCount',
                onTap: _showIgnoredMerchants,
              ),
              if (preferences.hasError) ...[
                const SizedBox(height: 14),
                ReceiptButton(
                  label: 'RETRY PREFERENCES',
                  variant: ReceiptButtonVariant.dashed,
                  onPressed: () => ref.invalidate(appPreferencesProvider),
                ),
              ],
              const SizedBox(height: 32),
              const _PrivacyNotice(),
              const SizedBox(height: 28),
              Text(
                'DUES / LOCAL FIRST / NO NETWORK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.receipt.muted,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message.toUpperCase())));
  }

  Future<void> _setAlerts(bool enabled) async {
    ref.read(hapticsProvider).selectionClick();
    setState(() => changingAlerts = true);
    try {
      if (enabled) {
        final granted = await ref
            .read(notificationServiceProvider)
            .requestPermission()
            .timeout(const Duration(seconds: 30));
        if (!granted) {
          if (!mounted) return;
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('NOTIFICATIONS BLOCKED'),
              content: const Text(
                'Allow Dues notifications in Android settings, then tap renewal alerts again to enable them.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('OPEN SETTINGS'),
                ),
              ],
            ),
          );
          if (openSettings == true) {
            await ref.read(notificationServiceProvider).openSettings();
          }
          return;
        }
      }
      await ref
          .read(appPreferencesProvider.notifier)
          .setRenewalAlertsEnabled(enabled);
      final synced = await ref.read(reminderSyncProvider).sync();
      if (!synced) {
        _message('Preference saved. Reminder scheduling will retry.');
      }
    } catch (_) {
      _message('Could not update renewal alerts. Please try again.');
    } finally {
      if (mounted) setState(() => changingAlerts = false);
    }
  }

  Future<void> _setHaptics(bool enabled) async {
    try {
      await ref
          .read(appPreferencesProvider.notifier)
          .setHapticsEnabled(enabled);
      if (enabled) ref.read(hapticsProvider).selectionClick();
    } catch (_) {
      _message('Could not save haptic preference. Please try again.');
    }
  }

  Future<void> _chooseCurrency() async {
    ref.read(hapticsProvider).selectionClick();
    final current = ref.read(appPreferencesProvider).value?.currency ?? 'INR';
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('DEFAULT CURRENCY'),
              const SizedBox(height: 12),
              Text(
                'USED FOR NEW MANUAL ENTRIES AND STATEMENT TOTALS. EXISTING CHARGES KEEP THEIR ORIGINAL CURRENCY.',
                style: TextStyle(
                  color: context.receipt.muted,
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              for (final entry in _currencyNames.entries) ...[
                LeaderLine(
                  label: entry.value,
                  amount: current == entry.key ? '[${entry.key}]' : entry.key,
                  onTap: () => Navigator.pop(context, entry.key),
                ),
                const DashedDivider(height: 1, dash: 2, gap: 4),
              ],
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    try {
      await ref.read(appPreferencesProvider.notifier).setCurrency(selected);
    } catch (_) {
      _message('Could not save default currency. Please try again.');
    }
  }

  void _showIgnoredMerchants() {
    ref.read(hapticsProvider).selectionClick();
    ref.invalidate(ignoredMerchantsProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _IgnoredMerchantsSheet(),
    );
  }

  Future<void> _scanSms() async {
    ref.read(hapticsProvider).selectionClick();
    setState(() => scanning = true);
    try {
      var granted = await ref.read(smsInboxProvider).hasPermission();
      if (!granted) {
        granted = await ref.read(smsInboxProvider).requestPermission();
      }
      if (!granted) {
        _message(
          'SMS access was not granted. Manual tracking stays available.',
        );
        return;
      }
      final result = await ref.read(smsImportServiceProvider).import();
      ref.invalidate(transactionsProvider);
      final synced = await ref.read(reminderSyncProvider).sync();
      if (mounted) setState(() => smsGranted = true);
      _message(
        'Scanned ${result.messagesRead} messages / found ${result.subscriptionsFound} recurring patterns. Check the review inbox.${synced ? '' : ' Reminder scheduling will retry.'}',
      );
    } catch (_) {
      _message('Could not finish scanning messages. Please try again.');
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> _exportCsv() async {
    ref.read(hapticsProvider).selectionClick();
    try {
      final subscriptions = await ref
          .read(repositoryProvider)
          .getSubscriptions();
      final rows = <List<Object?>>[
        ['Name', 'Amount', 'Currency', 'Cycle', 'Next due', 'Paused', 'Source'],
        for (final item in subscriptions)
          [
            item.name,
            item.amount,
            item.currency,
            item.cycle.name,
            item.nextDueDate.toIso8601String().split('T').first,
            item.isPaused,
            item.isAutoDetected ? 'SMS' : 'Manual',
          ],
      ];
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/dues-subscriptions.csv');
      await file.writeAsString(csv.encode(rows));
      await SharePlus.instance.share(
        ShareParams(
          title: 'Dues subscriptions',
          text: 'Local Dues export / ${formatShortDate(DateTime.now())}',
          files: [XFile(file.path, mimeType: 'text/csv')],
        ),
      );
    } catch (_) {
      _message('Could not export subscriptions. Please try again.');
    }
  }
}

class _ThemeCycleButton extends ConsumerStatefulWidget {
  const _ThemeCycleButton();

  @override
  ConsumerState<_ThemeCycleButton> createState() => _ThemeCycleButtonState();
}

class _ThemeCycleButtonState extends ConsumerState<_ThemeCycleButton> {
  bool saving = false;

  Future<void> _cycle(ThemeMode current) async {
    final next = switch (current) {
      ThemeMode.system => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.system,
    };
    ref.read(hapticsProvider).selectionClick();
    setState(() => saving = true);
    try {
      await ref.read(themeModeProvider.notifier).setMode(next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('THEME COULD NOT BE SAVED.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncMode = ref.watch(themeModeProvider);
    final current = asyncMode.value ?? ThemeMode.system;
    return OutlinedButton(
      key: const ValueKey('theme-cycle'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(72, 44),
        side: BorderSide(color: context.receipt.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      onPressed: saving || asyncMode.isLoading ? null : () => _cycle(current),
      child: Text(
        current.name.toUpperCase(),
        style: const TextStyle(fontSize: 11, letterSpacing: .7),
      ),
    );
  }
}

class _IgnoredMerchantsSheet extends ConsumerWidget {
  const _IgnoredMerchantsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
    top: false,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('IGNORED MERCHANTS'),
            const SizedBox(height: 12),
            Text(
              'RESTORE A MERCHANT TO ALLOW DETECTION ON THE NEXT SMS SCAN.',
              style: TextStyle(
                color: context.receipt.muted,
                fontSize: 10,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ref
                  .watch(ignoredMerchantsProvider)
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Center(
                      child: ReceiptButton(
                        label: 'RETRY',
                        variant: ReceiptButtonVariant.dashed,
                        onPressed: () =>
                            ref.invalidate(ignoredMerchantsProvider),
                      ),
                    ),
                    data: (merchants) {
                      if (merchants.isEmpty) {
                        return Center(
                          child: Text(
                            'No ignored merchants.',
                            style: TextStyle(color: context.receipt.muted),
                          ),
                        );
                      }
                      final sorted = merchants.toList()..sort();
                      return ListView.builder(
                        itemCount: sorted.length,
                        itemBuilder: (context, index) => Column(
                          children: [
                            LeaderLine(
                              label: sorted[index].toUpperCase(),
                              amount: 'RESTORE',
                              onTap: () {
                                ref.read(hapticsProvider).selectionClick();
                                showDialog<void>(
                                  context: context,
                                  builder: (_) => IgnoredMerchantSummary(
                                    merchant: sorted[index],
                                  ),
                                );
                              },
                              trailing: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.only(left: 12),
                                  minimumSize: const Size(44, 44),
                                  alignment: Alignment.centerRight,
                                ),
                                onPressed: () =>
                                    _restore(context, ref, sorted[index]),
                                child: const Text(
                                  'RESTORE',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const DashedDivider(height: 1, dash: 2, gap: 4),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    String merchant,
  ) async {
    ref.read(hapticsProvider).selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RESTORE MERCHANT?'),
        content: Text(
          'Allow ${merchant.toUpperCase()} to be detected in future SMS scans? It will stay removed until a scan finds it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(repositoryProvider).unignoreMerchant(merchant);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MERCHANT COULD NOT BE RESTORED.')),
        );
      }
    }
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: context.receipt.divider),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STAYS ON THIS DEVICE',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'NO ACCOUNT. NO CLOUD. NO ANALYTICS. DATA LEAVES YOUR PHONE ONLY WHEN YOU CHOOSE TO EXPORT IT.',
          style: TextStyle(
            color: context.receipt.muted,
            fontSize: 10,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}
