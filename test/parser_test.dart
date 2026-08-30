import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/utils/parser/parser.dart';

final _referenceDate = DateTime.utc(2026, 8, 27);

void main() {
  group('ThaiLedgerParser', () {
    test('รองรับวันสัมพัทธ์และปัดหารด้วย half-up', () {
      final dayBeforeYesterday = parseThaiLedgerLine(
        'กาแฟ 65 เมื่อวานซืน',
        referenceDate: _referenceDate,
      );
      expect(dayBeforeYesterday.items.single.date, DateTime.utc(2026, 8, 25));

      final lastMonday = parseThaiLedgerLine(
        'กาแฟ 65 จันทร์ที่แล้ว',
        referenceDate: _referenceDate,
      );
      expect(lastMonday.items.single.date, DateTime.utc(2026, 8, 24));

      final rounded = parseThaiLedgerLine(
        'หมูกระทะ 100 หาร 3',
        referenceDate: _referenceDate,
      );
      expect(rounded.items.single.amountSatang, 3333);
    });

    test('normalize สัญลักษณ์เงิน alias และคำจำนวนทุกระดับ', () {
      final cases = <String, int>{
        'กาแฟ ฿65': 6500,
        'กาแฟ 65 บ.': 6500,
        'เซเวน 89 บาท': 8900,
        'ขายของได้ 2พัน': 200000,
        'เงินเดือน 3 หมื่น': 3000000,
        'ขายของได้ 4แสน': 40000000,
        'ขายของได้ 1 ล้าน': 100000000,
      };

      for (final entry in cases.entries) {
        final result = parseThaiLedgerLine(
          entry.key,
          referenceDate: _referenceDate,
        );
        expect(result.items.single.amountSatang, entry.value,
            reason: entry.key);
        expect(result.tier, ParseTier.high, reason: entry.key);
      }
    });

    test('เข้าเป้าหมายถามชื่อกระปุกเมื่อ caller ส่งมาหลายตัวเลือก', () {
      final result = parseThaiLedgerLine(
        'ออม 300',
        referenceDate: _referenceDate,
        availableGoalNames: const ['ค่าเทอม', 'เที่ยวญี่ปุ่น'],
      );

      expect(result.tier, ParseTier.low);
      expect(result.items.single.type, ParsedEntryType.goalDeposit);
      expect(
        result.question!.options.map((option) => option.label),
        containsAll(['ค่าเทอม', 'เที่ยวญี่ปุ่น', 'ยกเลิก']),
      );
    });

    test('ปฏิเสธศูนย์ ค่าติดลบ และยอดเกินเพดาน', () {
      for (final input in [
        'กาแฟ 0',
        'กาแฟ -0.01',
        'เงินเดือน 100000000.01',
      ]) {
        final result =
            parseThaiLedgerLine(input, referenceDate: _referenceDate);
        expect(result.tier, ParseTier.reject, reason: input);
        expect(result.rejectReason, isNotEmpty, reason: input);
      }
    });

    test('medium เมื่อรู้จำนวนและประเภทแต่ไม่รู้หมวด', () {
      final result = parseThaiLedgerLine(
        'จ่าย 100',
        referenceDate: _referenceDate,
      );
      expect(result.tier, ParseTier.medium);
      expect(result.items.single.type, ParsedEntryType.expense);
      expect(result.items.single.category, 'อื่น ๆ');
      expect(result.confidence.amount, greaterThan(result.confidence.category));
    });

    test('เก็บตำแหน่งจำนวนและ confidence แยกรายฟิลด์', () {
      final result = parseThaiLedgerLine(
        'ข้าว 50 กาแฟ 40',
        referenceDate: _referenceDate,
      );
      expect(result.detectedAmounts, hasLength(2));
      for (final amount in result.detectedAmounts) {
        expect(amount.start, greaterThanOrEqualTo(0));
        expect(amount.end, greaterThan(amount.start));
        expect(result.normalizedInput.substring(amount.start, amount.end),
            amount.raw);
      }
      for (final value in [
        result.confidence.amount,
        result.confidence.type,
        result.confidence.category,
        result.confidence.date,
      ]) {
        expect(value, inInclusiveRange(0, 1));
      }
    });

    test('ไฟล์ parser เป็น pure Dart และไม่ import Flutter', () {
      final parserDirectory = Directory('lib/utils/parser');
      final dartFiles = parserDirectory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      expect(dartFiles, isNotEmpty);
      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains("package:flutter")), reason: file.path);
        expect(source, isNot(contains("dart:io")), reason: file.path);
      }
    });
  });
}
