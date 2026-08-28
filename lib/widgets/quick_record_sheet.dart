import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/quick_entry/quick_entry_controller.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/quick_entry.dart';

enum QuickRecordInitialMode { saving, expense }

Future<void> showQuickRecordSheet(
  BuildContext context, {
  QuickRecordInitialMode initialMode = QuickRecordInitialMode.saving,
}) async {
  final app = context.read<AppState>();
  final quickEntries = context.read<QuickEntryController?>();
  final messenger = ScaffoldMessenger.of(context);
  final receipt = await showModalBottomSheet<QuickRecordReceipt>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) {
      Widget child = ChangeNotifierProvider<AppState>.value(
        value: app,
        child: QuickRecordSheet(initialMode: initialMode),
      );
      if (quickEntries != null) {
        child = ChangeNotifierProvider<QuickEntryController>.value(
          value: quickEntries,
          child: child,
        );
      }
      return child;
    },
  );
  if (receipt == null || !context.mounted) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 5),
      backgroundColor: AppColors.deepGreen,
      content: Text(_feedbackMessage(receipt)),
      action: SnackBarAction(
        label: 'ยกเลิก',
        textColor: AppColors.warmYellow,
        onPressed: () => app.undoQuickRecord(receipt),
      ),
    ),
  );
}

class QuickRecordLauncher extends StatelessWidget {
  const QuickRecordLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('quick-record-launcher'),
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.coral.withValues(alpha: 0.35)),
          boxShadow: kCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0x26FF7F6A),
                  child: Icon(Icons.bolt, color: AppColors.coral),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'บันทึกเร็ว',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'เลือกงานแล้วบันทึกต่อได้ในหน้าเดียว',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('quick-saving-launcher'),
                    onPressed: () => showQuickRecordSheet(context),
                    icon: const Icon(Icons.savings_outlined, size: 18),
                    label: const Text('ออมเร็ว'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('quick-expense-launcher'),
                    onPressed: () => showQuickRecordSheet(
                      context,
                      initialMode: QuickRecordInitialMode.expense,
                    ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text('รายจ่ายเร็ว'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _QuickRecordMode { saving, expense }

class QuickRecordSheet extends StatefulWidget {
  const QuickRecordSheet({
    this.initialMode = QuickRecordInitialMode.saving,
    super.key,
  });

  final QuickRecordInitialMode initialMode;

  @override
  State<QuickRecordSheet> createState() => _QuickRecordSheetState();
}

class _QuickRecordSheetState extends State<QuickRecordSheet> {
  final TextEditingController _expenseAmountController =
      TextEditingController();
  late _QuickRecordMode _mode;
  String? _selectedGoalId;
  String? _selectedExpenseCategory;
  String? _errorMessage;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode == QuickRecordInitialMode.expense
        ? _QuickRecordMode.expense
        : _QuickRecordMode.saving;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedExpenseCategory ??=
        context.read<QuickEntryController?>()?.lastExpenseCategory ?? 'อาหาร';
  }

  @override
  void dispose() {
    _expenseAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final quickEntries = context.watch<QuickEntryController?>();
    final goals = app.activeGoals
        .map((goal) => QuickGoalOption(id: goal.id, name: goal.name))
        .toList();
    final goalDecision = decideQuickGoalSelection(goals);
    final selectedGoalId = goalDecision.mode == QuickGoalSelectionMode.direct
        ? goalDecision.selectedGoalId
        : _selectedGoalId;
    final amounts =
        quickEntries?.savingAmountsSatang ?? defaultQuickSavingAmountsSatang;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'บันทึกเร็ว',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'บันทึกทันที แล้วกดยกเลิกได้ภายใน 5 วินาที',
                style: TextStyle(fontSize: 12, color: AppColors.mutedText),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _modeButton(
                      key: const Key('quick-saving-tab'),
                      label: 'ออมเร็ว',
                      icon: Icons.savings_outlined,
                      selected: _mode == _QuickRecordMode.saving,
                      onPressed: () => setState(
                        () => _mode = _QuickRecordMode.saving,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _modeButton(
                      key: const Key('quick-expense-tab'),
                      label: 'รายจ่ายเร็ว',
                      icon: Icons.receipt_long_outlined,
                      selected: _mode == _QuickRecordMode.expense,
                      onPressed: () => setState(
                        () => _mode = _QuickRecordMode.expense,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_mode == _QuickRecordMode.saving)
                _savingContent(
                  goals: goals,
                  goalDecision: goalDecision,
                  selectedGoalId: selectedGoalId,
                  amounts: amounts,
                )
              else
                _expenseContent(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton({
    required Key key,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
    return selected
        ? FilledButton(key: key, onPressed: onPressed, child: child)
        : OutlinedButton(key: key, onPressed: onPressed, child: child);
  }

  Widget _savingContent({
    required List<QuickGoalOption> goals,
    required QuickGoalSelection goalDecision,
    required String? selectedGoalId,
    required List<int> amounts,
  }) {
    if (goalDecision.mode == QuickGoalSelectionMode.unavailable) {
      return const Text(
        'สร้างกระปุกก่อน แล้วปุ่มออมเร็วจะพร้อมใช้ตรงนี้',
        style: TextStyle(color: AppColors.mutedText),
      );
    }

    final selectedGoal =
        goals.where((goal) => goal.id == selectedGoalId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (goalDecision.mode == QuickGoalSelectionMode.direct)
          Text(
            'เข้ากระปุก ${selectedGoal?.name}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          )
        else ...[
          const Text(
            'เลือกกระปุก',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: goals
                .map(
                  (goal) => ChoiceChip(
                    key: Key('quick-goal-${goal.id}'),
                    label: Text(goal.name),
                    selected: goal.id == selectedGoalId,
                    onSelected: (_) => setState(
                      () => _selectedGoalId = goal.id,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 14),
        const Text(
          'เลือกจำนวน',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: amounts
              .map(
                (amount) => FilledButton.tonal(
                  key: Key('quick-saving-$amount'),
                  onPressed: selectedGoalId == null || _working
                      ? null
                      : () => _saveSaving(amount, selectedGoalId),
                  child: Text(formatMoney(amount)),
                ),
              )
              .toList(),
        ),
        if (goalDecision.mode == QuickGoalSelectionMode.choose &&
            selectedGoalId == null) ...[
          const SizedBox(height: 8),
          const Text(
            'เลือกกระปุกก่อนกดจำนวน โดยไม่ต้องออกจากหน้านี้',
            style: TextStyle(fontSize: 12, color: AppColors.mutedText),
          ),
        ],
      ],
    );
  }

  Widget _expenseContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('quick-expense-amount'),
          controller: _expenseAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'จำนวน (บาท)',
            prefixText: '฿ ',
          ),
        ),
        const SizedBox(height: 14),
        const Text('หมวด', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: expenseCategories
              .map(
                (category) => ChoiceChip(
                  key: Key('quick-expense-category-$category'),
                  label: Text('${categoryEmoji[category] ?? '✨'} $category'),
                  selected: category == _selectedExpenseCategory,
                  onSelected: (_) => setState(
                    () => _selectedExpenseCategory = category,
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('quick-expense-save'),
            onPressed: _working ? null : _saveExpense,
            icon: const Icon(Icons.check),
            label: const Text('บันทึกรายจ่าย'),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'ไม่ต้องใส่โน้ต และครั้งหน้าจะจำหมวดนี้ไว้ให้',
          style: TextStyle(fontSize: 12, color: AppColors.mutedText),
        ),
      ],
    );
  }

  void _saveSaving(int amountSatang, String goalId) {
    if (_working) return;
    _working = true;
    try {
      final receipt = context.read<AppState>().quickSave(
            amountSatang: amountSatang,
            goalId: goalId,
          );
      _finish(receipt);
    } on DomainValidationException catch (error) {
      setState(() {
        _working = false;
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (_working) return;
    final input = _expenseAmountController.text;
    final error = moneyInputError(input);
    final category = _selectedExpenseCategory;
    if (error != null || category == null) {
      setState(() => _errorMessage = error ?? 'กรุณาเลือกหมวดรายจ่าย');
      return;
    }
    final amountSatang = parseMoneyToSatang(input);
    if (amountSatang == null) {
      setState(() => _errorMessage = 'จำนวนเงินไม่ถูกต้อง');
      return;
    }

    setState(() {
      _working = true;
      _errorMessage = null;
    });
    try {
      final receipt = context.read<AppState>().quickExpense(
            amountSatang: amountSatang,
            category: category,
          );
      await context
          .read<QuickEntryController?>()
          ?.rememberExpenseCategory(category);
      if (!mounted) return;
      _finish(receipt);
    } on DomainValidationException catch (error) {
      if (mounted) {
        setState(() {
          _working = false;
          _errorMessage = error.message;
        });
      }
    }
  }

  void _finish(QuickRecordReceipt receipt) {
    Navigator.pop(context, receipt);
  }
}

String _feedbackMessage(QuickRecordReceipt receipt) {
  final saving = receipt.savingFeedback;
  if (saving != null) {
    final progress = saving.progressPercent == null
        ? 'ยอดสะสม ${formatMoney(saving.afterSatang)}'
        : 'เป้าหมาย ${saving.progressPercent}%';
    return 'เพิ่ม ${formatMoney(receipt.amountSatang)} เข้า '
        '${saving.goalName} แล้ว · $progress'
        '${receipt.expGained > 0 ? ' · +${receipt.expGained} EXP' : ''}';
  }
  return 'บันทึกรายจ่าย ${formatMoney(receipt.amountSatang)} แล้ว · '
      'รายจ่ายเดือนนี้ ${formatMoney(receipt.monthExpenseSatang ?? 0)}';
}
