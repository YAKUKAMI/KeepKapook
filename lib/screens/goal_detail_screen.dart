import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/coach.dart';
import '../utils/financial_summary.dart';
import '../utils/format.dart';
import '../widgets/simulation_notice.dart';
import 'add_saving_screen.dart';

class GoalDetailScreen extends StatelessWidget {
  final String goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    Goal? goal;
    for (final g in app.goals) {
      if (g.id == goalId) goal = g;
    }
    if (goal == null) {
      return const Scaffold(body: Center(child: Text('ไม่พบกระปุกนี้')));
    }
    final color = Color(goal.themeColor);
    final goalMoney = summarizeGoalMoney(goal);
    final txs = app.transactions.where((t) => t.goalId == goalId).toList();

    // ความเร็วออมเฉลี่ย + สถานะแผน (สำหรับ Recovery)
    final avgPerDaySatang = averageDepositPerDaySatang(txs, goal.startDate);
    final plan = goal.flexible ? null : planStatus(goal);
    final recovery = plan != null && plan.behind
        ? recoveryOptions(goal, plan, avgPerDaySatang)
        : null;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.darkText,
        title: Text(goal.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () {
              app.deleteGoal(goalId);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Text(goal.emoji, style: const TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    if (goal.flexible)
                      _chip('👛 กระเป๋าใช้จ่าย', AppColors.mutedText),
                    if (goal.isLockedNow)
                      _chip(
                          '🔒 ล็อกถึง ${goal.lockUntil != null ? formatThaiDate(goal.lockUntil!, short: true) : '-'}',
                          AppColors.coral),
                    if (goal.shared)
                      _chip('👥 ออมด้วยกัน (${goal.members.length})',
                          AppColors.deepGreen),
                  ],
                ),
                const SizedBox(height: 12),
                if (!goal.flexible)
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CircularProgressIndicator(
                            value: goalMoney.progress,
                            strokeWidth: 10,
                            backgroundColor: Colors.black12,
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                        Text(
                            '${(goalMoney.progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                else
                  Text(formatMoney(goalMoney.currentSatang),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepGreen)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _row(
            goal.flexible ? 'ยอดสะสม' : 'ยอดปัจจุบัน',
            formatMoney(goalMoney.currentSatang),
          ),
          if (!goal.flexible) ...[
            _row('เป้าหมาย', formatMoney(goalMoney.targetSatang)),
            _row('เหลืออีก', formatMoney(goalMoney.remainingSatang)),
            _row('วันที่เหลือ', '${daysLeft(goal.targetDate)} วัน'),
            _row('กำหนดสำเร็จ', formatThaiDate(goal.targetDate, short: true)),
          ],
          if (goal.shared) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: goal.members
                  .map((m) => Chip(
                        avatar: CircleAvatar(
                            backgroundColor: AppColors.mint,
                            child: Text(m.isNotEmpty ? m.substring(0, 1) : '?',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12))),
                        label: Text(m),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _action(
                Icons.remove_circle_outline,
                'ถอน',
                SimulationNoticeKind.withdrawal,
                goal.isLockedNow
                    ? null
                    : () => _withdrawDialog(context, app, goal!),
              ),
              _action(
                Icons.swap_horiz,
                'โอน',
                SimulationNoticeKind.transfer,
                goal.isLockedNow
                    ? null
                    : () => _transferDialog(context, app, goal!),
              ),
              _action(
                goal.isLockedNow ? Icons.lock : Icons.lock_open,
                goal.isLockedNow ? 'ปลดล็อก' : 'ล็อก',
                SimulationNoticeKind.lock,
                () => _lockDialog(context, app, goal!),
              ),
              _action(
                Icons.group_add,
                goal.shared ? 'จัดการแชร์' : 'ออมด้วยกัน',
                SimulationNoticeKind.sharedSaving,
                () => _shareDialog(context, app, goal!),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!goalMoney.isCompleted && plan != null && recovery != null) ...[
            _recoveryCard(context, app, goal, plan, recovery),
            const SizedBox(height: 20),
          ],
          if (!goalMoney.isCompleted)
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AddSavingScreen(presetGoalId: goalId)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มเงิน'),
            ),
          const SizedBox(height: 20),
          const Text('รายการ',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          if (txs.isEmpty)
            const Text('ยังไม่มีรายการ',
                style: TextStyle(color: AppColors.mutedText))
          else
            ...txs.map((t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.arrow_upward, color: AppColors.mint),
                  title: Text(formatMoney(t.amountSatang)),
                  subtitle: Text(formatThaiDate(t.date, short: true)),
                  trailing: t.expAwarded > 0
                      ? Text('+${t.expAwarded} EXP',
                          style: const TextStyle(
                              color: AppColors.mint, fontSize: 12))
                      : null,
                )),
        ],
      ),
    );
  }

  Widget _recoveryCard(BuildContext context, AppState app, Goal goal,
      PlanStatus plan, RecoveryOptions rec) {
    void snack(String m) =>
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warmYellow.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warmYellow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🛟 ภารกิจกู้แผน',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
              'ตามแผนได้ ${plan.onTrackPct}% · ขาดอีก ${formatMoney(plan.shortfallSatang)} — เลือกทางที่ไหวได้เลย',
              style: const TextStyle(fontSize: 12, color: AppColors.mutedText)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => snack(
                    'รับภารกิจ! ออมวันละ ${formatMoney(rec.catchUpPerDaySatang)} ${rec.catchUpDays} วัน 💪'),
                child: Text(
                    'ออมเพิ่มวันละ ${formatMoney(rec.catchUpPerDaySatang)}'),
              ),
              OutlinedButton(
                onPressed: () {
                  goal.targetDate =
                      goal.targetDate.add(Duration(days: rec.extendDays));
                  app.updateGoal(goal);
                  snack('เลื่อนวันสำเร็จ +${rec.extendDays} วัน');
                },
                child: Text('เลื่อน +${rec.extendDays} วัน'),
              ),
              OutlinedButton(
                onPressed: () {
                  goal.targetSatang = rec.reducedTargetSatang;
                  app.updateGoal(goal);
                  snack('ลดเป้าเหลือ ${formatMoney(rec.reducedTargetSatang)}');
                },
                child:
                    Text('ลดเป้าเหลือ ${formatMoney(rec.reducedTargetSatang)}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      );

  Widget _action(IconData icon, String label, SimulationNoticeKind noticeKind,
          VoidCallback? onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 6),
            SimulationNotice(kind: noticeKind, compact: true),
          ],
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepGreen,
          side: const BorderSide(color: AppColors.mint),
        ),
      );

  void _withdrawDialog(BuildContext context, AppState app, Goal goal) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final amountSatang = parseMoneyToSatang(ctrl.text);
          final inputError =
              ctrl.text.trim().isEmpty ? null : moneyInputError(ctrl.text);
          return AlertDialog(
            backgroundColor: AppColors.white,
            title: const Text('ถอนออก'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SimulationNotice(
                    kind: SimulationNoticeKind.withdrawal,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setLocal(() {}),
                    decoration: InputDecoration(
                      prefixText: '฿ ',
                      errorText: inputError,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก')),
              FilledButton(
                onPressed: amountSatang == null || amountSatang <= 0
                    ? null
                    : () {
                        app.withdrawFromGoal(goal.id, amountSatang);
                        Navigator.pop(ctx);
                      },
                child: const Text('ถอนไปยังไม่จัดสรร'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _transferDialog(BuildContext context, AppState app, Goal goal) {
    final others = app.goals.where((g) => g.id != goal.id).toList();
    if (others.isEmpty) return;
    String toId = others.first.id;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final amountSatang = parseMoneyToSatang(ctrl.text);
          final inputError =
              ctrl.text.trim().isEmpty ? null : moneyInputError(ctrl.text);
          return AlertDialog(
            backgroundColor: AppColors.white,
            title: const Text('โอนไปกระปุก/กระเป๋าอื่น'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SimulationNotice(
                    kind: SimulationNoticeKind.transfer,
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: toId,
                    items: others
                        .map((g) => DropdownMenuItem(
                            value: g.id, child: Text('${g.emoji} ${g.name}')))
                        .toList(),
                    onChanged: (v) => setLocal(() => toId = v ?? toId),
                  ),
                  TextField(
                    controller: ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setLocal(() {}),
                    decoration: InputDecoration(
                        prefixText: '฿ ', errorText: inputError),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก')),
              FilledButton(
                onPressed: amountSatang == null || amountSatang <= 0
                    ? null
                    : () {
                        app.transfer(goal.id, toId, amountSatang);
                        Navigator.pop(ctx);
                      },
                child: const Text('โอน'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _lockDialog(BuildContext context, AppState app, Goal goal) {
    if (goal.isLockedNow) {
      app.setLock(goal.id, null);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ปลดล็อกแล้ว')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text('ล็อกเงินถึงเมื่อไร?'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SimulationNotice(kind: SimulationNoticeKind.lock),
              SizedBox(height: 12),
              Text('เลือกระยะเวลาเตือนใจที่ต้องการ'),
            ],
          ),
        ),
        actions: [
          for (final d in [7, 30, 90])
            TextButton(
              onPressed: () {
                app.setLock(goal.id, DateTime.now().add(Duration(days: d)));
                Navigator.pop(ctx);
              },
              child: Text('$d วัน'),
            ),
        ],
      ),
    );
  }

  void _shareDialog(BuildContext context, AppState app, Goal goal) {
    final ctrl = TextEditingController(text: goal.members.join(', '));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text('ออมด้วยกัน'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SimulationNotice(
                kind: SimulationNoticeKind.sharedSaving,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                    labelText: 'สมาชิก (คั่นด้วย ,)',
                    hintText: 'กัปตัน, มายด์, ต้น'),
              ),
            ],
          ),
        ),
        actions: [
          if (goal.shared)
            TextButton(
              onPressed: () {
                app.toggleShared(goal.id, false, []);
                Navigator.pop(ctx);
              },
              child: const Text('ยกเลิกแชร์',
                  style: TextStyle(color: AppColors.error)),
            ),
          FilledButton(
            onPressed: () {
              final members = ctrl.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              app.toggleShared(goal.id, members.isNotEmpty, members);
              Navigator.pop(ctx);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.mutedText)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
