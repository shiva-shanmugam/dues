String formatInr(num amount) {
  final value = amount.round().toString();
  final lastThree = value.length > 3
      ? value.substring(value.length - 3)
      : value;
  final leading = value.length > 3 ? value.substring(0, value.length - 3) : '';
  final grouped = leading.isEmpty
      ? lastThree
      : '${leading.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (match) => ',')},$lastThree';
  return '₹$grouped';
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
