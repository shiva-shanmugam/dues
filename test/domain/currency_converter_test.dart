import 'package:dues/domain/services/currency_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts through bundled INR reference values', () {
    expect(
      CurrencyConverter.convert(8350, from: 'INR', to: 'USD'),
      closeTo(100, .001),
    );
    expect(
      CurrencyConverter.convert(100, from: 'USD', to: 'INR'),
      closeTo(8350, .001),
    );
    expect(
      CurrencyConverter.convert(83.5, from: 'USD', to: 'EUR'),
      closeTo(77.05, .01),
    );
  });

  test('keeps the amount when currencies match or are unsupported', () {
    expect(CurrencyConverter.convert(649, from: 'INR', to: 'INR'), 649);
    expect(CurrencyConverter.convert(649, from: 'JPY', to: 'INR'), 649);
  });
}
