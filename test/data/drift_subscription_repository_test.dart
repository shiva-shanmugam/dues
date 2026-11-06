import 'package:drift/native.dart';
import 'package:dues/data/database/app_database.dart' hide Subscription;
import 'package:dues/data/repositories/drift_subscription_repository.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/models/transaction_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftSubscriptionRepository repository;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = DriftSubscriptionRepository(database);
  });

  tearDown(() => database.close());

  test('persists and streams subscriptions', () async {
    final subscription = Subscription(
      id: 'netflix',
      name: 'Netflix',
      normalizedMerchant: 'Netflix',
      amount: 649,
      cycle: BillingCycle.monthly,
      nextDueDate: DateTime(2026, 12, 5),
    );

    await repository.saveSubscription(subscription);
    final saved = await repository.watchSubscriptions().first;

    expect(saved, hasLength(1));
    expect(saved.single.name, 'Netflix');
    expect(saved.single.amount, 649);
    expect(saved.single.nextDueDate, DateTime(2026, 12, 5));
  });

  test('updates pause state and deletes', () async {
    await repository.saveSubscription(
      Subscription(
        id: 'spotify',
        name: 'Spotify',
        amount: 119,
        cycle: BillingCycle.monthly,
        nextDueDate: DateTime(2026, 12, 8),
      ),
    );

    await repository.setPaused('spotify', paused: true);
    expect((await repository.getSubscriptions()).single.isPaused, isTrue);

    await repository.deleteSubscription('spotify');
    expect(await repository.getSubscriptions(), isEmpty);
  });

  test('stores ignored merchants case-normalized by caller', () async {
    await repository.ignoreMerchant('netflix');
    expect(await repository.getIgnoredMerchants(), {'netflix'});
  });

  test('returns only the latest ten matching merchant messages', () async {
    await repository.saveTransactions([
      for (var index = 0; index < 12; index++)
        TransactionRecord(
          id: 'netflix-$index',
          sender: 'HDFCBK',
          body: 'INR 649 debited at Netflix. Ref $index',
          merchant: 'Netflix',
          amount: 649,
          currency: 'INR',
          occurredAt: DateTime(2026, index + 1, 5),
          isDebit: true,
        ),
      TransactionRecord(
        id: 'other',
        sender: 'HDFCBK',
        body: 'INR 119 debited at Spotify',
        merchant: 'Spotify',
        amount: 119,
        currency: 'INR',
        occurredAt: DateTime(2026, 12, 8),
        isDebit: true,
      ),
    ]);

    final history = await repository.getRecentTransactionsForMerchant(
      ' netflix ',
    );
    expect(history, hasLength(10));
    expect(history.first.id, 'netflix-11');
    expect(history.last.id, 'netflix-2');
    expect(history.every((record) => record.merchant == 'Netflix'), isTrue);
    expect(history.first.sender, 'HDFCBK');
    expect(history.first.body, contains('Ref 11'));
  });

  test(
    'unignore re-enables a merchant and updates its settings stream',
    () async {
      await repository.ignoreMerchant(' Netflix ');
      expect(await repository.watchIgnoredMerchants().first, {'netflix'});

      await repository.unignoreMerchant('NETFLIX');
      expect(await repository.watchIgnoredMerchants().first, isEmpty);
    },
  );
}
