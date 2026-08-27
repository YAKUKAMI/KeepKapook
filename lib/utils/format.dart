import 'package:intl/intl.dart';

// ---------- Money ----------
const int maxMoneyInputSatang = 10000000000; // ฿100,000,000
const int _maxSafeMoneySatang = 9007199254740991; // JavaScript Number.MAX_SAFE_INTEGER

final RegExp _moneyInputPattern =
    RegExp(r'^(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d+)?$');

BigInt? _parseMoneyToSatangBigInt(String input) {
  final trimmed = input.trim();
  if (!_moneyInputPattern.hasMatch(trimmed)) return null;

  final normalized = trimmed.replaceAll(',', '');
  final parts = normalized.split('.');
  final wholeBaht = BigInt.tryParse(parts[0]);
  if (wholeBaht == null) return null;

  final fraction = parts.length == 2 ? parts[1] : '';
  final twoDigits = '${fraction}00'.substring(0, 2);
  var satang = wholeBaht * BigInt.from(100) + BigInt.parse(twoDigits);

  // ปัดครึ่งขึ้น: หลักทศนิยมที่ 3 ตั้งแต่ 5 ขึ้นไป เพิ่ม 1 สตางค์
  if (fraction.length > 2 && fraction.codeUnitAt(2) >= 53) {
    satang += BigInt.one;
  }
  return satang;
}

int? parseMoneyToSatang(
  String input, {
  int? maxSatang = maxMoneyInputSatang,
}) {
  final satang = _parseMoneyToSatangBigInt(input);
  if (satang == null || satang > BigInt.from(_maxSafeMoneySatang)) return null;
  if (maxSatang != null && satang > BigInt.from(maxSatang)) return null;
  return satang.toInt();
}

String? moneyInputError(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return 'กรุณากรอกจำนวนเงิน';
  if (trimmed.startsWith('-')) return 'จำนวนเงินต้องไม่ติดลบ';

  final satang = _parseMoneyToSatangBigInt(trimmed);
  if (satang == null) return 'รูปแบบจำนวนเงินไม่ถูกต้อง';
  if (satang == BigInt.zero) return 'จำนวนเงินต้องมากกว่า 0';
  if (satang > BigInt.from(maxMoneyInputSatang)) {
    return 'จำนวนเงินต้องไม่เกิน ${formatMoney(maxMoneyInputSatang)}';
  }
  return null;
}

String formatMoney(int amountSatang) {
  final negative = amountSatang < 0;
  final absolute = BigInt.from(amountSatang).abs();
  final wholeBaht = absolute ~/ BigInt.from(100);
  final satang = (absolute % BigInt.from(100)).toInt();
  final formattedBaht = NumberFormat('#,##0', 'th').format(wholeBaht.toInt());
  final decimal = satang == 0 ? '' : '.${satang.toString().padLeft(2, '0')}';
  return '฿${negative ? '-' : ''}$formattedBaht$decimal';
}

// ---------- Date (Thai, พ.ศ.) ----------
const _thaiMonths = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

String formatThaiDate(DateTime d, {bool short = false}) {
  final year = d.year + 543;
  if (short) {
    return '${d.day} ${_thaiMonths[d.month - 1].substring(0, 3)} ${year % 100}';
  }
  return '${d.day} ${_thaiMonths[d.month - 1]} $year';
}

int daysLeft(DateTime target) {
  final diff = target.difference(DateTime.now()).inHours / 24;
  return diff.ceil().clamp(0, 1 << 30);
}

// ---------- Level / EXP ----------
const _levelThresholds = [0, 100, 250, 450, 700, 1000, 1350, 1750, 2200, 2700];

int levelThreshold(int level) {
  if (level <= _levelThresholds.length) return _levelThresholds[level - 1];
  return _levelThresholds.last + (level - _levelThresholds.length) * 550;
}

int levelFromExp(int totalExp) {
  var lvl = 1;
  while (levelThreshold(lvl + 1) <= totalExp) {
    lvl++;
  }
  return lvl;
}

String levelTitle(int level) {
  if (level >= 8) return 'เจ้าแห่งกระปุก';
  if (level >= 6) return 'นักออมระดับตำนาน';
  if (level >= 4) return 'นักออมมั่นคง';
  if (level >= 2) return 'นักออมหน้าใหม่';
  return 'ผู้เริ่มต้น';
}

class LevelInfo {
  final int level;
  final int inLevel;
  final int need;
  final String title;
  LevelInfo(this.level, this.inLevel, this.need, this.title);
}

LevelInfo levelProgress(int totalExp) {
  final level = levelFromExp(totalExp);
  final base = levelThreshold(level);
  final next = levelThreshold(level + 1);
  return LevelInfo(level, totalExp - base, next - base, levelTitle(level));
}

// หมวดรายรับ-รายจ่าย (MAKE-style)
const incomeCategories = ['เงินเดือน', 'ค่าขนม', 'งานพิเศษ', 'โบนัส', 'ของขวัญ', 'อื่น ๆ'];
const expenseCategories = ['อาหาร', 'เดินทาง', 'ช้อปปิ้ง', 'บันเทิง', 'การเรียน', 'บิล', 'อื่น ๆ'];

const categoryEmoji = {
  'เงินเดือน': '💼', 'ค่าขนม': '🪙', 'งานพิเศษ': '🧑‍💻', 'โบนัส': '🎁', 'ของขวัญ': '🎀',
  'อาหาร': '🍜', 'เดินทาง': '🚌', 'ช้อปปิ้ง': '🛍️', 'บันเทิง': '🎬', 'การเรียน': '📚', 'บิล': '🧾',
  'อื่น ๆ': '✨',
};

// เพดานเงินแนะนำต่อวัน หน่วยสตางค์ (ตามโหมด + level)
int dailyDepositCapSatang(String mode, int level) {
  if (mode == 'child') return level >= 2 ? 10000 : 5000;
  const table = [10000, 30000, 50000, 100000];
  if (level <= table.length) return table[level - 1];
  return 100000 * (1 << (level - table.length));
}
