import 'package:drift/drift.dart';
import 'package:dues/data/database/app_database.dart';
import 'package:dues/domain/models/subscription.dart' as domain;
import 'package:dues/domain/models/transaction_record.dart' as domain;
import 'package:dues/domain/repositories/subscription_repository.dart';

class DriftSubscriptionRepository implements SubscriptionRepository {
  DriftSubscriptionRepository(this.database);

  final AppDatabase database;

  @override
  Stream<List<domain.Subscription>> watchSubscriptions() {
    final query = database.select(database.subscriptions)
      ..orderBy([(row) => OrderingTerm.asc(row.nextDueDate)]);
    return query.watch().map((rows) => rows.map(_subscriptionFromRow).toList());
  }

  @override
  Future<List<domain.Subscription>> getSubscriptions() async {
    final rows = await (database.select(
      database.subscriptions,
    )..orderBy([(row) => OrderingTerm.asc(row.nextDueDate)])).get();
    return rows.map(_subscriptionFromRow).toList();
  }

  @override
  Future<void> saveSubscription(domain.Subscription subscription) {
    return database
        .into(database.subscriptions)
        .insertOnConflictUpdate(
          SubscriptionsCompanion.insert(
            id: subscription.id,
            name: subscription.name,
            normalizedMerchant: Value(subscription.normalizedMerchant),
            amount: subscription.amount,
            currency: Value(subscription.currency),
            cycle: subscription.cycle.name,
            nextDueDate: subscription.nextDueDate,
            isPaused: Value(subscription.isPaused),
            isAutoDetected: Value(subscription.isAutoDetected),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> deleteSubscription(String id) async {
    await (database.delete(
      database.subscriptions,
    )..where((row) => row.id.equals(id))).go();
  }

  @override
  Future<void> setPaused(String id, {required bool paused}) async {
    await (database.update(
      database.subscriptions,
    )..where((row) => row.id.equals(id))).write(
      SubscriptionsCompanion(
        isPaused: Value(paused),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> saveTransactions(
    Iterable<domain.TransactionRecord> transactions,
  ) {
    return database.batch((batch) {
      batch.insertAllOnConflictUpdate(
        database.transactions,
        transactions.map(
          (record) => TransactionsCompanion.insert(
            id: record.id,
            sender: record.sender,
            body: record.body,
            merchant: record.merchant,
            amount: record.amount,
            currency: Value(record.currency),
            occurredAt: record.occurredAt,
            isDebit: record.isDebit,
            signal: Value(record.signal),
          ),
        ),
      );
    });
  }

  @override
  Future<List<domain.TransactionRecord>> getTransactions() async {
    final rows = await (database.select(
      database.transactions,
    )..orderBy([(row) => OrderingTerm.asc(row.occurredAt)])).get();
    return rows.map(_transactionFromRow).toList();
  }

  @override
  Future<List<domain.TransactionRecord>> getRecentTransactionsForMerchant(
    String merchant, {
    int limit = 10,
  }) async {
    final query = database.select(database.transactions)
      ..where(
        (row) => row.merchant.lower().equals(merchant.trim().toLowerCase()),
      )
      ..orderBy([
        (row) => OrderingTerm.desc(row.occurredAt),
        (row) => OrderingTerm.desc(row.id),
      ])
      ..limit(limit.clamp(1, 10));
    return (await query.get()).map(_transactionFromRow).toList();
  }

  domain.TransactionRecord _transactionFromRow(Transaction row) {
    return domain.TransactionRecord(
      id: row.id,
      sender: row.sender,
      body: row.body,
      merchant: row.merchant,
      amount: row.amount,
      currency: row.currency,
      occurredAt: row.occurredAt,
      isDebit: row.isDebit,
      signal: row.signal,
    );
  }

  @override
  Future<Set<String>> getIgnoredMerchants() async {
    final rows = await database.select(database.ignoredMerchants).get();
    return rows.map((row) => row.merchant).toSet();
  }

  @override
  Stream<Set<String>> watchIgnoredMerchants() {
    return database
        .select(database.ignoredMerchants)
        .watch()
        .map((rows) => rows.map((row) => row.merchant).toSet());
  }

  @override
  Future<void> ignoreMerchant(String merchant) {
    return database
        .into(database.ignoredMerchants)
        .insertOnConflictUpdate(
          IgnoredMerchantsCompanion.insert(
            merchant: merchant.trim().toLowerCase(),
          ),
        );
  }

  @override
  Future<void> unignoreMerchant(String merchant) async {
    await (database.delete(database.ignoredMerchants)..where(
          (row) => row.merchant.lower().equals(merchant.trim().toLowerCase()),
        ))
        .go();
  }

  domain.Subscription _subscriptionFromRow(Subscription row) {
    return domain.Subscription(
      id: row.id,
      name: row.name,
      normalizedMerchant: row.normalizedMerchant,
      amount: row.amount,
      currency: row.currency,
      cycle: domain.BillingCycle.values.byName(row.cycle),
      nextDueDate: row.nextDueDate,
      isPaused: row.isPaused,
      isAutoDetected: row.isAutoDetected,
    );
  }
}
