import 'package:dues/data/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'permission can be re-enabled without timezone initialization',
    () async {
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final calls = <String>[];
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      var granted = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'areNotificationsEnabled') return granted;
            if (call.method == 'requestNotificationsPermission') {
              return granted = true;
            }
            throw StateError('Unexpected setup ${call.method}');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final service = NotificationService();
      expect(await service.requestPermission(), isTrue);
      expect(calls, [
        'areNotificationsEnabled',
        'requestNotificationsPermission',
      ]);
      calls.clear();
      expect(await service.requestPermission(), isTrue);
      expect(calls, ['areNotificationsEnabled']);
    },
  );
}
