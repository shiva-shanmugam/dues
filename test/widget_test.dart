import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/data/services/sms_inbox_service.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
import 'package:dues/presentation/providers/theme_mode_provider.dart';
import 'package:dues/presentation/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final subscription = Subscription(
    id: 'netflix',
    name: 'Netflix',
    amount: 649,
    cycle: BillingCycle.monthly,
    nextDueDate: DateTime.now().add(const Duration(days: 2)),
  );

  Widget app({ThemeData? theme, double textScale = 1}) => ProviderScope(
    overrides: [
      subscriptionsProvider.overrideWith((ref) => Stream.value([subscription])),
      smsInboxProvider.overrideWithValue(const _FakeSmsInboxService()),
      appPreferencesProvider.overrideWith(_Preferences.new),
      themeModeProvider.overrideWith(_ThemePreference.new),
      ignoredMerchantsProvider.overrideWith((ref) => Stream.value(<String>{})),
    ],
    child: MaterialApp(
      theme: theme ?? DuesTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const AppShell(),
    ),
  );

  testWidgets('dashboard renders persisted subscription summary', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('DUES'), findsOneWidget);
    expect(find.textContaining('STATEMENT'), findsOneWidget);
    expect(find.text('TOTAL/MO'), findsOneWidget);
    expect(find.text('NETFLIX'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('bottom navigation opens subscriptions and settings', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('SUBSCRIPTIONS'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('CONFIG'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('home empty state offers an SMS scan', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionsProvider.overrideWith(
            (ref) => Stream.value(const <Subscription>[]),
          ),
          smsInboxProvider.overrideWithValue(const _FakeSmsInboxService()),
          appPreferencesProvider.overrideWith(_Preferences.new),
          themeModeProvider.overrideWith(_ThemePreference.new),
          ignoredMerchantsProvider.overrideWith(
            (ref) => Stream.value(<String>{}),
          ),
        ],
        child: MaterialApp(theme: DuesTheme.light, home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NO SUBSCRIPTIONS FOUND'), findsOneWidget);
    expect(find.text('SCAN SMS'), findsOneWidget);
  });

  testWidgets('receipt screens fit a small display at 1.3x in both themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final theme in [DuesTheme.light, DuesTheme.dark]) {
      await tester.pumpWidget(app(theme: theme, textScale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('nav-2')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

class _FakeSmsInboxService extends SmsInboxService {
  const _FakeSmsInboxService();

  @override
  Future<bool> hasPermission() async => false;
}

class _Preferences extends AppPreferencesController {
  @override
  Future<AppPreferences> build() async =>
      const AppPreferences(hapticsEnabled: false);
}

class _ThemePreference extends ThemeModeController {
  @override
  Future<ThemeMode> build() async => ThemeMode.system;
}
