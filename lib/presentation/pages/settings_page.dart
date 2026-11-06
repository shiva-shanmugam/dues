import 'dart:io';

import 'package:csv/csv.dart';
import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/core/utils/formatters.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/widgets/dues_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool renewalAlerts = true;
  bool smsGranted = false;
  bool scanning = false;

  @override
  void initState() {
    super.initState();
    _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final granted = await ref.read(smsInboxProvider).hasPermission();
    if (mounted) setState(() => smsGranted = granted);
  }

  @override
  Widget build(BuildContext context) {
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
              Text(
                'DATA & PERMISSIONS',
                style: Theme.of(context).textTheme.label
                    .copyWith(color: DuesColors.offWhite),
              ),
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
                      trailing: _StatusDot(active: smsGranted),
                      onTap: scanning ? null : _scanSms,
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.notifications_none,
                      title: 'RENEWAL ALERTS',
                      subtitle: '3 days and 1 day before',
                      trailing: Switch(
                        value: renewalAlerts,
                        activeThumbColor: DuesColors.offWhite,
                        activeTrackColor: DuesColors.red,
                        onChanged: (value) async {
                          HapticFeedback.selectionClick();
                          if (value) {
                            final granted = await ref
                                .read(notificationServiceProvider)
                                .requestPermission();
                            if (!granted) return;
                            await ref
                                .read(notificationServiceProvider)
                                .scheduleRenewals(
                                  await ref
                                      .read(repositoryProvider)
                                      .getSubscriptions(),
                                );
                          }
                          setState(() => renewalAlerts = value);
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.file_download_outlined,
                      title: 'EXPORT CSV',
                      subtitle: 'Save a local copy',
                      onTap: _exportCsv,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'PREFERENCES',
                style: Theme.of(context).textTheme.label
                    .copyWith(color: DuesColors.offWhite),
              ),
              const SizedBox(height: 12),
              DuesCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    const _SettingRow(
                      icon: Icons.currency_rupee,
                      title: 'CURRENCY',
                      subtitle: 'Indian rupee (INR)',
                      trailing: Icon(
                        Icons.chevron_right,
                        color: DuesColors.muted,
                      ),
                    ),
                    const Divider(height: 1),
                    const _SettingRow(
                      icon: Icons.vibration,
                      title: 'HAPTIC TICKS',
                      subtitle: 'On',
                      trailing: Icon(
                        Icons.chevron_right,
                        color: DuesColors.muted,
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      icon: Icons.block_outlined,
                      title: 'IGNORED MERCHANTS',
                      subtitle: 'No merchants ignored',
                      onTap: () => _preview(
                        context,
                        'Your ignored merchant rules will live here.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Center(
                child: Text(
                  'DUES / UI PREVIEW 0.1.0',
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

  void _preview(BuildContext context, String message) {
    HapticFeedback.selectionClick();
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

  Future<void> _scanSms() async {
    HapticFeedback.mediumImpact();
    setState(() => scanning = true);
    try {
      var granted = await ref.read(smsInboxProvider).hasPermission();
      if (!granted) {
        granted = await ref.read(smsInboxProvider).requestPermission();
      }
      if (!granted) {
        if (mounted) {
          _preview(
            context,
            'SMS access was not granted. You can still add subscriptions manually.',
          );
        }
        return;
      }
      final result = await ref.read(smsImportServiceProvider).import();
      await ref
          .read(notificationServiceProvider)
          .scheduleRenewals(
            await ref.read(repositoryProvider).getSubscriptions(),
          );
      if (mounted) {
        _preview(
          context,
          'Scanned ${result.messagesRead} messages · found ${result.subscriptionsFound} subscriptions.',
        );
      }
      smsGranted = true;
    } on PlatformException catch (error) {
      if (mounted) {
        _preview(context, error.message ?? 'Could not read SMS messages.');
      }
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> _exportCsv() async {
    final subscriptions = await ref.read(repositoryProvider).getSubscriptions();
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
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();
  @override
  Widget build(BuildContext context) => DuesCard(
    color: DuesColors.surfaceRaised,
    child: const Row(
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
                'No account. No cloud. No analytics. Your messages and subscription data never leave your phone.',
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

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: active ? DuesColors.offWhite : DuesColors.red,
    ),
  );
}
