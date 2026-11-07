import 'package:dues/domain/models/subscription.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  int _generation = 0;
  Future<void> _pendingMutation = Future.value();

  Future<void> _enqueue(Future<void> Function() mutation) {
    final next = _pendingMutation.then((_) => mutation());
    _pendingMutation = next.catchError((Object _) {});
    return next;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'renewals',
      'Renewal reminders',
      channelDescription: 'Reminders before recurring subscription renewals',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFFD71921),
    ),
  );

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } on ArgumentError {
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    // Permission prompting does not depend on timezone lookup or scheduling
    // initialization. A failure there must not block re-enabling alerts.
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    if (await android.areNotificationsEnabled() == true) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  Future<void> openSettings() =>
      const MethodChannel('com.duesapp.dues/notifications')
          .invokeMethod<void>('openSettings');

  Future<void> scheduleRenewals(Iterable<Subscription> subscriptions) {
    final generation = ++_generation;
    final snapshot = subscriptions.toList();
    return _enqueue(() => _scheduleRenewals(snapshot, generation));
  }

  Future<void> _scheduleRenewals(
    List<Subscription> subscriptions,
    int generation,
  ) async {
    if (generation != _generation) return;
    await initialize();
    if (generation != _generation) return;
    await _plugin.cancelAllPendingNotifications();
    if (generation != _generation) return;
    final now = tz.TZDateTime.now(tz.local);
    for (final subscription in subscriptions.where((item) => !item.isPaused)) {
      for (final daysBefore in const [3, 1]) {
        if (generation != _generation) return;
        final due = tz.TZDateTime(
          tz.local,
          subscription.nextDueDate.year,
          subscription.nextDueDate.month,
          subscription.nextDueDate.day,
          9,
        );
        final scheduled = due.subtract(Duration(days: daysBefore));
        if (!scheduled.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: _notificationId(subscription.id, daysBefore),
          title:
              '$daysBefore day${daysBefore == 1 ? '' : 's'} until ${subscription.name}',
          body:
              '${subscription.currency == 'INR' ? '₹' : subscription.currency} ${subscription.amount.toStringAsFixed(subscription.amount % 1 == 0 ? 0 : 2)} renews soon.',
          scheduledDate: scheduled,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: subscription.id,
        );
      }
    }
  }

  Future<void> cancelRenewals() {
    ++_generation;
    return _enqueue(() async {
      await initialize();
      await _plugin.cancelAllPendingNotifications();
    });
  }

  int _notificationId(String id, int daysBefore) {
    var hash = 0x811c9dc5;
    for (final code in '$id:$daysBefore'.codeUnits) {
      hash = ((hash ^ code) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
