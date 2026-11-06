import 'package:dues/data/services/notification_service.dart';
import 'package:dues/domain/repositories/subscription_repository.dart';
import 'package:dues/presentation/providers/app_providers.dart';
import 'package:dues/presentation/providers/preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReminderSync {
  ReminderSync(this.repository, this.notifications, this.readPreferences);

  final SubscriptionRepository repository;
  final NotificationService notifications;
  final Future<AppPreferences> Function() readPreferences;
  int _generation = 0;

  Future<bool> sync() async {
    final generation = ++_generation;
    try {
      await _sync(generation).timeout(const Duration(seconds: 8));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _sync(int generation) async {
    final preferences = await readPreferences();
    if (generation != _generation) return;
    if (!preferences.renewalAlertsEnabled) {
      await notifications.cancelRenewals();
      return;
    }
    final subscriptions = await repository.getSubscriptions();
    if (generation != _generation) return;
    await notifications.scheduleRenewals(subscriptions);
  }
}

final reminderSyncProvider = Provider(
  (ref) => ReminderSync(
    ref.watch(repositoryProvider),
    ref.watch(notificationServiceProvider),
    () => ref.read(appPreferencesProvider.future),
  ),
);
