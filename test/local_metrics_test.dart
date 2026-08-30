import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/utils/local_metrics.dart';

void main() {
  group('local-only metrics', () {
    test('นับวันบันทึกไม่ซ้ำและแยกการออมกับรายจ่าย', () {
      var metrics = LocalMetrics.empty(
        installedAt: DateTime.utc(2026, 1, 1),
      );

      metrics = recordLoggingActivity(
        metrics,
        occurredAt: DateTime.utc(2026, 1, 1, 18), // 2 ม.ค. เวลาไทย
        kind: LoggingKind.saving,
      );
      metrics = recordLoggingActivity(
        metrics,
        occurredAt: DateTime.utc(2026, 1, 2, 10),
        kind: LoggingKind.expense,
      );

      expect(metrics.recordingDays, <String>{'2026-01-02'});
      expect(metrics.savingRecordCount, 1);
      expect(metrics.expenseRecordCount, 1);
    });

    test('W4 คือวันที่ 22-28 หลังติดตั้งและรอให้ช่วงจบก่อนตัดสิน', () {
      var retained = LocalMetrics.empty(
        installedAt: DateTime.utc(2026, 1, 1),
      );
      retained = recordLoggingActivity(
        retained,
        occurredAt: DateTime.utc(2026, 1, 22),
        kind: LoggingKind.expense,
      );

      final waiting = summarizeLocalMetrics(
        retained,
        asOf: DateTime.utc(2026, 1, 28),
      );
      expect(waiting.w4Status, W4LoggingRetentionStatus.waiting);

      final completed = summarizeLocalMetrics(
        retained,
        asOf: DateTime.utc(2026, 1, 29),
      );
      expect(completed.activeWeekNumbers, <int>[4]);
      expect(completed.w4Status, W4LoggingRetentionStatus.retained);

      final notRetained = summarizeLocalMetrics(
        LocalMetrics.empty(installedAt: DateTime.utc(2026, 1, 1)),
        asOf: DateTime.utc(2026, 1, 29),
      );
      expect(notRetained.w4Status, W4LoggingRetentionStatus.notRetained);
    });

    test('นับ quick entry แยก tier และเก็บ corpus เฉพาะ low/reject', () {
      var metrics = LocalMetrics.empty(
        installedAt: DateTime.utc(2026, 1, 1),
      );
      for (final tier in MetricQuickEntryTier.values) {
        metrics = recordQuickEntryAttempt(
          metrics,
          tier: tier,
          input: 'ข้อความ $tier',
          occurredAt: DateTime.utc(2026, 1, 2),
        );
      }

      expect(metrics.quickEntryTierCounts, <MetricQuickEntryTier, int>{
        MetricQuickEntryTier.high: 1,
        MetricQuickEntryTier.medium: 1,
        MetricQuickEntryTier.low: 1,
        MetricQuickEntryTier.reject: 1,
      });
      expect(
        metrics.parserCorpus.map((sample) => sample.reason),
        <ParserCorpusReason>[
          ParserCorpusReason.low,
          ParserCorpusReason.reject,
        ],
      );
      expect(
        metrics.parserCorpus.map((sample) => sample.input),
        <String>[
          'ข้อความ MetricQuickEntryTier.low',
          'ข้อความ MetricQuickEntryTier.reject'
        ],
      );
    });

    test('ปิด corpus แล้วหยุดเก็บข้อความ แต่ยังนับ tier', () {
      var metrics = LocalMetrics.empty(
        installedAt: DateTime.utc(2026, 1, 1),
      ).copyWith(parserCorpusCollectionEnabled: false);

      metrics = recordQuickEntryAttempt(
        metrics,
        tier: MetricQuickEntryTier.reject,
        input: 'ข้อมูลนี้ต้องไม่ถูกเก็บ',
        occurredAt: DateTime.utc(2026, 1, 2),
      );

      expect(metrics.quickEntryTierCounts[MetricQuickEntryTier.reject], 1);
      expect(metrics.parserCorpus, isEmpty);
    });

    test('การแก้จาก parser เก็บเฉพาะข้อความ ไม่เก็บข้อมูลรายการแยก field', () {
      final metrics = recordCorrection(
        LocalMetrics.empty(installedAt: DateTime.utc(2026, 1, 1)),
        occurredAt: DateTime.utc(2026, 1, 2),
        parserInput: 'ข้าวขาหมู 150',
      );

      expect(metrics.correctionCount, 1);
      expect(metrics.parserCorpus.single.input, 'ข้าวขาหมู 150');
      expect(
        metrics.parserCorpus.single.reason,
        ParserCorpusReason.corrected,
      );
      expect(
        metrics.parserCorpus.single.toJson().keys,
        <String>{'input', 'reason', 'recordedDay'},
      );
    });

    test('นับ action ที่เหลือและคำนวณอัตรารับข้อเสนอเป้าหมายถัดไป', () {
      var metrics = LocalMetrics.empty(
        installedAt: DateTime.utc(2026, 1, 1),
      );
      metrics = recordUndo(metrics);
      metrics = recordWeeklyReviewOpen(metrics);
      metrics = recordRecoveryPlanAccepted(metrics);
      metrics = recordNextGoalOfferDecision(metrics, accepted: true);
      metrics = recordNextGoalOfferDecision(metrics, accepted: false);
      metrics = recordNextGoalOfferDecision(metrics, accepted: true);

      expect(metrics.undoCount, 1);
      expect(metrics.weeklyReviewOpenCount, 1);
      expect(metrics.recoveryPlanAcceptedCount, 1);
      expect(metrics.nextGoalOfferAcceptedCount, 2);
      expect(metrics.nextGoalOfferDeferredCount, 1);
      expect(metrics.nextGoalOfferAcceptanceRate, closeTo(2 / 3, 0.0001));
    });

    test('toJson/fromJson round-trip และ field หายใช้ default ได้', () {
      var original = LocalMetrics.empty(
        installedAt: DateTime.utc(2026, 1, 1),
      );
      original = recordLoggingActivity(
        original,
        occurredAt: DateTime.utc(2026, 1, 2),
        kind: LoggingKind.saving,
      );
      original = recordUndo(original);

      expect(
          LocalMetrics.fromJson(original.toJson()).toJson(), original.toJson());

      final missingFields = LocalMetrics.fromJson(<String, dynamic>{});
      expect(missingFields.recordingDays, isEmpty);
      expect(missingFields.undoCount, 0);
      expect(missingFields.parserCorpusCollectionEnabled, isTrue);
    });
  });
}
