import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/utils/parser/parser.dart';

import 'fixtures/parser_edge_cases.dart';

final _referenceDate = DateTime.utc(2026, 8, 29);

void main() {
  group('ThaiLedgerParser synthetic structural regression', () {
    for (final fixture in mandatoryCases) {
      test('${fixture.group}: ${fixture.input}', () {
        final result = _parse(fixture);

        expect(
          result.tier,
          _tier(fixture.tier),
          reason: fixture.note,
        );

        if (fixture.amountSatang != null) {
          expect(result.items, isNotEmpty, reason: fixture.note);
          expect(
            result.items.first.amountSatang,
            fixture.amountSatang,
            reason: fixture.note,
          );
        }
        if (fixture.type != null) {
          expect(result.items, isNotEmpty, reason: fixture.note);
          expect(
            result.items.first.type,
            _type(fixture.type!),
            reason: fixture.note,
          );
        }
        if (fixture.category != null) {
          expect(result.items, isNotEmpty, reason: fixture.note);
          expect(
            result.items.first.category,
            fixture.category,
            reason: fixture.note,
          );
        }
        if (fixture.dayOffset != null) {
          expect(result.items, isNotEmpty, reason: fixture.note);
          expect(
            result.items.first.date,
            _referenceDate.add(Duration(days: fixture.dayOffset!)),
            reason: fixture.note,
          );
        }
        if (fixture.entryCount > 1) {
          expect(result.items, hasLength(fixture.entryCount),
              reason: fixture.note);
        }
        if (result.tier == ParseTier.low) {
          expect(result.question, isNotNull, reason: fixture.note);
          expect(result.question!.options, isNotEmpty, reason: fixture.note);
        }
        if (result.tier == ParseTier.reject) {
          expect(result.items, isEmpty, reason: fixture.note);
          expect(result.rejectReason, isNotEmpty, reason: fixture.note);
        }
      });
    }

    for (final fixture in knownLimitationCases) {
      test('known limitation ไม่บันทึกเงียบ: ${fixture.input}', () {
        final result = _parse(fixture);
        expect(result.tier, isNot(ParseTier.high), reason: fixture.note);
      });
    }

    test('fixture แยกจาก corpus และมี 70 เคสตามสเปก', () {
      expect(parserEdgeCases, hasLength(70));
      expect(mandatoryCases, hasLength(66));
      expect(knownLimitationCases, hasLength(4));
    });
  });
}

ParseResult _parse(ParserCase fixture) {
  final goalNames = switch ((fixture.group, fixture.contextDependent)) {
    ('G-ambiguous', true) => const <String>['ค่าเทอม', 'โทรศัพท์'],
    (_, true) => const <String>['ค่าเทอม'],
    _ => const <String>[],
  };
  return parseThaiLedgerLine(
    fixture.input,
    referenceDate: _referenceDate,
    availableGoalNames: goalNames,
  );
}

ParseTier _tier(ExpectedTier tier) => switch (tier) {
      ExpectedTier.high => ParseTier.high,
      ExpectedTier.medium => ParseTier.medium,
      ExpectedTier.low => ParseTier.low,
      ExpectedTier.reject => ParseTier.reject,
    };

ParsedEntryType _type(ExpectedType type) => switch (type) {
      ExpectedType.saving => ParsedEntryType.goalDeposit,
      ExpectedType.expense => ParsedEntryType.expense,
      ExpectedType.income => ParsedEntryType.income,
    };
