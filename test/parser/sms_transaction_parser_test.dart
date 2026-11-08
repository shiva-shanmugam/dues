import 'package:dues/parser/models/parsed_transaction.dart';
import 'package:dues/parser/models/sms_message.dart';
import 'package:dues/parser/sms_transaction_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = SmsTransactionParser();
  final receivedAt = DateTime(2026, 11, 5, 12, 30);

  ParsedTransaction? parse(String body, {int id = 1}) => parser.parse(
    SmsMessage(id: '$id', sender: 'BANK', body: body, receivedAt: receivedAt),
  );

  group('Indian debit SMS parsing', () {
    final cases = <({String body, String merchant, double amount})>[
      (
        body: 'HDFC Bank: Rs.649.00 debited from a/c XX1234 at NETFLIX.COM on 05-11-26. Ref 42',
        merchant: 'Netflix',
        amount: 649,
      ),
      (
        body: 'ICICI Bank: INR 119 spent on Card XX8899 at Spotify India on 04/11/2026.',
        merchant: 'Spotify',
        amount: 119,
      ),
      (
        body: 'SBI Card ending 2345 debited by Rs 149 at GOOGLE YOUTUBE on 03-11-26.',
        merchant: 'YouTube Premium',
        amount: 149,
      ),
      (
        body: 'Axis Bank: INR 299.00 was spent on your card at AMAZON PRIME on 02-11-2026.',
        merchant: 'Amazon Prime',
        amount: 299,
      ),
      (
        body: 'Rs.399 paid to Netflix India via UPI from HDFC Bank a/c 9012.',
        merchant: 'Netflix',
        amount: 399,
      ),
      (
        body: 'Paytm: Paid Rs 299 to HOTSTAR via UPI. Ref 5566',
        merchant: 'Disney+ Hotstar',
        amount: 299,
      ),
      (
        body: 'PhonePe: You paid INR 199 to SWIGGY ONE via UPI on 01-11-26.',
        merchant: 'Swiggy One',
        amount: 199,
      ),
      (
        body: 'GPay: You paid ₹149.00 to YouTube Premium using UPI.',
        merchant: 'YouTube Premium',
        amount: 149,
      ),
      (
        body:
            'Auto-debit of INR 499 to NETFLIX.COM on 05-11-26. Mandate ref 91.',
        merchant: 'Netflix',
        amount: 499,
      ),
      (
        body: 'Mandate executed: INR 999 debited towards ADOBE SYSTEMS on 05-11-26.',
        merchant: 'Adobe',
        amount: 999,
      ),
      (
        body: 'INR 3,999 charged for NOTION renewal on your ICICI card.',
        merchant: 'Notion',
        amount: 3999,
      ),
      (
        body: 'Your card was charged Rs.75.50 at APPLE.COM/BILL on 05/11/26.',
        merchant: 'Apple',
        amount: 75.5,
      ),
      (
        body: 'Rs 1300 debited from Axis a/c at CULT.FIT BANGALORE on 05-11-2026.',
        merchant: 'Cult.fit',
        amount: 1300,
      ),
      (
        body: 'INR 130 spent at JIO SERVICES PVT LTD on 05-11-26 using card 1234.',
        merchant: 'Jio',
        amount: 130,
      ),
      (
        body: 'Rs.299 debited at AIRTEL INDIA for txn 4433.',
        merchant: 'Airtel',
        amount: 299,
      ),
      (
        body: 'Purchase of INR 650 at DROPBOX.COM on card XX11.',
        merchant: 'Dropbox',
        amount: 650,
      ),
      (
        body: 'INR 489 paid to ZOMATO GOLD via UPI Ref 8181.',
        merchant: 'Zomato Gold',
        amount: 489,
      ),
      (
        body: 'Rs 1,499.99 spent at MICROSOFT INDIA on your SBI card.',
        merchant: 'Microsoft',
        amount: 1499.99,
      ),
    ];

    for (var index = 0; index < cases.length; index++) {
      final sample = cases[index];
      test('parses realistic debit ${index + 1}: ${sample.merchant}', () {
        final result = parse(sample.body, id: index);
        expect(result, isNotNull);
        expect(result!.merchant, sample.merchant);
        expect(result.amount, sample.amount);
        expect(result.currency, 'INR');
        expect(result.isDebit, isTrue);
      });
    }
  });

  group('recurring keyword signals', () {
    test('detects auto-debit', () {
      expect(
        parse('Auto-debit of INR 499 to Netflix on 05-11-26')!.signal,
        RecurringSignal.autoDebit,
      );
    });

    test('detects mandate', () {
      expect(
        parse('Mandate executed: INR 999 debited towards Adobe on 05-11-26')!
            .signal,
        RecurringSignal.mandate,
      );
    });

    test('detects renewal', () {
      expect(
        parse('INR 3999 charged for Notion renewal on card XX1')!.signal,
        RecurringSignal.renewal,
      );
    });

    test('detects free trial ending with a debit signal', () {
      expect(
        parse('Free trial ending. INR 1 charged at Google One on 05-11-26')!
            .signal,
        RecurringSignal.freeTrial,
      );
    });
  });

  group('UPI transfer narration', () {
    test('stops a named payee before an Info P2A field', () {
      final result = parse(
        'Rs.500 sent from A/c XX1234 to DEVA REDDY on 08-11-26. '
        'Info: P2A/634512908771/deva@upi/UPI',
      );

      expect(result, isNotNull);
      expect(result!.rawMerchant, 'DEVA REDDY');
      expect(result.merchant, 'Deva Reddy');
    });

    test('extracts the payee from a P2A narration after its reference', () {
      final result = parse(
        'INR 500 debited from A/c XX1234. '
        'Info: P2A/634512908771/DEVA REDDY/deva@upi',
      );

      expect(result, isNotNull);
      expect(result!.merchant, 'Deva Reddy');
    });

    test('extracts a P2M business without keeping transfer metadata', () {
      final result = parse(
        'INR 275 debited from account XX99 INFO P2M/634512908772/'
        'GREEN CAFE/merchant@okaxis',
      );

      expect(result, isNotNull);
      expect(result!.merchant, 'Green Cafe');
    });

    test('does not treat an Info field with no named recipient as a payee', () {
      expect(
        parse('INR 500 debited from A/c XX1234. Info: P2A/634512908771'),
        isNull,
      );
    });
  });

  group('false positives and edge cases', () {
    final ignored = [
      '123456 is your OTP for HDFC transaction of Rs 649. Do not share it.',
      'INR 20,000 credited to your SBI account on 05-11-26.',
      'Refund of Rs.499 credited for NETFLIX.COM.',
      'Your credit card statement is generated. Payment due INR 4,321.',
      'Available balance in account XX12 is Rs 15,000.',
      'Get 20% off on Netflix. Promo valid today.',
      'Transaction of INR 999 at Amazon was declined.',
      'Your minimum amount due is Rs 500 by 10-11-26.',
      'Cashback offer: spend Rs 1000 and receive Rs 100.',
      'Login detected for your ICICI account. If not you call support.',
      'Rs 500 received from Rahul via UPI.',
      'KYC expires soon. Update PAN to keep services active.',
    ];

    for (var index = 0; index < ignored.length; index++) {
      test('ignores non-debit sample ${index + 1}', () {
        expect(parse(ignored[index], id: index), isNull);
      });
    }
  });
}
