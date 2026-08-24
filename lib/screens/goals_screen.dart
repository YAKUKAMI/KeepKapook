import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/goal_card.dart';
import 'goal_detail_screen.dart';
import 'new_goal_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  int tab = 0; // 0 all, 1 active, 2 completed

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    var list = app.goals;
    if (tab == 1) list = app.activeGoals;
    if (tab == 2) list = app.completedGoals;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('กระปุกของฉัน',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  FilledButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const NewGoalScreen())),
                    child: const Text('สร้างกระปุก'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _tabs(),
              const SizedBox(height: 12),
              Expanded(
                child: list.isEmpty
                    ? const Center(
                        child: Text('ยังไม่มีกระปุก',
                            style: TextStyle(color: AppColors.mutedText)))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => GoalCard(
                          goal: list[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    GoalDetailScreen(goalId: list[i].id)),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabs() {
    const labels = ['ทั้งหมด', 'กำลังออม', 'สำเร็จแล้ว'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: kCardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final active = tab == i;
          return GestureDetector(
            onTap: () => setState(() => tab = i),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.mint : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(labels[i],
                  style: TextStyle(
                      fontSize: 13,
                      color: active ? Colors.white : AppColors.mutedText,
                      fontWeight: FontWeight.w500)),
            ),
          );
        }),
      ),
    );
  }
}
