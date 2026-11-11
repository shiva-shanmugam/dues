String formatInr(num amount) => formatMoney(amount, 'INR');

String formatMoney(num amount, String currency) {
  final parts = amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2).split('.');
  final value = parts.first;
  final lastThree = value.length > 3
      ? value.substring(value.length - 3)
      : value;
  final leading = value.length > 3 ? value.substring(0, value.length - 3) : '';
  final grouped = currency != 'INR'
      ? value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')
      : leading.isEmpty
      ? lastThree
      : '${leading.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (match) => ',')},$lastThree';
  final symbol = switch (currency) {
    'INR' => '₹',
    'USD' => '\$',
    'EUR' => '€',
    'GBP' => '£',
    _ => '$currency ',
  };
  final decimals = parts.length == 2 ? '.${parts.last}' : '';
  return '$symbol$grouped$decimals';
}

String formatShortDate(DateTime date) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}';
}

String formatLongReceiptDate(DateTime date) {
  const weekdays = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];
  return '${weekdays[date.weekday - 1]} / ${formatShortDate(date)} ${date.year}';
}
