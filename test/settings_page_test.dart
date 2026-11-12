import 'dart:async';

import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/data/services/sms_inbox_service.dart';
import 'package:dues/data/services/notification_service.dart';
import 'package:dues/domain/models/transaction_record.dart';
import 'package:dues/domain/repositories/subscription_repository.dart';
import 'package:dues/presentation/pages/settings_page.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
import 'package:dues/presentation/providers/theme_mode_provider.dart';
import 'package:dues/presentation/providers/reminder_sync_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('currency, haptics and ignored merchant controls respond', (
    tester,
  ) async {
    final repository = _IgnoredRepository();
    final notifications = _Notifications();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWith(_MemoryPreferences.new),
        themeModeProvider.overrideWith(_MemoryThemeMode.new),
        repositoryProvider.overrideWithValue(repository),
        smsInboxProvider.overrideWithValue(const _FakeSmsService()),
        notificationServiceProvider.overrideWithValue(notifications),
        reminderSyncProvider.overrideWithValue(
          _Sync(repository, notifications),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.changes.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: DuesTheme.dark,
          home: const Scaffold(body: SettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final next in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
      await tester.tap(find.byKey(const ValueKey('theme-cycle')));
      await tester.pumpAndSettle();
      expect(container.read(themeModeProvider).value, next);
    }

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('RENEWAL ALERTS'));
      await tester.pumpAndSettle();
      expect(
        container.read(appPreferencesProvider).value!.renewalAlertsEnabled,
        isFalse,
      );
      await tester.tap(find.text('RENEWAL ALERTS'));
      await tester.pumpAndSettle();
      expect(
        container.read(appPreferencesProvider).value!.renewalAlertsEnabled,
        isTrue,
      );
    }

    await tester.tap(find.text('RENEWAL ALERTS'));
    await tester.pumpAndSettle();
    notifications.granted = false;
    await tester.tap(find.text('RENEWAL ALERTS'));
    await tester.pumpAndSettle();
    expect(find.text('NOTIFICATIONS BLOCKED'), findsOneWidget);
    await tester.tap(find.text('OPEN SETTINGS'));
    await tester.pumpAndSettle();
    expect(notifications.openedSettings, isTrue);
    expect(
      container.read(appPreferencesProvider).value!.renewalAlertsEnabled,
      isFalse,
    );
    notifications.granted = true;
    await tester.tap(find.text('RENEWAL ALERTS'));
    await tester.pumpAndSettle();
    expect(
      container.read(appPreferencesProvider).value!.renewalAlertsEnabled,
      isTrue,
    );

    await tester.ensureVisible(find.text('CURRENCY'));
    await tester.tap(find.text('CURRENCY'));
    await tester.pumpAndSettle();
    expect(find.text('HOME DISPLAY CURRENCY'), findsOneWidget);
    await tester.tap(find.text('US DOLLAR'));
    await tester.pumpAndSettle();
    expect(container.read(appPreferencesProvider).value!.currency, 'USD');
    expect(find.text('USD'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('haptic-row')));
    await tester.tap(find.byKey(const ValueKey('haptic-row')));
    await tester.pumpAndSettle();
    expect(
      container.read(appPreferencesProvider).value!.hapticsEnabled,
      isFalse,
    );

    await tester.ensureVisible(find.text('IGNORED MERCHANTS'));
    await tester.tap(find.text('IGNORED MERCHANTS'));
    await tester.pumpAndSettle();
    expect(find.text('NETFLIX'), findsOneWidget);
    await tester.tap(find.text('NETFLIX'));
    await tester.pumpAndSettle();
    expect(find.text('IGNORED DURING SMS SCANS'), findsOneWidget);
    expect(repository.restored, isNull);
    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RESTORE'));
    await tester.pumpAndSettle();
    expect(find.text('RESTORE MERCHANT?'), findsOneWidget);
    expect(repository.restored, isNull);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(repository.restored, isNull);
    await tester.tap(find.text('RESTORE'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'RESTORE').last);
    await tester.pumpAndSettle();
    expect(repository.restored, 'netflix');
    expect(find.text('No ignored merchants.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

class _MemoryThemeMode extends ThemeModeController {
  @override
  Future<ThemeMode> build() async => ThemeMode.system;

  @override
  Future<void> setMode(ThemeMode mode) async => state = AsyncData(mode);
}

class _MemoryPreferences extends AppPreferencesController {
  @override
  Future<AppPreferences> build() async => const AppPreferences();

  @override
  Future<void> setCurrency(String value) async {
    state = AsyncData(state.value!.copyWith(currency: value));
  }

  @override
  Future<void> setHapticsEnabled(bool value) async {
    state = AsyncData(state.value!.copyWith(hapticsEnabled: value));
  }

  @override
  Future<void> setRenewalAlertsEnabled(bool value) async {
    state = AsyncData(state.value!.copyWith(renewalAlertsEnabled: value));
  }
}

class _Notifications extends NotificationService {
  bool granted = true;
  bool openedSettings = false;
  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<void> openSettings() async {
    openedSettings = true;
  }
}

class _Sync extends ReminderSync {
  _Sync(SubscriptionRepository repository, NotificationService notifications)
    : super(repository, notifications, () async => const AppPreferences());
  @override
  Future<bool> sync() async => true;
}

class _FakeSmsService extends SmsInboxService {
  const _FakeSmsService();

  @override
  Future<bool> hasPermission() async => false;
}

class _IgnoredRepository implements SubscriptionRepository {
  final changes = StreamController<Set<String>>.broadcast();
  Set<String> merchants = {'netflix'};
  String? restored;

  @override
  Stream<Set<String>> watchIgnoredMerchants() async* {
    yield merchants;
    yield* changes.stream;
  }

  @override
  Future<void> unignoreMerchant(String merchant) async {
    restored = merchant;
    merchants = {...merchants}..remove(merchant);
    changes.add(merchants);
  }

  @override
  Future<List<TransactionRecord>> getRecentTransactionsForMerchant(
    String merchant, {
    int limit = 10,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
