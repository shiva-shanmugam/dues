import 'package:dues/core/theme/app_theme.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/models/transaction_record.dart';
import 'package:dues/domain/repositories/subscription_repository.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/widgets/subscription_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Subscription subscription({String? merchant}) => Subscription(
    id: 'netflix',
    name: 'Netflix',
    normalizedMerchant: merchant,
    amount: 649,
    cycle: BillingCycle.monthly,
    nextDueDate: DateTime(2026, 12, 5),
    isAutoDetected: false,
  );

  Widget app(Subscription item, SubscriptionRepository repository) =>
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: DuesTheme.dark,
          home: Scaffold(body: SubscriptionDetailSheet(subscription: item)),
        ),
      );

  testWidgets('shows original message text for an edited SMS subscription', (
    tester,
  ) async {
    final repository = _HistoryRepository([
      TransactionRecord(
        id: '12',
        sender: 'VM-HDFCBK',
        body: 'INR 649 debited at NETFLIX.COM on 05-11-26. Ref 42.',
        merchant: 'Netflix',
        amount: 649,
        currency: 'INR',
        occurredAt: DateTime(2026, 11, 5, 9, 30),
        isDebit: true,
      ),
    ]);
    await tester.pumpWidget(app(subscription(merchant: 'Netflix'), repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('SOURCE SMS'), findsOneWidget);
    expect(find.textContaining('VM-HDFCBK'), findsOneWidget);
    expect(
      find.text('INR 649 debited at NETFLIX.COM on 05-11-26. Ref 42.'),
      findsOneWidget,
    );
    expect(repository.lastMerchant, 'Netflix');
  });

  testWidgets('explains manual subscription has no linked history', (
    tester,
  ) async {
    final repository = _HistoryRepository(const []);
    await tester.pumpWidget(app(subscription(), repository));
    await tester.pumpAndSettle();

    expect(
      find.text('Added manually. This subscription has no linked SMS history.'),
      findsOneWidget,
    );
    expect(repository.lastMerchant, isNull);
  });

  testWidgets(
    'SMS history scrolls while heading and actions remain fixed at 1.3x',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _HistoryRepository(
        List.generate(
          10,
          (index) => TransactionRecord(
            id: '$index',
            sender: 'VM-HDFCBK',
            body:
                'Payment $index: INR 649 debited to NETFLIX.COM. Your autopay renewal was processed successfully. Ref $index.',
            merchant: 'Netflix',
            amount: 649,
            currency: 'INR',
            occurredAt: DateTime(2026, 11, 5),
            isDebit: true,
          ),
        ),
      );
      for (final theme in [DuesTheme.light, DuesTheme.dark]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWithValue(repository)],
            child: MaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: Scaffold(
                body: SubscriptionDetailSheet(
                  subscription: subscription(merchant: 'Netflix'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final fixed = [
          '< ALL SUBSCRIPTIONS',
          'NETFLIX',
          'CHARGE HISTORY',
          'PAUSE REMINDERS',
          'NOT A SUBSCRIPTION',
        ];
        final positions = {
          for (final label in fixed) label: tester.getTopLeft(find.text(label)),
        };
        expect(
          tester.getRect(find.text('₹649.00').first).right,
          closeTo(340, .01),
        );
        await tester.drag(
          find.byKey(const ValueKey('sms-history-scroll')),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        for (final label in fixed) {
          expect(tester.getTopLeft(find.text(label)), positions[label]);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}

class _HistoryRepository implements SubscriptionRepository {
  _HistoryRepository(this.records);
  final List<TransactionRecord> records;
  String? lastMerchant;

  @override
  Future<List<TransactionRecord>> getRecentTransactionsForMerchant(
    String merchant, {
    int limit = 10,
  }) async {
    lastMerchant = merchant;
    return records;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
