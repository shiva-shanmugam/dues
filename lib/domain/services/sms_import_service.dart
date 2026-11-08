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
    final claimedSubscriptionIds = <String>{};
    for (final candidate in candidates) {
      final current =
          existingByMerchant[candidate.merchant.toLowerCase()] ??
          _legacyMetadataMatch(candidate, existing, claimedSubscriptionIds);
      if (current != null) claimedSubscriptionIds.add(current.id);
      // A manually adjusted subscription remains linked to its source SMS,
      // but its price, cycle and due date are owned by the user.
      if (current != null && !current.isAutoDetected) continue;
      await repository.saveSubscription(
        Subscription(
          id: current?.id ?? 'sms:${_slug(candidate.merchant)}',
          name: candidate.merchant,
          normalizedMerchant: candidate.merchant,
          amount: candidate.amount,
          currency: candidate.currency,
          cycle: candidate.cycle,
          nextDueDate: _futureDate(candidate.nextDueDate, candidate.cycle),
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

  Subscription? _legacyMetadataMatch(
    RecurringCandidate candidate,
    List<Subscription> existing,
    Set<String> claimedIds,
  ) {
    final candidateKey = candidate.merchant.toLowerCase();
    final possible = existing.where((item) {
      if (!item.isAutoDetected || claimedIds.contains(item.id)) return false;
      final oldKey = (item.normalizedMerchant ?? item.name).toLowerCase();
      final withoutMetadata = oldKey
          .replaceFirst(RegExp(r'\s+(?:info|p2[am])(?:\s+p2[am])?$'), '')
          .trim();
      final metadataOnly = RegExp(r'^(?:info\s+)?p2[am]$').hasMatch(oldKey);
      final sameIdentity = withoutMetadata == candidateKey || metadataOnly;
      final amountClose =
          (item.amount - candidate.amount).abs() <= candidate.amount * .02;
      return sameIdentity &&
          amountClose &&
          item.currency == candidate.currency &&
          item.cycle == candidate.cycle;
    }).toList();
    return possible.length == 1 ? possible.single : null;
  }

  String _slug(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  DateTime _futureDate(DateTime date, BillingCycle cycle) {
    var result = date;
    final now = DateTime.now();
    while (!result.isAfter(now)) {
      result = result.add(Duration(days: cycle.days));
    }
    return result;
  }
}
