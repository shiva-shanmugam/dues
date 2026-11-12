class CurrencyConverter {
  const CurrencyConverter._();

  // Bundled reference values expressed as INR per unit. Dues never contacts
  // an exchange-rate service, so conversion remains private and deterministic.
  static const inrPerUnit = <String, double>{
    'INR': 1,
    'USD': 83.5,
    'EUR': 90.5,
    'GBP': 106,
  };

  static double convert(
    num amount, {
    required String from,
    required String to,
  }) {
    if (from == to) return amount.toDouble();
    final source = inrPerUnit[from];
    final destination = inrPerUnit[to];
    if (source == null || destination == null) return amount.toDouble();
    return amount * source / destination;
  }
}
