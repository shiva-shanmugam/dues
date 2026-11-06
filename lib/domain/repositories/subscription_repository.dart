import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/models/transaction_record.dart';

abstract interface class SubscriptionRepository {
  Stream<List<Subscription>> watchSubscriptions();
  Future<List<Subscription>> getSubscriptions();
  Future<void> saveSubscription(Subscription subscription);
  Future<void> deleteSubscription(String id);
  Future<void> setPaused(String id, {required bool paused});
  Future<void> saveTransactions(Iterable<TransactionRecord> transactions);
  Future<List<TransactionRecord>> getTransactions();
  Future<List<TransactionRecord>> getRecentTransactionsForMerchant(
    String merchant, {
    int limit = 10,
  });
  Future<Set<String>> getIgnoredMerchants();
  Stream<Set<String>> watchIgnoredMerchants();
  Future<void> ignoreMerchant(String merchant);
  Future<void> unignoreMerchant(String merchant);
}
