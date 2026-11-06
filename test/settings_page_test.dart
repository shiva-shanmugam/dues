import 'dart:async';

import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/data/services/sms_inbox_service.dart';
import 'package:dues/domain/repositories/subscription_repository.dart';
import 'package:dues/presentation/pages/settings_page.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('currency, haptics and ignored merchant controls respond', (
    tester,
  ) async {
    final repository = _IgnoredRepository();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWith(_MemoryPreferences.new),
        repositoryProvider.overrideWithValue(repository),
        smsInboxProvider.overrideWithValue(const _FakeSmsService()),
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

    await tester.ensureVisible(find.text('CURRENCY'));
    await tester.tap(find.text('CURRENCY'));
    await tester.pumpAndSettle();
    expect(find.text('DEFAULT CURRENCY'), findsOneWidget);
    await tester.tap(find.text('US dollar (USD)'));
    await tester.pumpAndSettle();
    expect(container.read(appPreferencesProvider).value!.currency, 'USD');
    expect(find.text('US dollar (USD) · totals & new entries'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('haptic-switch')));
    await tester.tap(find.byKey(const ValueKey('haptic-switch')));
    await tester.pumpAndSettle();
    expect(
      container.read(appPreferencesProvider).value!.hapticsEnabled,
      isFalse,
    );

    await tester.ensureVisible(find.text('IGNORED MERCHANTS'));
    await tester.tap(find.text('IGNORED MERCHANTS'));
    await tester.pumpAndSettle();
    expect(find.text('netflix'), findsOneWidget);
    await tester.tap(find.text('RESTORE'));
    await tester.pumpAndSettle();
    expect(repository.restored, 'netflix');
    expect(find.text('No ignored merchants.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
