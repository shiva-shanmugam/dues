import 'package:dues/data/database/app_database.dart' hide Subscription;
import 'package:dues/data/repositories/drift_subscription_repository.dart';
import 'package:dues/data/services/local_settings_service.dart';
import 'package:dues/data/services/notification_service.dart';
import 'package:dues/data/services/sms_inbox_service.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/models/transaction_record.dart';
import 'package:dues/domain/repositories/subscription_repository.dart';
import 'package:dues/domain/services/sms_import_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final clockProvider = Provider<DateTime>((ref) => DateTime.now());

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final repositoryProvider = Provider<SubscriptionRepository>((ref) {
  return DriftSubscriptionRepository(ref.watch(databaseProvider));
});

final localSettingsProvider = Provider(
  (ref) => LocalSettingsService(ref.watch(databaseProvider)),
);
final smsInboxProvider = Provider((ref) => const SmsInboxService());
final notificationServiceProvider = Provider((ref) => NotificationService());
final smsImportServiceProvider = Provider(
  (ref) => SmsImportService(
    inbox: ref.watch(smsInboxProvider),
    repository: ref.watch(repositoryProvider),
  ),
);

final subscriptionsProvider = StreamProvider<List<Subscription>>((ref) {
  return ref.watch(repositoryProvider).watchSubscriptions();
});

final transactionsProvider = FutureProvider<List<TransactionRecord>>((ref) {
  return ref.watch(repositoryProvider).getTransactions();
});

class SelectedTabController extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final selectedTabProvider = NotifierProvider<SelectedTabController, int>(
  SelectedTabController.new,
);
