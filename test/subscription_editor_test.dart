import 'dart:async';

import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/data/services/notification_service.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/repositories/subscription_repository.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
import 'package:dues/presentation/providers/reminder_sync_provider.dart';
import 'package:dues/presentation/widgets/subscription_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final existing = Subscription(
    id: 'netflix',
    name: 'Netflix',
    amount: 149.50,
    normalizedMerchant: 'Netflix',
    cycle: BillingCycle.monthly,
    nextDueDate: DateTime(2027, 1, 5),
  );

  Future<void> openEditor(
    WidgetTester tester,
    _Repository repository,
    _ReminderSync sync, {
    Subscription? subscription,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repository),
          appPreferencesProvider.overrideWith(_Preferences.new),
          reminderSyncProvider.overrideWithValue(sync),
        ],
        child: MaterialApp(
          theme: DuesTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showSubscriptionEditor(context, subscription: subscription),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'update closes immediately after save even while reminders wait',
    (tester) async {
      final repository = _Repository();
      final sync = _ReminderSync(repository);
      await openEditor(tester, repository, sync, subscription: existing);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('subscription-amount')),
            )
            .controller!
            .text,
        '149.5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('subscription-amount')),
        '199.75',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('save-subscription')),
      );
      await tester.tap(find.byKey(const ValueKey('save-subscription')));
      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionEditorSheet), findsNothing);
      expect(repository.saved!.amount, 199.75);
      expect(repository.saved!.normalizedMerchant, 'Netflix');
      expect(repository.saved!.isAutoDetected, isFalse);
      sync.result.complete(false);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Subscription saved. Reminders'),
        findsOneWidget,
      );
    },
  );

  testWidgets('database failure restores UPDATE and allows a retry', (
    tester,
  ) async {
    final repository = _Repository()..fail = true;
    final sync = _ReminderSync(repository);
    await openEditor(tester, repository, sync, subscription: existing);
    await tester.ensureVisible(find.byKey(const ValueKey('save-subscription')));
    await tester.tap(find.byKey(const ValueKey('save-subscription')));
    await tester.pumpAndSettle();
    expect(find.text('UPDATE'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Could not save'), findsOneWidget);
    repository.fail = false;
    sync.result.complete(true);
    await tester.tap(find.byKey(const ValueKey('save-subscription')));
    await tester.pumpAndSettle();
    expect(repository.saved!.amount, 149.5);
    expect(find.byType(SubscriptionEditorSheet), findsNothing);
  });

  testWidgets('manual and autopay editors both dismiss with a downward drag', (
    tester,
  ) async {
    for (final automatic in [false, true]) {
      final repository = _Repository();
      final sync = _ReminderSync(repository);
      await openEditor(
        tester,
        repository,
        sync,
        subscription: existing.copyWith(isAutoDetected: automatic),
      );
      await tester.drag(find.text('EDIT SUBSCRIPTION'), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionEditorSheet), findsNothing);
      expect(repository.saved, isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('popular plan fills price and cycle and accepts a manual price', (
    tester,
  ) async {
    final repository = _Repository();
    final sync = _ReminderSync(repository)..result.complete(true);
    await openEditor(tester, repository, sync);
    await tester.tap(find.widgetWithText(OutlinedButton, 'AMAZON PRIME'));
    await tester.pumpAndSettle();
    final annual = find.text('PRIME ANNUAL');
    await tester.ensureVisible(annual);
    await tester.tap(annual);
    await tester.pumpAndSettle();
    final amount = find.byKey(const ValueKey('subscription-amount'));
    expect(tester.widget<TextField>(amount).controller!.text, '1499');
    expect(find.textContaining('YEARLY'), findsOneWidget);
    await tester.ensureVisible(amount);
    await tester.enterText(amount, '1299');
    await tester.ensureVisible(find.byKey(const ValueKey('save-subscription')));
    await tester.tap(find.byKey(const ValueKey('save-subscription')));
    await tester.pumpAndSettle();
    expect(repository.saved!.amount, 1299);
    expect(repository.saved!.cycle, BillingCycle.yearly);
    expect(repository.saved!.currency, 'INR');
  });
}

class _Repository implements SubscriptionRepository {
  Subscription? saved;
  bool fail = false;

  @override
  Future<void> saveSubscription(Subscription subscription) async {
    if (fail) throw StateError('disk error');
    saved = subscription;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReminderSync extends ReminderSync {
  _ReminderSync(_Repository repository)
    : super(
        repository,
        NotificationService(),
        () async => const AppPreferences(),
      );
  final result = Completer<bool>();
  @override
  Future<bool> sync() => result.future;
}

class _Preferences extends AppPreferencesController {
  @override
  Future<AppPreferences> build() async =>
      const AppPreferences(hapticsEnabled: false);
}
