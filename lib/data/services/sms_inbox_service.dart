import 'package:dues/parser/models/sms_message.dart';
import 'package:flutter/services.dart';

class SmsInboxService {
  const SmsInboxService();

  static const _channel = MethodChannel('com.duesapp.dues/sms');

  Future<bool> hasPermission() async {
    return await _channel.invokeMethod<bool>('hasPermission') ?? false;
  }

  Future<bool> requestPermission() async {
    return await _channel.invokeMethod<bool>('requestPermission') ?? false;
  }

  Future<List<SmsMessage>> readInbox({int limit = 2000}) async {
    final rows =
        await _channel.invokeListMethod<Map<Object?, Object?>>('readInbox', {
          'limit': limit,
        }) ??
        const [];
    return rows.map((row) {
      return SmsMessage(
        id: row['id']! as String,
        sender: row['sender']! as String,
        body: row['body']! as String,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(row['date']! as int),
      );
    }).toList();
  }
}
