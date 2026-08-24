import 'package:intl/intl.dart';

// ---------- Money ----------
String formatMoney(double amount) {
  final hasDecimal = (amount * 100).round() % 100 != 0;
  final f = NumberFormat(hasDecimal ? '#,##0.00' : '#,##0', 'th');
  return '฿${f.format(amount)}';
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

// เพดานเงินแนะนำต่อวัน (ตามโหมด + level)
double dailyDepositCap(String mode, int level) {
  if (mode == 'child') return level >= 2 ? 100 : 50;
  const table = [100.0, 300.0, 500.0, 1000.0];
  if (level <= table.length) return table[level - 1];
  return 1000 * (1 << (level - table.length)).toDouble();
}
