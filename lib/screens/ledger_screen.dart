import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final entries = [...app.ledger]..sort((a, b) => b.date.compareTo(a.date));
    final net = app.monthIncome - app.monthExpense;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.darkText,
        title: const Text('รายรับ-รายจ่าย'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.mint,
        onPressed: () => _addDialog(context, app),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('บันทึก', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: kCardShadow,
            ),
            child: Column(
              children: [
                const Text('สรุปเดือนนี้',
                    style: TextStyle(color: AppColors.mutedText)),
                const SizedBox(height: 4),
                Text(formatMoney(net),
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: net >= 0 ? AppColors.deepGreen : AppColors.error)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _mini('รายรับ', app.monthIncome, AppColors.mint),
                    _mini('รายจ่าย', app.monthExpense, AppColors.coral),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('รายการ',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Text('ยังไม่มีรายการ',
                style: TextStyle(color: AppColors.mutedText))
          else
            ...entries.map((e) => Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => app.deleteLedger(e.id),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    color: AppColors.error,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.cream,
                      child: Text(categoryEmoji[e.category] ?? '✨'),
                    ),
                    title: Text(e.category),
                    subtitle: Text(
                        '${formatThaiDate(e.date, short: true)}${e.note.isNotEmpty ? ' · ${e.note}' : ''}'),
                    trailing: Text(
                      '${e.type == LedgerType.income ? '+' : '-'}${formatMoney(e.amount)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: e.type == LedgerType.income
                              ? AppColors.mint
                              : AppColors.coral),
                    ),
                  ),
                )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _mini(String label, double value, Color color) => Expanded(
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.mutedText)),
            Text(formatMoney(value),
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      );

  void _addDialog(BuildContext context, AppState app) {
    LedgerType type = LedgerType.expense;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String category = expenseCategories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('บันทึกรายการ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SegmentedButton<LedgerType>(
                segments: const [
                  ButtonSegment(value: LedgerType.expense, label: Text('รายจ่าย')),
                  ButtonSegment(value: LedgerType.income, label: Text('รายรับ')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setLocal(() {
                  type = s.first;
                  category = (type == LedgerType.income
                      ? incomeCategories
                      : expenseCategories)
                      .first;
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'จำนวนเงิน', prefixText: '฿ '),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: (type == LedgerType.income
                        ? incomeCategories
                        : expenseCategories)
                    .map((c) => ChoiceChip(
                          label: Text('${categoryEmoji[c] ?? ''} $c'),
                          selected: category == c,
                          onSelected: (_) => setLocal(() => category = c),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'บันทึก (ไม่บังคับ)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final amt =
                        double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? 0;
                    if (amt > 0) {
                      app.addLedger(type, amt, category, noteCtrl.text.trim());
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('บันทึก'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
