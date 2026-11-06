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
  Future<Set<String>> getIgnoredMerchants();
  Future<void> ignoreMerchant(String merchant);
}
