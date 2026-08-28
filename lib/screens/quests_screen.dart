import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class QuestsScreen extends StatelessWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final daily = app.quests.where((q) => q.period == 'daily').toList();
    final weekly = app.quests.where((q) => q.period == 'weekly').toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('ภารกิจ',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('ทำภารกิจเพื่อรับ EXP',
                style: TextStyle(color: AppColors.mutedText)),
            const SizedBox(height: 16),
            const Text('รายวัน', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...daily.map((q) => _QuestTile(quest: q)),
            const SizedBox(height: 16),
            const Text('รายสัปดาห์',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...weekly.map((q) => _QuestTile(quest: q)),
          ],
        ),
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  final Quest quest;
  const _QuestTile({required this.quest});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quest.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(quest.description,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.mutedText)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: quest.progress / quest.target,
                    minHeight: 6,
                    backgroundColor: Colors.black12,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.warmYellow),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                    '${quest.progress}/${quest.target} · +${quest.expReward} EXP',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.mutedText)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: quest.claimed
                  ? AppColors.mint.withValues(alpha: 0.15)
                  : quest.complete
                      ? AppColors.mint
                      : Colors.black12,
              foregroundColor: quest.claimed ? AppColors.mint : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: (!quest.complete || quest.claimed)
                ? null
                : () {
                    final r = app.claimQuest(quest.id);
                    if (r > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('รับรางวัล +$r EXP 🎉'),
                          backgroundColor: AppColors.deepGreen));
                    }
                  },
            child: Text(quest.claimed
                ? 'รับแล้ว'
                : quest.complete
                    ? 'รับรางวัล'
                    : 'ทำต่อ'),
          ),
        ],
      ),
    );
  }
}
