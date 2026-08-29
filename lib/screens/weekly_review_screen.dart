import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/weekly_review.dart';

class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({super.key, this.now});

  final DateTime? now;

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  bool _questProgressRecorded = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final periods = app.weeklyReviewPeriods(now: widget.now ?? DateTime.now());
    if (periods.isNotEmpty && !_questProgressRecorded) {
      _questProgressRecorded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AppState>().completeWeeklyReview();
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('สรุปสัปดาห์')),
      body: periods.isEmpty
          ? const _EmptyReview()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: periods.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ReportCard(
                report: app.weeklyReportFor(periods[index]),
                initiallyExpanded: index == 0,
              ),
            ),
    );
  }
}

class _EmptyReview extends StatelessWidget {
  const _EmptyReview();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'สรุปแรกจะพร้อมหลังใช้งานครบ 7 วัน\nระหว่างนี้บันทึกตามจริงได้เลยนะ',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedText, height: 1.5),
          ),
        ),
      );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.initiallyExpanded,
  });

  final WeeklyReport report;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final isFirstWeek = report.period.kind == WeeklyReviewKind.firstWeek;
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.white,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          isFirstWeek ? 'สรุป 7 วันแรก' : 'สรุปสัปดาห์',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${formatThaiDate(report.period.start, short: true)} – '
          '${formatThaiDate(report.period.lastDay, short: true)}',
        ),
        children: [
          if (isFirstWeek) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ถ้ารักษาจังหวะนี้จะถึงเป้าเมื่อไร',
                style: TextStyle(
                  color: AppColors.deepGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _MetricRow(
            icon: Icons.edit_calendar_outlined,
            label: 'วันที่บันทึก',
            value: '${report.loggingDays} วัน · streak ${report.streak} วัน',
          ),
          _MetricRow(
            icon: Icons.savings_outlined,
            label: 'ออมเข้าเป้า',
            value: formatMoney(report.savingsToGoalsSatang),
          ),
          _MetricRow(
            icon: Icons.receipt_long_outlined,
            label: 'รายจ่ายที่บันทึก',
            value: _expenseText(report),
          ),
          if (report.topExpenseCategory case final category?)
            _MetricRow(
              icon: Icons.category_outlined,
              label: 'หมวดสูงสุด',
              value:
                  '${category.category} · ${formatMoney(category.amountSatang)}',
            ),
          if (report.dataMessage case final message?) ...[
            const SizedBox(height: 8),
            _Notice(text: message, icon: Icons.info_outline),
          ],
          if (report.projection case final projection?) ...[
            const SizedBox(height: 8),
            _Notice(
              text: _projectionText(projection),
              icon: Icons.flag_outlined,
            ),
          ],
          if (report.goalLink case final link?) ...[
            const SizedBox(height: 8),
            _Notice(
              text: _goalLinkText(report, link),
              icon: Icons.route_outlined,
              emphasized: true,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            report.disclaimer,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _expenseText(WeeklyReport report) {
    final base = formatMoney(report.expenseSatang);
    final comparison = report.expenseComparison;
    if (comparison == null) return base;
    final delta = comparison.deltaSatang;
    if (delta > 0) {
      return '$base · มากกว่าสัปดาห์ก่อน ${formatMoney(delta)}';
    }
    if (delta < 0) {
      return '$base · น้อยกว่าสัปดาห์ก่อน '
          '${formatMoney(comparison.absoluteDeltaSatang)}';
    }
    return '$base · เท่ากับสัปดาห์ก่อน';
  }

  String _projectionText(WeeklyGoalProjection projection) {
    final base = 'ถ้ารักษาจังหวะนี้ “${projection.goalName}” '
        'คาดว่าจะถึงวันที่ ${formatThaiDate(projection.estimatedDate)}';
    final difference = projection.daysComparedWithPlan;
    if (difference == null) return base;
    if (difference > 0) return '$base · เร็วกว่าแผน $difference วัน';
    if (difference < 0) {
      return '$base · ช้ากว่าแผน '
          '${projection.absoluteDaysComparedWithPlan} วัน';
    }
    return '$base · ตรงตามแผน';
  }

  String _goalLinkText(WeeklyReport report, WeeklyGoalLink link) {
    final currentExpense = formatMoney(report.expenseSatang);
    final difference = formatMoney(link.observedDifferenceSatang);
    switch (link.kind) {
      case WeeklyGoalLinkKind.returnToPrevious:
        return 'สัปดาห์นี้ใช้ไป $currentExpense '
            '(มากกว่าสัปดาห์ก่อน $difference) ถ้ากลับไปเท่าเดิมและนำส่วนต่างไปออม '
            '“${link.goalName}” จะถึงเร็วขึ้น ${link.daysSooner} วัน';
      case WeeklyGoalLinkKind.maintainReduction:
        return 'สัปดาห์นี้ใช้ลดลง $difference เก่งมาก '
            'ถ้ารักษาระดับนี้และนำส่วนต่างไปออม “${link.goalName}” '
            'จะถึงเร็วขึ้น ${link.daysSooner} วัน';
      case WeeklyGoalLinkKind.startSaving:
        return 'เราเห็นส่วนต่างรายจ่าย $difference แต่ยังไม่มีจังหวะออมให้คำนวณ '
            'เริ่มออมเข้า “${link.goalName}” วันนี้ได้เลยนะ';
    }
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.deepGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppColors.mutedText),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.text,
    required this.icon,
    this.emphasized = false,
  });

  final String text;
  final IconData icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (emphasized ? AppColors.warmYellow : AppColors.mint)
              .withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.deepGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
          ],
        ),
      );
}
