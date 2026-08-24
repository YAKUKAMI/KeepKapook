import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/goal_card.dart';
import 'goal_detail_screen.dart';
import 'add_saving_screen.dart';
import 'scan_slip_screen.dart';
import 'ledger_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lp = levelProgress(app.user.exp);
    final overall = app.grandTarget <= 0 ? 0.0 : app.totalSaved / app.grandTarget;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Hero
        _card(
          gradient: const LinearGradient(
            colors: [Color(0x2652C7A5), Color(0x26FFC857)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('สวัสดี ${app.user.emoji}',
                  style: const TextStyle(color: AppColors.mutedText)),
              Text(app.user.name,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Lv.${lp.level} · ${lp.title}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepGreen)),
                  Text('EXP ${lp.inLevel}/${lp.need}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.mutedText)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: lp.need == 0 ? 0 : lp.inLevel / lp.need,
                  minHeight: 8,
                  backgroundColor: Colors.black12,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.warmYellow),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const AddSavingScreen())),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('เพิ่มเงิน'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.deepGreen,
                        side: const BorderSide(color: AppColors.mint),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                      ),
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const ScanSlipScreen())),
                      icon: const Icon(Icons.document_scanner_outlined,
                          size: 18),
                      label: const Text('สแกนสลิป'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ยอดรวม
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ยอดออมรวม',
                          style: TextStyle(color: AppColors.mutedText)),
                      Text(formatMoney(app.totalSaved),
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.deepGreen)),
                    ],
                  ),
                  Text('จากเป้าหมาย ${formatMoney(app.grandTarget)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.mutedText)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: overall.clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: Colors.black12,
                  valueColor: const AlwaysStoppedAnimation(AppColors.mint),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Stats
        Row(
          children: [
            _stat('กระปุกกำลังออม', '${app.activeGoals.length}', AppColors.mint),
            const SizedBox(width: 12),
            _stat('ยังไม่จัดสรร', formatMoney(app.unallocated), AppColors.coral),
          ],
        ),
        const SizedBox(height: 16),

        // รายรับ-รายจ่ายเดือนนี้ (MAKE-style)
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LedgerScreen())),
          child: _card(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('รายรับ-รายจ่ายเดือนนี้',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                          'คงเหลือ ${formatMoney(app.monthIncome - app.monthExpense)}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.deepGreen)),
                      Text(
                          'รับ ${formatMoney(app.monthIncome)} · จ่าย ${formatMoney(app.monthExpense)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.mutedText)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.mutedText),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Chart
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ยอดออม 7 วันล่าสุด',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              SizedBox(height: 160, child: _Chart(app: app)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('กระปุกของฉัน',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 12),
        ...app.activeGoals.map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GoalCard(
                goal: g,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => GoalDetailScreen(goalId: g.id)),
                ),
              ),
            )),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.mutedText)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ),
      );

  Widget _card({required Widget child, Gradient? gradient}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: gradient == null ? AppColors.white : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: kCardShadow,
        ),
        child: child,
      );
}

class _Chart extends StatelessWidget {
  final AppState app;
  const _Chart({required this.app});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: 6 - i)));
    final totals = days.map((d) {
      return app.transactions
          .where((t) =>
              t.type != TxType.withdraw &&
              t.date.year == d.year &&
              t.date.month == d.month &&
              t.date.day == d.day)
          .fold(0.0, (s, t) => s + t.amount);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < totals.length; i++)
                FlSpot(i.toDouble(), totals[i]),
            ],
            isCurved: true,
            color: AppColors.deepGreen,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.mint.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }
}
