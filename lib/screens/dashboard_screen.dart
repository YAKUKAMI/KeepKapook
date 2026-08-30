import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/financial_summary.dart';
import '../utils/format.dart';
import '../widgets/goal_card.dart';
import '../widgets/habit_calendar_card.dart';
import 'goal_detail_screen.dart';
import 'add_saving_screen.dart';
import 'scan_slip_screen.dart';
import 'ledger_screen.dart';
import 'weekly_review_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lp = levelProgress(app.user.exp);
    final currentTime = now ?? DateTime.now();
    final money = summarizeDashboardMoney(
      goals: app.goals,
      ledger: app.ledger,
      transactions: app.transactions,
      now: currentTime,
    );
    final habitEntries = app.habitEntries;
    final habit = app.habitSummary(now: currentTime);
    final weeklyPeriods = app.weeklyReviewPeriods(now: currentTime);

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
              Text(
                'สวัสดี ${app.user.emoji}',
                style: const TextStyle(color: AppColors.mutedText),
              ),
              Text(
                app.user.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lv.${lp.level} · ${lp.title}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepGreen,
                    ),
                  ),
                  Text(
                    'EXP ${lp.inLevel}/${lp.need}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: lp.progress,
                  minHeight: 8,
                  backgroundColor: Colors.black12,
                  valueColor: const AlwaysStoppedAnimation(
                    AppColors.warmYellow,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddSavingScreen(),
                        ),
                      ),
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
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScanSlipScreen(),
                        ),
                      ),
                      icon: const Icon(
                        Icons.document_scanner_outlined,
                        size: 18,
                      ),
                      label: const Text('สแกนสลิป'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // รายรับ-รายจ่ายเดือนนี้
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LedgerScreen()),
          ),
          child: _card(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'รายรับ-รายจ่ายเดือนนี้',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'คงเหลือ ${formatMoney(money.month.netSatang)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepGreen,
                        ),
                      ),
                      Text(
                        'รับ ${formatMoney(money.month.incomeSatang)} · จ่าย ${formatMoney(money.month.expenseSatang)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.mutedText),
              ],
            ),
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
                      const Text(
                        'ยอดออมรวม',
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                      Text(
                        formatMoney(money.goals.totalSavedSatang),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepGreen,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'จากเป้าหมาย ${formatMoney(money.goals.targetSatang)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: money.goals.targetProgress,
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
            _stat(
              'กระปุกกำลังออม',
              '${app.activeGoals.length}',
              AppColors.mint,
            ),
            const SizedBox(width: 12),
            _stat(
              'ยังไม่จัดสรร',
              formatMoney(app.unallocatedSatang),
              AppColors.coral,
            ),
          ],
        ),
        const SizedBox(height: 16),

        const Text(
          'กระปุกของฉัน',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        ...app.activeGoals.map(
          (g) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GoalCard(
              goal: g,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GoalDetailScreen(goalId: g.id),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),

        HabitCalendarCard(
          summary: habit,
          entries: habitEntries,
          today: currentTime,
        ),
        const SizedBox(height: 16),

        if (weeklyPeriods.isNotEmpty) ...[
          InkWell(
            key: const Key('weekly-review-launcher'),
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WeeklyReviewScreen(now: currentTime),
              ),
            ),
            child: _card(
              gradient: const LinearGradient(
                colors: [Color(0x26FFC857), Color(0x2652C7A5)],
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_graph, color: AppColors.deepGreen),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'สรุปสัปดาห์พร้อมแล้ว',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'ดูจังหวะการบันทึก เป้าหมาย และรายงานย้อนหลัง',
                          style: TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.deepGreen),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
    child: _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
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
