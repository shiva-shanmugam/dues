import 'package:drift/native.dart';
import 'package:dues/data/database/app_database.dart' hide Subscription;
import 'package:dues/data/repositories/drift_subscription_repository.dart';
import 'package:dues/data/services/sms_inbox_service.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/services/sms_import_service.dart';
import 'package:dues/parser/models/sms_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'SMS rescan retains manually adjusted fields and keeps source history',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSubscriptionRepository(database);
      final importer = SmsImportService(
        inbox: _Inbox(),
        repository: repository,
      );
      await importer.import();
      final original = (await repository.getSubscriptions()).single;
      await repository.saveSubscription(
        original.copyWith(
          name: 'Family Netflix',
          amount: 199.75,
          currency: 'USD',
          cycle: BillingCycle.yearly,
          nextDueDate: DateTime(2027, 2, 7),
          isAutoDetected: false,
        ),
      );
      await importer.import();
      final edited = (await repository.getSubscriptions()).single;
      expect(edited.name, 'Family Netflix');
      expect(edited.amount, 199.75);
      expect(edited.currency, 'USD');
      expect(edited.cycle, BillingCycle.yearly);
      expect(edited.nextDueDate, DateTime(2027, 2, 7));
      expect(
        await repository.getRecentTransactionsForMerchant(
          edited.normalizedMerchant!,
        ),
        hasLength(2),
      );
    },
  );
}

class _Inbox extends SmsInboxService {
  @override
  Future<List<SmsMessage>> readInbox({int limit = 2000}) async => [
    for (final month in [9, 10])
      SmsMessage(
        id: 'netflix-$month',
        sender: 'HDFC',
        body: 'INR 649 debited at NETFLIX.COM on 05-$month-2026.',
        receivedAt: DateTime(2026, month, 5),
      ),
  ];
}
