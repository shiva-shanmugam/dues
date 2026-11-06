import 'dart:io';

import 'package:csv/csv.dart';
import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/core/utils/formatters.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
import 'package:dues/presentation/providers/reminder_sync_provider.dart';
import 'package:dues/presentation/widgets/dues_card.dart';
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
      // SMS support is Android-only; manual tracking still works elsewhere.
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(appPreferencesProvider);
    final current = preferences.value;
    final ignored = ref.watch(ignoredMerchantsProvider);
    return CustomScrollView(
      key: const PageStorageKey('settings-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
          sliver: SliverList.list(
            children: [
              Text('SETTINGS', style: Theme.of(context).textTheme.dotTitle),
              const SizedBox(height: 6),
              Text(
                'PRIVATE BY DESIGN',
                style: Theme.of(context).textTheme.label,
              ),
              const SizedBox(height: 28),
              const _PrivacyCard(),
              const SizedBox(height: 28),
              _sectionLabel(context, 'DATA & PERMISSIONS'),
              const SizedBox(height: 12),
              DuesCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingRow(
                      icon: Icons.sms_outlined,
                      title: 'SMS ACCESS',
                      subtitle: scanning
                          ? 'Scanning messages…'
                          : (smsGranted
                                ? 'Connected · tap to rescan'
                                : 'Not connected · tap to allow'),
                      trailing: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: smsGranted
                              ? DuesColors.offWhite
                              : DuesColors.red,
                        ),
                      ),
                      onTap: scanning ? null : _scanSms,
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.notifications_none,
                      title: 'RENEWAL ALERTS',
                      subtitle: changingAlerts
                          ? 'Updating reminders…'
                          : '3 days and 1 day before',
                      onTap: current == null || changingAlerts
                          ? null
                          : () => _setAlerts(!current.renewalAlertsEnabled),
                      trailing: Switch(
                        value: current?.renewalAlertsEnabled ?? false,
                        activeThumbColor: DuesColors.offWhite,
                        activeTrackColor: DuesColors.red,
                        onChanged: current == null || changingAlerts
                            ? null
                            : _setAlerts,
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.file_download_outlined,
                      title: 'EXPORT CSV',
                      subtitle: 'Save or share a local copy',
                      onTap: _exportCsv,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _sectionLabel(context, 'PREFERENCES'),
              const SizedBox(height: 12),
              if (preferences.hasError) ...[
                TextButton(
                  onPressed: () => ref.invalidate(appPreferencesProvider),
                  child: const Text(
                    'Could not load preferences. Tap to retry.',
                  ),
                ),
              ],
              DuesCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingRow(
                      icon: Icons.currency_exchange,
                      title: 'CURRENCY',
                      subtitle: current == null
                          ? 'Loading…'
                          : '${_currencyNames[current.currency] ?? current.currency} · totals & new entries',
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: DuesColors.muted,
                      ),
                      onTap: current == null ? null : _chooseCurrency,
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.vibration,
                      title: 'HAPTIC TICKS',
                      subtitle: current?.hapticsEnabled == true ? 'On' : 'Off',
                      onTap: current == null
                          ? null
                          : () => _setHaptics(!current.hapticsEnabled),
                      trailing: Switch(
                        key: const ValueKey('haptic-switch'),
                        value: current?.hapticsEnabled ?? false,
                        activeThumbColor: DuesColors.offWhite,
                        activeTrackColor: DuesColors.red,
                        onChanged: current == null ? null : _setHaptics,
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.block_outlined,
                      title: 'IGNORED MERCHANTS',
                      subtitle: ignored.when(
                        data: (merchants) => merchants.isEmpty
                            ? 'No merchants ignored'
                            : '${merchants.length} ignored · tap to manage',
                        loading: () => 'Loading…',
                        error: (_, _) => 'Tap to retry',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: DuesColors.muted,
                      ),
                      onTap: _showIgnoredMerchants,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Center(
                child: Text(
                  'DUES / LOCAL FIRST',
                  style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 1,
                    color: DuesColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Text(
    text,
    style: Theme.of(context).textTheme.label
        .copyWith(color: DuesColors.offWhite),
  );

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 11)),
        backgroundColor: DuesColors.surfaceRaised,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: DuesColors.outline),
        ),
      ),
    );
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
          _message(
            'Allow notifications in Android settings to enable renewal alerts.',
          );
          return;
        }
      }
      await ref
          .read(appPreferencesProvider.notifier)
          .setRenewalAlertsEnabled(enabled);
      final synced = await ref.read(reminderSyncProvider).sync();
      if (!synced) {
        _message(
          'Preference saved. Reminder scheduling will retry in the background.',
        );
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

  static const _currencyNames = {
    'INR': 'Indian rupee (INR)',
    'USD': 'US dollar (USD)',
    'EUR': 'Euro (EUR)',
    'GBP': 'British pound (GBP)',
  };

  Future<void> _chooseCurrency() async {
    ref.read(hapticsProvider).selectionClick();
    final current = ref.read(appPreferencesProvider).value?.currency ?? 'INR';
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DuesColors.surfaceRaised,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEFAULT CURRENCY',
                      style: Theme.of(context).textTheme.dotTitle
                          .copyWith(fontSize: 26),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Used for new manual subscriptions and to choose the currency shown in dashboard totals. Existing charges keep their original currency; no exchange conversion is applied.',
                      style: TextStyle(
                        color: DuesColors.muted,
                        fontSize: 11,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              for (final entry in _currencyNames.entries)
                ListTile(
                  title: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: current == entry.key
                      ? const Icon(Icons.check, color: DuesColors.red)
                      : null,
                  onTap: () => Navigator.pop(context, entry.key),
                ),
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
      backgroundColor: DuesColors.surfaceRaised,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _IgnoredMerchantsSheet(),
    );
  }

  Future<void> _scanSms() async {
    ref.read(hapticsProvider).mediumImpact();
    setState(() => scanning = true);
    try {
      var granted = await ref.read(smsInboxProvider).hasPermission();
      if (!granted) {
        granted = await ref.read(smsInboxProvider).requestPermission();
      }
      if (!granted) {
        _message(
          'SMS access was not granted. You can still add subscriptions manually.',
        );
        return;
      }
      final result = await ref.read(smsImportServiceProvider).import();
      final synced = await ref.read(reminderSyncProvider).sync();
      if (mounted) setState(() => smsGranted = true);
      _message(
        'Scanned ${result.messagesRead} messages · found ${result.subscriptionsFound} subscriptions.${synced ? '' : ' Reminder scheduling will retry.'}',
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
          text:
              'Local Dues subscription export · ${formatShortDate(DateTime.now())}',
          files: [XFile(file.path, mimeType: 'text/csv')],
        ),
      );
    } catch (_) {
      _message('Could not export subscriptions. Please try again.');
    }
  }
}

class _IgnoredMerchantsSheet extends ConsumerWidget {
  const _IgnoredMerchantsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IGNORED MERCHANTS',
              style: Theme.of(context).textTheme.dotTitle
                  .copyWith(fontSize: 25),
            ),
            const SizedBox(height: 10),
            const Text(
              'These merchants are skipped during SMS scans. Restore one to allow detection on your next scan.',
              style: TextStyle(
                fontSize: 11,
                height: 1.6,
                color: DuesColors.muted,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ref
                  .watch(ignoredMerchantsProvider)
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Center(
                      child: TextButton(
                        onPressed: () =>
                            ref.invalidate(ignoredMerchantsProvider),
                        child: const Text('Could not load merchants. Retry'),
                      ),
                    ),
                    data: (merchants) {
                      if (merchants.isEmpty) {
                        return const Center(
                          child: Text(
                            'No ignored merchants.',
                            style: TextStyle(color: DuesColors.muted),
                          ),
                        );
                      }
                      final sorted = merchants.toList()..sort();
                      return ListView.separated(
                        itemCount: sorted.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            sorted[index],
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              ref.read(hapticsProvider).selectionClick();
                              try {
                                await ref
                                    .read(repositoryProvider)
                                    .unignoreMerchant(sorted[index]);
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Could not restore merchant. Please try again.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text(
                              'RESTORE',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
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
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();
  @override
  Widget build(BuildContext context) => const DuesCard(
    color: DuesColors.surfaceRaised,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline, color: DuesColors.red, size: 22),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STAYS ON THIS DEVICE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: .4,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'No account. No cloud. No analytics. Your messages and subscription data stay on your phone unless you choose to export them.',
                style: TextStyle(
                  color: DuesColors.muted,
                  height: 1.6,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 19, color: DuesColors.muted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: .4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 9, color: DuesColors.muted),
                ),
              ],
            ),
          ),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    ),
  );
}
