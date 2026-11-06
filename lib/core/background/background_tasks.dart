import 'package:dues/data/database/app_database.dart';
import 'package:dues/data/repositories/drift_subscription_repository.dart';
import 'package:dues/data/services/notification_service.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

const renewalReconciliationTask = 'renewal-reconciliation';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != renewalReconciliationTask) return true;
    WidgetsFlutterBinding.ensureInitialized();
    final database = AppDatabase();
    try {
      final subscriptions = await DriftSubscriptionRepository(database)
          .getSubscriptions();
      await NotificationService().scheduleRenewals(subscriptions);
      return true;
    } finally {
      await database.close();
    }
  });
}

Future<void> initializeBackgroundTasks() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'dues-renewal-reconciliation',
    renewalReconciliationTask,
    frequency: const Duration(hours: 24),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
