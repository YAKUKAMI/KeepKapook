import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/financial_summary.dart';
import '../utils/format.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final entries = [...app.ledger]..sort((a, b) => b.date.compareTo(a.date));
    final month = summarizeLedgerMonth(app.ledger, now: DateTime.now());

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
        onPressed: () => showEntrySheet(context, app),
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
                Text(formatMoney(month.netSatang),
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: month.netSatang >= 0
                            ? AppColors.deepGreen
                            : AppColors.error)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _mini('รายรับ', month.incomeSatang, AppColors.mint),
                    _mini('รายจ่าย', month.expenseSatang, AppColors.coral),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('รายการ', style: TextStyle(fontWeight: FontWeight.w600)),
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
                    onTap: () => _editDialog(context, app, e),
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.cream,
                      child: Text(categoryEmoji[e.category] ?? '✨'),
                    ),
                    title: Text(e.category),
                    subtitle: Text(
                        '${formatThaiDate(e.date.toLocal(), short: true)}${e.note.isNotEmpty ? ' · ${e.note}' : ''}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${e.type == LedgerType.income ? '+' : '-'}${formatMoney(e.amountSatang)}',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: e.type == LedgerType.income
                                  ? AppColors.mint
                                  : AppColors.coral),
                        ),
                        PopupMenuButton<String>(
                          key: ValueKey('ledger-actions-${e.id}'),
                          tooltip: 'จัดการรายการ',
                          onSelected: (action) {
                            if (action == 'edit') {
                              _editDialog(context, app, e);
                            } else {
                              _confirmDelete(context, app, e);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('แก้ไข'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('ลบ'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _mini(String label, int valueSatang, Color color) => Expanded(
        child: Column(
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.mutedText)),
            Text(formatMoney(valueSatang),
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      );

  static void showEntrySheet(
    BuildContext context,
    AppState app, {
    LedgerType initialType = LedgerType.expense,
  }) {
    LedgerType type = initialType;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String category = (type == LedgerType.income
            ? incomeCategories
            : expenseCategories)
        .first;

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
                  ButtonSegment(
                      value: LedgerType.expense, label: Text('รายจ่าย')),
                  ButtonSegment(
                      value: LedgerType.income, label: Text('รายรับ')),
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
                key: const Key('ledger-entry-amount'),
                controller: amountCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setLocal(() {}),
                decoration: InputDecoration(
                  labelText: 'จำนวนเงิน',
                  prefixText: '฿ ',
                  errorText: amountCtrl.text.trim().isEmpty
                      ? null
                      : moneyInputError(amountCtrl.text),
                ),
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
                decoration:
                    const InputDecoration(labelText: 'บันทึก (ไม่บังคับ)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('ledger-entry-save'),
                  onPressed: (parseMoneyToSatang(amountCtrl.text) ?? 0) <= 0
                      ? null
                      : () {
                          app.addLedger(
                            type,
                            parseMoneyToSatang(amountCtrl.text)!,
                            category,
                            noteCtrl.text.trim(),
                          );
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

  Future<void> _editDialog(
    BuildContext context,
    AppState app,
    LedgerEntry entry,
  ) async {
    var type = entry.type;
    var category = entry.category;
    var date = entry.date;
    final amountCtrl = TextEditingController(
      text: formatMoneyInput(entry.amountSatang),
    );
    final noteCtrl = TextEditingController(text: entry.note);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final categories = <String>{
            category,
            ...(type == LedgerType.income
                ? incomeCategories
                : expenseCategories),
          }.toList();
          return Padding(
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
                    'แก้ไขรายการ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<LedgerType>(
                    segments: const [
                      ButtonSegment(
                        value: LedgerType.expense,
                        label: Text('รายจ่าย'),
                      ),
                      ButtonSegment(
                        value: LedgerType.income,
                        label: Text('รายรับ'),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (selection) => setLocal(() {
                      type = selection.first;
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
                    onChanged: (_) => setLocal(() {}),
                    decoration: InputDecoration(
                      labelText: 'จำนวนเงิน',
                      prefixText: '฿ ',
                      errorText: moneyInputError(amountCtrl.text),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'หมวด'),
                    items: [
                      for (final value in categories)
                        DropdownMenuItem(value: value, child: Text(value)),
                    ],
                    onChanged: (value) {
                      if (value != null) setLocal(() => category = value);
                    },
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
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
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
                              app.updateLedgerEntry(
                                id: entry.id,
                                type: type,
                                amountSatang:
                                    parseMoneyToSatang(amountCtrl.text)!,
                                category: category,
                                note: noteCtrl.text.trim(),
                                date: date,
                              );
                              Navigator.pop(ctx);
                            }
                          : null,
                      child: const Text('บันทึกการแก้ไข'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
    LedgerEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบรายการนี้ไหม?'),
        content: Text(
          '${entry.category} ${formatMoney(entry.amountSatang)} จะถูกลบออกจากบัญชี',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยังไม่ลบ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบรายการ'),
          ),
        ],
      ),
    );
    if (confirmed == true) app.deleteLedger(entry.id);
  }
}
