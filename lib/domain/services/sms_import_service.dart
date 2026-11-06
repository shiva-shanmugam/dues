import 'package:dues/domain/models/subscription.dart';
import 'package:dues/domain/models/transaction_record.dart';
import 'package:dues/domain/repositories/subscription_repository.dart';
import 'package:dues/parser/recurrence_detector.dart';
import 'package:dues/parser/models/parsed_transaction.dart';
import 'package:dues/parser/sms_transaction_parser.dart';
import 'package:dues/data/services/sms_inbox_service.dart';

class SmsImportResult {
  const SmsImportResult({
    required this.messagesRead,
    required this.transactionsFound,
    required this.subscriptionsFound,
  });
  final int messagesRead;
  final int transactionsFound;
  final int subscriptionsFound;
}

class SmsImportService {
  SmsImportService({
    required this.inbox,
    required this.repository,
    this.parser = const SmsTransactionParser(),
    this.detector = const RecurrenceDetector(),
  });

  final SmsInboxService inbox;
  final SubscriptionRepository repository;
  final SmsTransactionParser parser;
  final RecurrenceDetector detector;

  Future<SmsImportResult> import() async {
    final messages = await inbox.readInbox();
    final ignored = await repository.getIgnoredMerchants();
    final parsed = messages
        .map(parser.parse)
        .whereType<ParsedTransaction>()
        .where((item) => !ignored.contains(item.merchant.toLowerCase()))
        .toList();

    await repository.saveTransactions(
      parsed.map(
        (item) => TransactionRecord(
          id: item.messageId,
          sender: item.sender,
          body: item.rawBody,
          merchant: item.merchant,
          amount: item.amount,
          currency: item.currency,
          occurredAt: item.occurredAt,
          isDebit: item.isDebit,
          signal: item.signal?.name,
        ),
      ),
    );

    final candidates = detector.detect(parsed);
    final existing = await repository.getSubscriptions();
    final existingByMerchant = {
      for (final item in existing)
        if (item.normalizedMerchant != null)
          item.normalizedMerchant!.toLowerCase(): item,
    };
    for (final candidate in candidates) {
      final current = existingByMerchant[candidate.merchant.toLowerCase()];
      await repository.saveSubscription(
        Subscription(
          id: current?.id ?? 'sms:${_slug(candidate.merchant)}',
          name: current?.name ?? candidate.merchant,
          normalizedMerchant: candidate.merchant,
          amount: candidate.amount,
          currency: candidate.currency,
          cycle: candidate.cycle,
          nextDueDate: _futureDate(candidate.nextDueDate),
          isPaused: current?.isPaused ?? false,
          isAutoDetected: true,
        ),
      );
    }

    return SmsImportResult(
      messagesRead: messages.length,
      transactionsFound: parsed.length,
      subscriptionsFound: candidates.length,
    );
  }

  String _slug(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  DateTime _futureDate(DateTime date) {
    var result = date;
    final now = DateTime.now();
    while (!result.isAfter(now)) {
      result = result.add(const Duration(days: 30));
    }
    return result;
  }
}
