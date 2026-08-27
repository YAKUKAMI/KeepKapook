import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

class UnallocatedScreen extends StatelessWidget {
  const UnallocatedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.darkText,
        title: const Text('เงินที่ยังไม่จัดสรร'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.warmYellow.withOpacity(0.25),
                AppColors.coral.withOpacity(0.15),
              ]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ยอดรวมที่ยังไม่จัดสรร',
                    style: TextStyle(color: AppColors.mutedText)),
                Text(formatMoney(app.unallocatedSatang),
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                    'เป็นข้อมูลที่คุณบันทึกไว้ ไม่ใช่เงินจริงที่ KeepKapook ถือครอง',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.mutedText)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: app.unallocatedSatang <= 0
                ? null
                : () => _allocateDialog(context, app),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('จัดสรรเข้ากระปุก'),
          ),
        ],
      ),
    );
  }

  void _allocateDialog(BuildContext context, AppState app) {
    String? goalId = app.activeGoals.isNotEmpty ? app.activeGoals.first.id : null;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final amountSatang = parseMoneyToSatang(ctrl.text);
          final inputError = ctrl.text.trim().isEmpty
              ? null
              : moneyInputError(ctrl.text);
          return AlertDialog(
          backgroundColor: AppColors.white,
          title: const Text('จัดสรรเงิน'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                isExpanded: true,
                value: goalId,
                items: app.activeGoals
                    .map((g) => DropdownMenuItem(
                        value: g.id, child: Text('${g.emoji} ${g.name}')))
                    .toList(),
                onChanged: (v) => setLocal(() => goalId = v),
              ),
              TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setLocal(() {}),
                decoration:
                    InputDecoration(prefixText: '฿ ', errorText: inputError),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก')),
            FilledButton(
              onPressed:
                  goalId == null || amountSatang == null || amountSatang <= 0
                      ? null
                      : () {
                          app.allocateUnallocated(amountSatang, goalId!);
                          Navigator.pop(ctx);
                        },
              child: const Text('จัดสรร'),
            ),
          ],
          );
        },
      ),
    );
  }
}
