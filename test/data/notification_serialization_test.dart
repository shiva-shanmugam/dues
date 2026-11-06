import 'dart:async';

import 'package:dues/data/services/notification_service.dart';
import 'package:dues/domain/models/subscription.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('turning reminders off during scheduling leaves no alarms', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          (_) async => 'Asia/Kolkata',
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_timezone'),
            null,
          ),
    );
    final plugin = _HeldNotificationPlugin();
    final service = NotificationService(plugin: plugin);
    final saving = service.scheduleRenewals([
      Subscription(
        id: 'netflix',
        name: 'Netflix',
        amount: 649,
        cycle: BillingCycle.monthly,
        nextDueDate: DateTime.now().add(const Duration(days: 10)),
      ),
    ]);
    await plugin.scheduleStarted.future;
    final disabling = service.cancelRenewals();
    plugin.releaseSchedule.complete();
    await saving;
    await disabling;

    expect(plugin.pendingIds, isEmpty);
    expect(plugin.scheduleCalls, 1);
    expect(plugin.cancellationCalls, 2);
  });
}

class _HeldNotificationPlugin implements FlutterLocalNotificationsPlugin {
  final scheduleStarted = Completer<void>();
  final releaseSchedule = Completer<void>();
  final pendingIds = <int>{};
  int scheduleCalls = 0;
  int cancellationCalls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  Future<void> cancelAllPendingNotifications() async {
    cancellationCalls++;
    pendingIds.clear();
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduleCalls++;
    scheduleStarted.complete();
    await releaseSchedule.future;
    pendingIds.add(id);
  }
}
