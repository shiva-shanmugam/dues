import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/data/services/sms_inbox_service.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
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

  Widget app() => ProviderScope(
    overrides: [
      subscriptionsProvider.overrideWith((ref) => Stream.value([subscription])),
      smsInboxProvider.overrideWithValue(const _FakeSmsInboxService()),
      appPreferencesProvider.overrideWith(_Preferences.new),
      ignoredMerchantsProvider.overrideWith((ref) => Stream.value(<String>{})),
    ],
    child: MaterialApp(theme: DuesTheme.dark, home: const AppShell()),
  );

  testWidgets('dashboard renders persisted subscription summary', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('DUES'), findsOneWidget);
    expect(find.text('1 ACTIVE SUBSCRIPTIONS'), findsOneWidget);
    expect(find.text('MONTHLY OUTGO'), findsOneWidget);
    expect(find.text('Netflix'), findsWidgets);

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
    expect(find.text('1 TRACKED LOCALLY'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE BY DESIGN'), findsOneWidget);
    expect(find.text('STAYS ON THIS DEVICE'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
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
