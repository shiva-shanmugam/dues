import 'package:drift/native.dart';
import 'package:dues/data/database/app_database.dart' hide Subscription;
import 'package:dues/data/repositories/drift_subscription_repository.dart';
import 'package:dues/domain/models/subscription.dart';
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
}
