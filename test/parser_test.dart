import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/utils/parser/parser.dart';

import 'fixtures/parser_corpus.dart';

const _minimumAmountAccuracy = 0.98;
const _minimumTypeAccuracy = 0.95;
const _minimumCategoryAccuracy = 0.80;
final _referenceDate = DateTime.utc(2026, 8, 27);

void main() {
  group('ThaiLedgerParser synthetic regression corpus', () {
    test('ผ่าน regression gate พร้อมรายงาน accuracy แยกรายฟิลด์', () {
      var amountCorrect = 0;
      var amountTotal = 0;
      var typeCorrect = 0;
      var typeTotal = 0;
      var categoryCorrect = 0;
      var categoryTotal = 0;
      var dateCorrect = 0;
      var dateTotal = 0;
      var silentHighErrors = 0;

      for (final fixture in parserCorpus) {
        final result = parseThaiLedgerLine(
          fixture.input,
          referenceDate: _referenceDate,
        );

        expect(
          result.tier,
          fixture.expectedTier,
          reason: 'tier ผิดสำหรับ "${fixture.input}"',
        );

        if (fixture.knownLimitation) {
          expect(fixture.limitationReason, isNotEmpty);
          expect(result.tier, isNot(ParseTier.high));
          continue;
        }

        final expectedAmounts = fixture.expectedItems.isNotEmpty
            ? fixture.expectedItems.map((item) => item.amountSatang).toList()
            : fixture.expectedDetectedAmounts;
        final actualAmounts = result.items.isNotEmpty
            ? result.items.map((item) => item.amountSatang).toList()
            : result.detectedAmounts
                .where((amount) => !amount.isOperatorOperand)
                .map((amount) => amount.amountSatang)
                .whereType<int>()
                .toList();

        if (expectedAmounts.isNotEmpty) {
          amountTotal += expectedAmounts.length;
          for (var index = 0; index < expectedAmounts.length; index++) {
            if (index < actualAmounts.length &&
                actualAmounts[index] == expectedAmounts[index]) {
              amountCorrect++;
            }
          }
        }

        for (var index = 0; index < fixture.expectedItems.length; index++) {
          final expected = fixture.expectedItems[index];
          final actual =
              index < result.items.length ? result.items[index] : null;

          typeTotal++;
          categoryTotal++;
          dateTotal++;
          if (actual?.type == expected.type) typeCorrect++;
          if (actual?.category == expected.category) categoryCorrect++;

          final expectedDate =
              _referenceDate.add(Duration(days: expected.dayOffset));
          if (actual?.date == expectedDate) dateCorrect++;
        }

        final highResultIsWrong = result.tier == ParseTier.high &&
            (!_sameItems(result.items, fixture.expectedItems) ||
                result.rejectReason != null ||
                result.question != null);
        if (highResultIsWrong) silentHighErrors++;

        if (result.tier == ParseTier.low) {
          expect(result.question, isNotNull, reason: fixture.input);
          expect(result.question!.options, isNotEmpty, reason: fixture.input);
        }
        if (result.tier == ParseTier.reject) {
          expect(result.rejectReason, isNotEmpty, reason: fixture.input);
          expect(result.items, isEmpty, reason: fixture.input);
        }
      }

      final amountAccuracy = amountCorrect / amountTotal;
      final typeAccuracy = typeCorrect / typeTotal;
      final categoryAccuracy = categoryCorrect / categoryTotal;
      final dateAccuracy = dateCorrect / dateTotal;

      // ignore: avoid_print
      print(
        'PARSER_SYNTHETIC_REGRESSION_ACCURACY '
        'amount=${_percent(amountAccuracy)} ($amountCorrect/$amountTotal) '
        'type=${_percent(typeAccuracy)} ($typeCorrect/$typeTotal) '
        'category=${_percent(categoryAccuracy)} ($categoryCorrect/$categoryTotal) '
        'date=${_percent(dateAccuracy)} ($dateCorrect/$dateTotal) '
        'silent_high_errors=$silentHighErrors',
      );

      expect(amountAccuracy, greaterThanOrEqualTo(_minimumAmountAccuracy));
      expect(typeAccuracy, greaterThanOrEqualTo(_minimumTypeAccuracy));
      expect(categoryAccuracy, greaterThanOrEqualTo(_minimumCategoryAccuracy));
      expect(silentHighErrors, 0);
    });

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
      final highCases = <String, int>{
        'กาแฟ ฿65': 6500,
        'กาแฟ 65 บ.': 6500,
        'ขายของได้ 2พัน': 200000,
        'เงินเดือน 3 หมื่น': 3000000,
        'ขายของได้ 4แสน': 40000000,
        'ขายของได้ 1 ล้าน': 100000000,
      };

      for (final entry in highCases.entries) {
        final result = parseThaiLedgerLine(
          entry.key,
          referenceDate: _referenceDate,
        );
        expect(result.items.single.amountSatang, entry.value,
            reason: entry.key);
        expect(result.tier, ParseTier.high, reason: entry.key);
      }

      final commonMisspelling = parseThaiLedgerLine(
        'เซเวน 89 บาท',
        referenceDate: _referenceDate,
      );
      expect(commonMisspelling.items.single.amountSatang, 8900);
      expect(commonMisspelling.tier, ParseTier.medium);
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

bool _sameItems(
  List<ParsedLedgerItem> actual,
  List<ExpectedParserItem> expected,
) {
  if (actual.length != expected.length) return false;
  for (var index = 0; index < expected.length; index++) {
    final actualItem = actual[index];
    final expectedItem = expected[index];
    if (actualItem.amountSatang != expectedItem.amountSatang ||
        actualItem.type != expectedItem.type ||
        actualItem.category != expectedItem.category ||
        actualItem.date !=
            _referenceDate.add(Duration(days: expectedItem.dayOffset))) {
      return false;
    }
  }
  return true;
}

String _percent(double value) => '${(value * 100).toStringAsFixed(2)}%';
