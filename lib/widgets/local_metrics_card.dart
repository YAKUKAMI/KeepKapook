import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/local_metrics.dart';

class LocalMetricsCard extends StatelessWidget {
  const LocalMetricsCard({
    super.key,
    required this.metrics,
    required this.summary,
    required this.onCorpusCollectionChanged,
    required this.onClearCorpus,
  });

  final LocalMetrics metrics;
  final LocalMetricsSummary summary;
  final ValueChanged<bool> onCorpusCollectionChanged;
  final VoidCallback onClearCorpus;

  @override
  Widget build(BuildContext context) {
    final installed = DateTime.tryParse(metrics.installedDay);
    final activeWeeks = summary.activeWeekNumbers.isEmpty
        ? 'ยังไม่มี'
        : summary.activeWeekNumbers.join(', ');
    return Container(
      key: const Key('local-metrics-card'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ข้อมูลการใช้งานในเครื่อง',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'ตัวเลขเหล่านี้ไม่ถูกส่งออกอัตโนมัติ และจะออกจากเครื่องเฉพาะเมื่อคุณเลือกแชร์ไฟล์สำรองเอง',
              style: TextStyle(fontSize: 12, color: AppColors.mutedText),
            ),
            const SizedBox(height: 12),
            _row(
              'วันแรกที่ติดตั้ง',
              installed == null ? 'ไม่ทราบ' : formatThaiDate(installed),
            ),
            _row('จำนวนวันที่บันทึก', '${summary.loggingDayCount} วัน'),
            _row(
              'สัปดาห์ที่ยังบันทึกอยู่',
              '$activeWeeks (${summary.activeLoggingWeekCount} สัปดาห์)',
            ),
            _row('W4 logging retention', _w4Label(summary.w4Status)),
            const Divider(height: 24),
            _row('บันทึกการออม', '${metrics.savingRecordCount} ครั้ง'),
            _row('บันทึกรายจ่าย', '${metrics.expenseRecordCount} ครั้ง'),
            _row(
              'ข้อความบันทึกเร็ว · high',
              '${metrics.quickEntryTierCounts[MetricQuickEntryTier.high] ?? 0} ครั้ง',
            ),
            _row(
              'ข้อความบันทึกเร็ว · medium',
              '${metrics.quickEntryTierCounts[MetricQuickEntryTier.medium] ?? 0} ครั้ง',
            ),
            _row(
              'ข้อความบันทึกเร็ว · low',
              '${metrics.quickEntryTierCounts[MetricQuickEntryTier.low] ?? 0} ครั้ง',
            ),
            _row(
              'ข้อความบันทึกเร็ว · reject',
              '${metrics.quickEntryTierCounts[MetricQuickEntryTier.reject] ?? 0} ครั้ง',
            ),
            _row('กดยกเลิกหลังบันทึก', '${metrics.undoCount} ครั้ง'),
            _row('แก้ไขรายการย้อนหลัง', '${metrics.correctionCount} ครั้ง'),
            _row('เปิดสรุปสัปดาห์', '${metrics.weeklyReviewOpenCount} ครั้ง'),
            _row(
              'ทำตาม Recovery Plan',
              '${metrics.recoveryPlanAcceptedCount} ครั้ง',
            ),
            _row(
              'รับข้อเสนอเป้าหมายถัดไป',
              '${metrics.nextGoalOfferAcceptedCount} จาก '
                  '${metrics.nextGoalOfferDecisionCount} ครั้ง '
                  '(${metrics.nextGoalOfferAcceptancePercent}%)',
            ),
            const Divider(height: 24),
            SwitchListTile(
              key: const Key('parser-corpus-toggle'),
              contentPadding: EdgeInsets.zero,
              value: metrics.parserCorpusCollectionEnabled,
              onChanged: onCorpusCollectionChanged,
              title: const Text('เก็บข้อความเพื่อปรับ parser'),
              subtitle: const Text(
                'เก็บเฉพาะข้อความที่ได้ low/reject หรือถูกแก้ในหน้าบันทึกข้อความ ไม่เก็บยอด หมวด หรือชื่อเป้าหมายเป็น field แยก',
              ),
            ),
            ExpansionTile(
              key: const Key('parser-corpus-list'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                'ข้อความที่เก็บไว้ ${metrics.parserCorpus.length} ประโยค',
              ),
              children: [
                if (metrics.parserCorpus.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'ยังไม่มีข้อความที่เก็บไว้',
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                    ),
                  )
                else
                  for (final sample in metrics.parserCorpus)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(sample.input),
                      subtitle: Text(
                        '${_reasonLabel(sample.reason)} · ${sample.recordedDay}',
                      ),
                    ),
                if (metrics.parserCorpus.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const Key('clear-parser-corpus'),
                      onPressed: onClearCorpus,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('ล้างข้อความที่เก็บไว้'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

String _w4Label(W4LoggingRetentionStatus status) => switch (status) {
      W4LoggingRetentionStatus.waiting => 'ยังวัดไม่ได้',
      W4LoggingRetentionStatus.retained => 'กลับมาบันทึกในสัปดาห์ที่ 4',
      W4LoggingRetentionStatus.notRetained => 'ไม่พบบันทึกในสัปดาห์ที่ 4',
    };

String _reasonLabel(ParserCorpusReason reason) => switch (reason) {
      ParserCorpusReason.low => 'low',
      ParserCorpusReason.reject => 'reject',
      ParserCorpusReason.corrected => 'แก้หลังบันทึก',
    };
