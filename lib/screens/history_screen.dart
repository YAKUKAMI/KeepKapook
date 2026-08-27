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
                              Text('🎉 ${formatMoney(g.targetSatang)}',
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
            if (txs.isEmpty)
              const Text(
                'ยังไม่มีรายการ',
                style: TextStyle(color: AppColors.mutedText),
              ),
            ...txs.map((t) => ListTile(
                  onTap: () => _editTransaction(context, app, t),
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.mint.withValues(alpha: 0.15),
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
                    '${formatThaiDate(t.date.toLocal(), short: true)}'
                    '${goalName(t.goalId) != null ? ' · ${goalName(t.goalId)}' : ''}'
                    '${t.note.isNotEmpty ? ' · ${t.note}' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${t.type == TxType.withdraw ? '-' : '+'}${formatMoney(t.amountSatang)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.deepGreen),
                      ),
                      PopupMenuButton<String>(
                        key: ValueKey('history-actions-${t.id}'),
                        tooltip: 'จัดการรายการ',
                        onSelected: (action) {
                          if (action == 'edit') {
                            _editTransaction(context, app, t);
                          } else {
                            _confirmDelete(context, app, t);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('แก้ไข')),
                          PopupMenuItem(value: 'delete', child: Text('ลบ')),
                        ],
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _editTransaction(
    BuildContext context,
    AppState app,
    SavingTransaction transaction,
  ) async {
    var date = transaction.date;
    String? errorMessage;
    final amountCtrl = TextEditingController(
      text: formatMoneyInput(transaction.amountSatang),
    );
    final noteCtrl = TextEditingController(text: transaction.note);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'แก้ไขประวัติ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _txLabel(transaction.type),
                  style: const TextStyle(color: AppColors.mutedText),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setLocal(() => errorMessage = null),
                  decoration: InputDecoration(
                    labelText: 'จำนวนเงิน',
                    prefixText: '฿ ',
                    errorText: errorMessage ?? moneyInputError(amountCtrl.text),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration:
                      const InputDecoration(labelText: 'บันทึก (ไม่บังคับ)'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: ctx,
                      initialDate: date.toLocal(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (selected != null) {
                      setLocal(() => date = selected.toUtc());
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(formatThaiDate(date.toLocal())),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: moneyInputError(amountCtrl.text) == null
                        ? () {
                            final result = app.updateSavingTransaction(
                              id: transaction.id,
                              amountSatang:
                                  parseMoneyToSatang(amountCtrl.text)!,
                              note: noteCtrl.text.trim(),
                              date: date,
                            );
                            if (result.success) {
                              Navigator.pop(ctx);
                            } else {
                              setLocal(() => errorMessage = result.message);
                            }
                          }
                        : null,
                    child: const Text('บันทึกการแก้ไข'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // รอ reverse animation ถอด TextField ออกจาก tree ก่อนคืน controller
    await Future<void>.delayed(const Duration(milliseconds: 400));
    amountCtrl.dispose();
    noteCtrl.dispose();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppState app,
    SavingTransaction transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบประวัตินี้ไหม?'),
        content: Text(
          '${_txLabel(transaction.type)} ${formatMoney(transaction.amountSatang)} '
          'จะถูกย้อนออกจากยอดที่เกี่ยวข้อง แต่ EXP ที่เคยได้จะไม่ถูกหัก',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยังไม่ลบ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบประวัติ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = app.deleteSavingTransaction(transaction.id);
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'ลบรายการไม่สำเร็จ')),
      );
    }
  }
}
