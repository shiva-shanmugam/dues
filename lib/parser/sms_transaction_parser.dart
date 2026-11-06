import 'package:dues/parser/merchant_normalizer.dart';
import 'package:dues/parser/models/parsed_transaction.dart';
import 'package:dues/parser/models/sms_message.dart';

class SmsTransactionParser {
  const SmsTransactionParser({this.normalizer = const MerchantNormalizer()});

  final MerchantNormalizer normalizer;

  static final _amountPatterns = [
    RegExp(
      r'(?:INR|RS\.?|₹)\s*([0-9][0-9,]*(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:AMOUNT|AMT)\s*[:\-]?\s*([0-9][0-9,]*(?:\.\d{1,2})?)',
      caseSensitive: false,
    ),
  ];

  static final _ignorePatterns = [
    RegExp(
      r'\bOTP\b|ONE[ -]TIME PASSWORD|VERIFICATION CODE',
      caseSensitive: false,
    ),
    RegExp(r'AVAILABLE (?:BALANCE|LIMIT)|AVBL BAL', caseSensitive: false),
    RegExp(
      r'PAYMENT (?:IS )?DUE|STATEMENT GENERATED|MINIMUM AMOUNT DUE',
      caseSensitive: false,
    ),
    RegExp(
      r'LOGIN|PASSWORD|KYC|PROMO|OFFER|CASHBACK OFFER',
      caseSensitive: false,
    ),
  ];

  static final _creditPattern = RegExp(
    r'\b(CREDITED|RECEIVED|REFUND(?:ED)?|CASHBACK (?:OF )?.*CREDIT|DEPOSITED)\b',
    caseSensitive: false,
  );

  static final _debitPattern = RegExp(
    r'\b(DEBITED|SPENT|PAID|SENT|PURCHASE|WITHDRAWN|CHARGED|AUTO[ -]?DEBIT(?:ED)?|AUTOPAY|MANDATE EXECUTED|TXN\s+(?:OF|FOR))\b',
    caseSensitive: false,
  );

  ParsedTransaction? parse(SmsMessage message) {
    final body = message.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (body.isEmpty ||
        _ignorePatterns.any((pattern) => pattern.hasMatch(body))) {
      return null;
    }
    if (_creditPattern.hasMatch(body) && !_debitPattern.hasMatch(body)) {
      return null;
    }
    if (!_debitPattern.hasMatch(body)) return null;

    final amount = _extractAmount(body);
    if (amount == null || amount <= 0) return null;
    final rawMerchant = _extractMerchant(body);
    if (rawMerchant == null || rawMerchant.length < 2) return null;

    return ParsedTransaction(
      messageId: message.id,
      sender: message.sender,
      rawBody: message.body,
      rawMerchant: rawMerchant,
      merchant: normalizer.normalize(rawMerchant),
      amount: amount,
      currency: _currency(body),
      occurredAt: _dateInBody(body, message.receivedAt),
      isDebit: true,
      signal: _signal(body),
    );
  }

  double? _extractAmount(String body) {
    for (final pattern in _amountPatterns) {
      final match = pattern.firstMatch(body);
      final value = match?.group(1)?.replaceAll(',', '');
      if (value != null) return double.tryParse(value);
    }
    return null;
  }

  String? _extractMerchant(String body) {
    final candidates = [
      RegExp(
        r'\b(?:PAID|SENT)\s+(?:(?:INR|RS\.?|₹)\s*)?[0-9][0-9,.]*\s+TO\s+(.+?)(?=\s+(?:ON|VIA|USING|REF|UPI|TXN|FROM)\b|;|\.(?=\s|$)|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'\bAUTO[ -]?DEBIT(?:ED)?\s+(?:OF\s+)?(?:(?:INR|RS\.?|₹)\s*)?[0-9][0-9,.]*\s+(?:TO|FOR)\s+(.+?)(?=\s+(?:ON|REF|MANDATE)\b|;|\.(?=\s|$)|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(?:PAID|SENT)\s+(?:TO\s+)?(.+?)(?=\s+(?:ON|VIA|USING|REF|UPI REF|TXN|FROM)\b|;|\.(?=\s|$)|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(?:AT|TO|TOWARDS|FOR)\s+(.+?)(?=\s+(?:ON|VIA|USING|REF|UPI|TXN|FROM|WITH)\b|;|\.(?=\s|$)|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(?:INFO|MERCHANT)\s*[:\-]\s*(.+?)(?=\s+(?:REF|ON|TXN)\b|;|\.(?=\s|$)|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'\bAUTO[ -]?DEBIT(?:ED)?\s+(?:BY|FOR|TO)?\s*(.+?)(?=\s+(?:FOR|ON|REF|MANDATE)\b|;|\.(?=\s|$)|$)',
        caseSensitive: false,
      ),
    ];
    for (final pattern in candidates) {
      final value = pattern.firstMatch(body)?.group(1)?.trim();
      if (value != null && !_looksLikeAccount(value)) {
        return value;
      }
    }
    return null;
  }

  bool _looksLikeAccount(String value) {
    return RegExp(
      r'^(?:A/C|ACCT|ACCOUNT|CARD|XX|X+|\*+)\s*[X*0-9-]*$',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }

  String _currency(String body) => 'INR';

  DateTime _dateInBody(String body, DateTime fallback) {
    final match = RegExp(r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b')
        .firstMatch(body);
    if (match == null) return fallback;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    var year = int.parse(match.group(3)!);
    if (year < 100) year += 2000;
    try {
      return DateTime(year, month, day, fallback.hour, fallback.minute);
    } on ArgumentError {
      return fallback;
    }
  }

  RecurringSignal? _signal(String body) {
    if (RegExp(
      r'FREE TRIAL|TRIAL (?:ENDS|ENDING|EXPIRES)',
      caseSensitive: false,
    ).hasMatch(body)) {
      return RecurringSignal.freeTrial;
    }
    if (RegExp(
      r'AUTO[ -]?DEBIT|AUTOPAY',
      caseSensitive: false,
    ).hasMatch(body)) {
      return RecurringSignal.autoDebit;
    }
    if (RegExp(r'\bMANDATE\b|E-?NACH', caseSensitive: false).hasMatch(body)) {
      return RecurringSignal.mandate;
    }
    if (RegExp(r'RENEW(?:AL|ED|S)', caseSensitive: false).hasMatch(body)) {
      return RecurringSignal.renewal;
    }
    return null;
  }
}
