import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  String _txLabel(TxType t) {
    switch (t) {
      case TxType.deposit:
        return 'เงินออมเข้ากระปุก';
      case TxType.unallocated:
        return 'เงินที่ยังไม่จัดสรร';
      case TxType.withdraw:
        return 'ถอนออก';
      case TxType.transfer:
        return 'โอนระหว่างกระปุก';
      case TxType.adjust:
        return 'ปรับยอด';
      case TxType.slip:
        return 'จากสลิป';
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final txs = [...app.transactions]..sort((a, b) => b.date.compareTo(a.date));
    final completed = app.completedGoals;
    String? goalName(String? id) {
      if (id == null) return null;
      for (final g in app.goals) {
        if (g.id == id) return g.name;
      }
      return null;
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('ประวัติ',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (completed.isNotEmpty) ...[
              const Text('กระปุกที่สำเร็จแล้ว',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...completed.map((g) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: kCardShadow,
                    ),
                    child: Row(
                      children: [
                        Text(g.emoji, style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text('🎉 ${formatMoney(g.targetAmount)}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.mutedText)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
            ],
            const Text('รายการทั้งหมด',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...txs.map((t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.mint.withOpacity(0.15),
                    child: Icon(
                      t.type == TxType.withdraw
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      color: AppColors.mint,
                      size: 18,
                    ),
                  ),
                  title: Text(_txLabel(t.type),
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '${formatThaiDate(t.date, short: true)}'
                    '${goalName(t.goalId) != null ? ' · ${goalName(t.goalId)}' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    '${t.type == TxType.withdraw ? '-' : '+'}${formatMoney(t.amount)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepGreen),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
