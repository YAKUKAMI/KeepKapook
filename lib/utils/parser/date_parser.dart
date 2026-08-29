class ParsedDate {
  const ParsedDate({
    required this.value,
    required this.confidence,
    required this.explicit,
  });

  final DateTime value;
  final double confidence;
  final bool explicit;
}

const _weekdays = <String, int>{
  'จันทร์': DateTime.monday,
  'อังคาร': DateTime.tuesday,
  'พุธ': DateTime.wednesday,
  'พฤหัสบดี': DateTime.thursday,
  'พฤหัส': DateTime.thursday,
  'ศุกร์': DateTime.friday,
  'เสาร์': DateTime.saturday,
  'อาทิตย์': DateTime.sunday,
};

ParsedDate parseLedgerDate(String input, DateTime referenceDate) {
  final today = _startOfDay(referenceDate);

  if (input.contains('เมื่อวานซืน')) {
    return ParsedDate(
      value: today.subtract(const Duration(days: 2)),
      confidence: 1,
      explicit: true,
    );
  }
  if (input.contains('เมื่อวาน')) {
    return ParsedDate(
      value: today.subtract(const Duration(days: 1)),
      confidence: 1,
      explicit: true,
    );
  }
  if (input.contains('วันนี้')) {
    return ParsedDate(value: today, confidence: 1, explicit: true);
  }

  final daysAgo = RegExp(r'(\d+)\s*วัน(?:ก่อน|ที่แล้ว)').firstMatch(input);
  if (daysAgo != null) {
    final days = int.parse(daysAgo.group(1)!);
    return ParsedDate(
      value: today.subtract(Duration(days: days)),
      confidence: 1,
      explicit: true,
    );
  }

  for (final weekday in _weekdays.entries) {
    if (RegExp('(?:วัน)?${weekday.key}ที่แล้ว').hasMatch(input)) {
      var daysBack = (today.weekday - weekday.value) % 7;
      if (daysBack == 0) daysBack = 7;
      return ParsedDate(
        value: today.subtract(Duration(days: daysBack)),
        confidence: 0.65,
        explicit: true,
      );
    }
  }

  final looksLikeUnknownRelativeDate =
      input.contains('ที่แล้ว') || input.contains('เมื่อ');
  return ParsedDate(
    value: today,
    confidence: looksLikeUnknownRelativeDate ? 0.4 : 0.8,
    explicit: false,
  );
}

DateTime _startOfDay(DateTime value) {
  if (value.isUtc) return DateTime.utc(value.year, value.month, value.day);
  return DateTime(value.year, value.month, value.day);
}
