import 'parser_dictionary.dart';

const _thaiDigits = <String, String>{
  '๐': '0',
  '๑': '1',
  '๒': '2',
  '๓': '3',
  '๔': '4',
  '๕': '5',
  '๖': '6',
  '๗': '7',
  '๘': '8',
  '๙': '9',
};

const _wordMultipliers = <String, int>{
  'พัน': 1000,
  'หมื่น': 10000,
  'แสน': 100000,
  'ล้าน': 1000000,
};

String normalizeThaiLedgerInput(String input) {
  var normalized = input.trim().toLowerCase();

  for (final alias in normalizationAliases.entries) {
    normalized = normalized.replaceAll(alias.key, alias.value);
  }
  for (final digit in _thaiDigits.entries) {
    normalized = normalized.replaceAll(digit.key, digit.value);
  }

  normalized = normalized.replaceAll(',', '');
  normalized = _expandWordAmounts(normalized);
  normalized = normalized.replaceAll(RegExp(r'฿|บาท|บ\.'), ' ');
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized;
}

String _expandWordAmounts(String input) {
  final pattern = RegExp(r'(-?\d+(?:\.\d+)?)\s*(พัน|หมื่น|แสน|ล้าน)');
  return input.replaceAllMapped(pattern, (match) {
    return _multiplyDecimal(match.group(1)!, _wordMultipliers[match.group(2)]!);
  });
}

String _multiplyDecimal(String value, int multiplier) {
  final negative = value.startsWith('-');
  final unsigned = negative ? value.substring(1) : value;
  final parts = unsigned.split('.');
  final fraction = parts.length == 2 ? parts[1] : '';
  final scale = BigInt.from(10).pow(fraction.length);
  final digits = BigInt.parse('${parts[0]}$fraction');
  final product = digits * BigInt.from(multiplier);
  final whole = product ~/ scale;
  final remainder = product % scale;
  final sign = negative ? '-' : '';

  if (remainder == BigInt.zero) return '$sign$whole';
  final decimal = remainder
      .toString()
      .padLeft(fraction.length, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '$sign$whole.$decimal';
}
