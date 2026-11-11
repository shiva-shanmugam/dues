import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/data/services/sms_inbox_service.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/models/review_candidate.dart';
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
      transactionsProvider.overrideWith((ref) async => const []),
      reviewCandidatesProvider.overrideWith((ref) => Stream.value(const [])),
      changeEventsProvider.overrideWith((ref) => Stream.value(const [])),
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
    await tester.tap(find.text('NETFLIX'));
    await tester.pumpAndSettle();
    expect(find.text('CHARGE HISTORY'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('compact header button opens floating calendar', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-calendar-button')), findsOneWidget);
    expect(find.text('COMMITMENT CALENDAR'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('home-calendar-button')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('COMMITMENT CALENDAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home scroll reaches monthly change receipt', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('WHAT CHANGED?'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('WHAT CHANGED?'), findsOneWidget);
    expect(find.text('NO RECORDED CHANGES THIS MONTH.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review inbox opens a classification receipt', (tester) async {
    final candidate = ReviewCandidate(
      id: 'review:rent:monthly',
      merchant: 'Landlord',
      amount: 18000,
      currency: 'INR',
      cycle: BillingCycle.monthly,
      nextDueDate: DateTime.now().add(const Duration(days: 12)),
      occurrences: 3,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionsProvider.overrideWith(
            (ref) => Stream.value([subscription]),
          ),
          reviewCandidatesProvider.overrideWith(
            (ref) => Stream.value([candidate]),
          ),
          changeEventsProvider.overrideWith((ref) => Stream.value(const [])),
          smsInboxProvider.overrideWithValue(const _FakeSmsInboxService()),
          appPreferencesProvider.overrideWith(_Preferences.new),
          themeModeProvider.overrideWith(_ThemePreference.new),
          ignoredMerchantsProvider.overrideWith(
            (ref) => Stream.value(<String>{}),
          ),
        ],
        child: MaterialApp(theme: DuesTheme.dark, home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('REVIEW INBOX'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('LANDLORD'));
    await tester.pumpAndSettle();

    expect(find.text('REPEATING PAYMENT?'), findsOneWidget);
    expect(find.text('PERSON / BUSINESS'), findsOneWidget);
    expect(find.text('TRACK THIS'), findsOneWidget);
    expect(find.text('NOT RECURRING'), findsOneWidget);
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
          transactionsProvider.overrideWith((ref) async => const []),
          reviewCandidatesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          changeEventsProvider.overrideWith((ref) => Stream.value(const [])),
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

      await tester.tap(find.byKey(const ValueKey('nav-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-calendar-button')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('×'));
      await tester.pumpAndSettle();

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
