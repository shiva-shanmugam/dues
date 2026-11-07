import 'dart:async';

import 'package:drift/native.dart';
import 'package:dues/data/database/app_database.dart';
import 'package:dues/data/repositories/drift_subscription_repository.dart';
import 'package:dues/data/services/notification_service.dart';
import 'package:dues/domain/models/subscription.dart' as domain;
import 'package:dues/domain/repositories/subscription_repository.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
import 'package:dues/presentation/providers/reminder_sync_provider.dart';
import 'package:dues/presentation/providers/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'currency, haptics and reminder choices survive provider reload',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      final initial = await container.read(appPreferencesProvider.future);
      expect(initial.currency, 'INR');
      expect(initial.hapticsEnabled, isTrue);
      expect(initial.renewalAlertsEnabled, isTrue);

      final controller = container.read(appPreferencesProvider.notifier);
      await controller.setCurrency('USD');
      await controller.setHapticsEnabled(false);
      await controller.setRenewalAlertsEnabled(false);
      container.invalidate(appPreferencesProvider);
      final restored = await container.read(appPreferencesProvider.future);
      expect(restored.currency, 'USD');
      expect(restored.hapticsEnabled, isFalse);
      expect(restored.renewalAlertsEnabled, isFalse);
    },
  );

  test('theme mode defaults to system and survives provider reload', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    expect(await container.read(themeModeProvider.future), ThemeMode.system);
    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    container.invalidate(themeModeProvider);
    expect(await container.read(themeModeProvider.future), ThemeMode.dark);
  });

  test('disabled haptics never invokes platform feedback', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await const AppHaptics(false).selectionClick();
    await const AppHaptics(false).mediumImpact();
    expect(calls, isEmpty);
    await const AppHaptics(true).selectionClick();
    expect(calls.single.method, 'HapticFeedback.vibrate');
  });

  test(
    'disabled reminders cancel alarms and scheduling errors are reported',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final notifications = _FakeNotifications();
      final repository = DriftSubscriptionRepository(database);
      final disabled = ReminderSync(
        repository,
        notifications,
        () async => const AppPreferences(renewalAlertsEnabled: false),
      );
      expect(await disabled.sync(), isTrue);
      expect(notifications.cancelled, isTrue);
      expect(notifications.scheduled, isFalse);

      notifications.fail = true;
      final enabled = ReminderSync(
        repository,
        notifications,
        () async => const AppPreferences(),
      );
      expect(await enabled.sync(), isFalse);
    },
  );

  test(
    'a delayed old sync cannot re-enable reminders after disabling',
    () async {
      final subscriptions = Completer<List<domain.Subscription>>();
      final repository = _DelayedRepository(subscriptions.future);
      final notifications = _FakeNotifications();
      var preferences = const AppPreferences();
      final sync = ReminderSync(
        repository,
        notifications,
        () async => preferences,
      );

      final oldSync = sync.sync();
      await repository.requested.future;
      preferences = const AppPreferences(renewalAlertsEnabled: false);
      expect(await sync.sync(), isTrue);
      subscriptions.complete([]);
      expect(await oldSync, isTrue);
      expect(notifications.cancelled, isTrue);
      expect(notifications.scheduled, isFalse);
    },
  );
}

class _DelayedRepository implements SubscriptionRepository {
  _DelayedRepository(this.subscriptions);
  final Future<List<domain.Subscription>> subscriptions;
  final requested = Completer<void>();

  @override
  Future<List<domain.Subscription>> getSubscriptions() {
    requested.complete();
    return subscriptions;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotifications extends NotificationService {
  bool cancelled = false;
  bool scheduled = false;
  bool fail = false;

  @override
  Future<void> cancelRenewals() async => cancelled = true;

  @override
  Future<void> scheduleRenewals(
    Iterable<domain.Subscription> subscriptions,
  ) async {
    scheduled = true;
    if (fail) throw StateError('notification scheduling failed');
  }
}
