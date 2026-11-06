import 'dart:ui';

import 'package:dues/domain/models/subscription.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

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
    await initialize();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        true;
  }

  Future<void> scheduleRenewals(Iterable<Subscription> subscriptions) async {
    await initialize();
    await _plugin.cancelAllPendingNotifications();
    final now = tz.TZDateTime.now(tz.local);
    for (final subscription in subscriptions.where((item) => !item.isPaused)) {
      for (final daysBefore in const [3, 1]) {
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

  int _notificationId(String id, int daysBefore) {
    var hash = 0x811c9dc5;
    for (final code in '$id:$daysBefore'.codeUnits) {
      hash = ((hash ^ code) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
