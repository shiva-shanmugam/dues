import 'package:dues/data/catalog/popular_plans.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'recognizes common service aliases without guessing unknown merchants',
    () {
      expect(serviceForName('NETFLIX.COM')?.id, 'netflix');
      expect(serviceForName('  Amazon Prime  ')?.id, 'amazon-prime');
      expect(serviceForName('spotify premium')?.id, 'spotify');
      expect(serviceForName('Amazon order 12345'), isNull);
      expect(serviceForName(''), isNull);
    },
  );

  test(
    'reference catalog is India-priced and has traceable official sources',
    () {
      final ids = <String>{};
      for (final service in popularServices) {
        expect(Uri.parse(service.sourceUrl).scheme, 'https');
        expect(DateTime.tryParse(service.checkedOn), isNotNull);
        for (final plan in service.plans) {
          expect(ids.add(plan.id), isTrue, reason: 'Plan IDs must be unique');
          expect(plan.currency, 'INR');
          expect(plan.amount, greaterThan(0));
        }
      }
    },
  );
}
