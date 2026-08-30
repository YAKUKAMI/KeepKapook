import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/parser/parser.dart';

Future<void> showConversationalEntrySheet(BuildContext context) {
  final app = context.read<AppState>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ChangeNotifierProvider<AppState>.value(
      value: app,
      child: const ConversationalEntrySheet(),
    ),
  );
}

class ConversationalEntryLauncher extends StatelessWidget {
  const ConversationalEntryLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => showConversationalEntrySheet(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.mint.withValues(alpha: 0.35)),
            boxShadow: kCardShadow,
          ),
          child: const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0x2652C7A5),
                child: Icon(Icons.chat_bubble_outline, color: AppColors.mint),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'พิมพ์บันทึกรายการ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'เช่น “ข้าวขาหมู 150” หรือ “ออม 300”',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: AppColors.deepGreen),
            ],
          ),
        ),
      ),
    );
  }
}

class ConversationalEntrySheet extends StatefulWidget {
  const ConversationalEntrySheet({super.key});

  @override
  State<ConversationalEntrySheet> createState() =>
      _ConversationalEntrySheetState();
}

class _ConversationalEntrySheetState extends State<ConversationalEntrySheet> {
  final _controller = TextEditingController();
  ParseResult? _result;
  ConversationalSaveReceipt? _receipt;
  String? _editableLedgerId;
  String? _editableTransactionId;
  String? _selectedCategory;
  DateTime? _selectedDate;
  bool _showCategoryEditor = false;
  bool _showDateEditor = false;
  String? _message;
  List<Goal>? _pendingGoalChoices;
  ParsedLedgerItem? _pendingGoalItem;
  bool _working = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'บันทึกด้วยข้อความ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'ปิด',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'พิมพ์สั้น ๆ ได้เลย ระบบจะบันทึกทันทีเมื่อข้อมูลชัดเจน',
                style: TextStyle(color: AppColors.mutedText),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('conversational_entry_input'),
                controller: _controller,
                autofocus: true,
                enabled: _receipt == null,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'ข้าวขาหมู 150',
                  suffixIcon: IconButton(
                    key: const Key('conversational_entry_submit'),
                    tooltip: 'บันทึก',
                    onPressed: _working || _receipt != null ? null : _submit,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_receipt != null) _savedContent(),
              if (_receipt == null && _pendingGoalChoices != null)
                _goalQuestion(),
              if (_receipt == null && _pendingGoalChoices == null)
                _resultContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _savedContent() {
    final receipt = _receipt!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.mint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'บันทึก ${formatMoney(receipt.totalAmountSatang)} แล้ว'
                  '${receipt.expGained > 0 ? ' · +${receipt.expGained} EXP' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (_showCategoryEditor &&
              _editableLedgerId != null &&
              _selectedCategory != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('แก้ได้ทันที: '),
                PopupMenuButton<String>(
                  key: const Key('editable_category_chip'),
                  initialValue: _selectedCategory,
                  onSelected: _changeCategory,
                  itemBuilder: (_) => [
                    for (final category in _categoryChoices())
                      PopupMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                  ],
                  child: Chip(
                    label: Text('หมวด: $_selectedCategory ▾'),
                    avatar: Text(categoryEmoji[_selectedCategory] ?? '✨'),
                  ),
                ),
              ],
            ),
          ],
          if (_showDateEditor && _selectedDate != null) ...[
            const SizedBox(height: 8),
            ActionChip(
              key: const Key('editable_date_chip'),
              avatar: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text('วันที่: ${formatThaiDate(_selectedDate!)} ▾'),
              onPressed: _changeDate,
            ),
          ],
          const SizedBox(height: 4),
          const Text(
            'ยอดและ EXP อัปเดตแล้วในหน้าจอนี้',
            style: TextStyle(fontSize: 12, color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _resultContent() {
    if (_message != null) {
      return Text(
        _message!,
        style: const TextStyle(color: AppColors.error),
      );
    }
    final result = _result;
    if (result == null) {
      return const Text(
        'รายการที่ชัดเจนจะถูกบันทึกเลย และยกเลิกได้ภายใน 5 วินาที',
        style: TextStyle(fontSize: 12, color: AppColors.mutedText),
      );
    }
    if (result.tier == ParseTier.reject) {
      return Text(
        result.rejectReason ?? 'ยังบันทึกรายการนี้ไม่ได้',
        style: const TextStyle(color: AppColors.error),
      );
    }
    if (result.tier == ParseTier.low && result.question != null) {
      return _question(
        result.question!.prompt,
        result.question!.options,
        _answerLowQuestion,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _goalQuestion() {
    final goals = _pendingGoalChoices!;
    return _question(
      'ต้องการเก็บเงินเข้ากระปุกไหน?',
      [
        for (var index = 0; index < goals.length; index++)
          ParseOption(id: 'goal_$index', label: goals[index].name),
        const ParseOption(id: 'cancel', label: 'ยกเลิก'),
      ],
      (option) {
        if (option.id == 'cancel') {
          Navigator.pop(context);
          return;
        }
        final index = int.tryParse(option.id.replaceFirst('goal_', ''));
        if (index == null || index < 0 || index >= goals.length) return;
        _saveItems([_pendingGoalItem!], goalId: goals[index].id);
      },
    );
  }

  Widget _question(
    String prompt,
    List<ParseOption> options,
    ValueChanged<ParseOption> onSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              OutlinedButton(
                onPressed: () => onSelected(option),
                child: Text(option.label),
              ),
          ],
        ),
      ],
    );
  }

  void _submit() {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() => _message = 'พิมพ์รายการพร้อมจำนวนเงินก่อนนะ');
      return;
    }

    final app = context.read<AppState>();
    final activeGoals = app.activeGoals;
    final result = parseThaiLedgerLine(
      input,
      referenceDate: DateTime.now(),
      availableGoalNames: activeGoals.map((goal) => goal.name).toList(),
    );
    final goalItems = result.items
        .where((item) => item.type == ParsedEntryType.goalDeposit)
        .toList();
    final effectiveTier = switch ((result.tier, goalItems.isNotEmpty)) {
      (ParseTier.high || ParseTier.medium, true) when activeGoals.isEmpty =>
        ParseTier.reject,
      (ParseTier.high || ParseTier.medium, true) when activeGoals.length > 1 =>
        ParseTier.low,
      _ => result.tier,
    };
    app.recordQuickEntryResult(effectiveTier, input);
    setState(() {
      _result = result;
      _message = null;
      _pendingGoalChoices = null;
      _pendingGoalItem = null;
    });

    if (result.tier == ParseTier.high || result.tier == ParseTier.medium) {
      if (goalItems.isNotEmpty) {
        if (activeGoals.isEmpty) {
          setState(() =>
              _message = 'ยังไม่มีกระปุกสำหรับเก็บเงิน สร้างกระปุกก่อนนะ');
          return;
        }
        if (activeGoals.length > 1) {
          setState(() {
            _pendingGoalChoices = activeGoals;
            _pendingGoalItem = goalItems.single;
          });
          return;
        }
      }
      _saveItems(
        result.items,
        goalId: goalItems.isEmpty ? null : activeGoals.single.id,
        keepOpen: result.tier == ParseTier.medium,
      );
    }
  }

  void _answerLowQuestion(ParseOption option) {
    if (option.id == 'cancel') {
      Navigator.pop(context);
      return;
    }

    final app = context.read<AppState>();
    final activeGoals = app.activeGoals;
    final result = _result!;
    if (option.id.startsWith('goal_') && result.items.isNotEmpty) {
      final index = int.tryParse(option.id.replaceFirst('goal_', ''));
      if (index != null && index >= 0 && index < activeGoals.length) {
        _saveItems(result.items, goalId: activeGoals[index].id);
      }
      return;
    }
    if (option.id == 'split' && result.items.isNotEmpty) {
      _saveItems(result.items);
      return;
    }

    final selectedType = switch (option.id) {
      'expense' ||
      'lend_to_friend' ||
      'repay_friend' =>
        ParsedEntryType.expense,
      'income' ||
      'borrow_from_friend' ||
      'friend_repaid' =>
        ParsedEntryType.income,
      'goal_deposit' => ParsedEntryType.goalDeposit,
      _ => null,
    };
    if (selectedType == null) {
      setState(() => _message = 'รายการนี้ยังต้องระบุให้ชัดอีกนิด');
      return;
    }

    final amount = result.detectedAmounts
        .where((value) => !value.isOperatorOperand)
        .map((value) => value.amountSatang)
        .whereType<int>()
        .firstOrNull;
    if (amount == null) {
      setState(() => _message = 'ใส่จำนวนเงินด้วยนะ');
      return;
    }
    final item = ParsedLedgerItem(
      amountSatang: amount,
      type: selectedType,
      category: selectedType == ParsedEntryType.goalDeposit
          ? 'เป้าหมายการออม'
          : 'อื่น ๆ',
      date: DateTime.now(),
      description: _controller.text.trim(),
      confidence: const FieldConfidence(
        amount: 0.99,
        type: 1,
        category: 0.5,
        date: 0.8,
      ),
    );

    if (selectedType == ParsedEntryType.goalDeposit) {
      if (activeGoals.isEmpty) {
        setState(
            () => _message = 'ยังไม่มีกระปุกสำหรับเก็บเงิน สร้างกระปุกก่อนนะ');
      } else if (activeGoals.length == 1) {
        _saveItems([item], goalId: activeGoals.single.id);
      } else {
        setState(() {
          _pendingGoalChoices = activeGoals;
          _pendingGoalItem = item;
        });
      }
      return;
    }
    _saveItems([item], keepOpen: true);
  }

  void _saveItems(
    List<ParsedLedgerItem> items, {
    String? goalId,
    bool keepOpen = false,
  }) {
    if (_working) return;
    setState(() => _working = true);
    final app = context.read<AppState>();
    try {
      final receipt = app.saveParsedEntries(items, goalId: goalId);
      final editableLedgerId = receipt.ledgerEntryIds.length == 1
          ? receipt.ledgerEntryIds.single
          : null;
      final editableTransactionId = receipt.transactionIds.length == 1
          ? receipt.transactionIds.single
          : null;
      final item = items.length == 1 ? items.single : null;
      final category = item?.category;
      _showUndoSnackBar(receipt);

      if (keepOpen && mounted) {
        setState(() {
          _receipt = receipt;
          _editableLedgerId = editableLedgerId;
          _editableTransactionId = editableTransactionId;
          _selectedCategory = category;
          _selectedDate = item?.date;
          _showCategoryEditor = editableLedgerId != null &&
              item != null &&
              item.confidence.category < 0.9;
          _showDateEditor =
              (editableLedgerId != null || editableTransactionId != null) &&
                  item != null &&
                  item.confidence.date < 0.7;
          _working = false;
        });
      } else if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _working = false;
          _message = 'บันทึกรายการไม่สำเร็จ ลองตรวจข้อมูลอีกครั้งนะ';
        });
      }
    }
  }

  void _showUndoSnackBar(ConversationalSaveReceipt receipt) {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        backgroundColor: AppColors.deepGreen,
        content: Text(
          'บันทึก ${formatMoney(receipt.totalAmountSatang)} แล้ว'
          '${receipt.expGained > 0 ? ' · +${receipt.expGained} EXP' : ''}',
        ),
        action: SnackBarAction(
          label: 'ยกเลิก',
          textColor: AppColors.warmYellow,
          onPressed: () {
            final restored = app.undoConversationalSave(receipt);
            if (restored && mounted) Navigator.maybePop(context);
          },
        ),
      ),
    );
  }

  void _changeCategory(String category) {
    final id = _editableLedgerId;
    if (id == null) return;
    if (context.read<AppState>().updateLedgerCategory(
          id,
          category,
          parserInput: _controller.text.trim(),
        )) {
      setState(() => _selectedCategory = category);
    }
  }

  Future<void> _changeDate() async {
    final current = _selectedDate;
    if (current == null) return;
    final selected = await showDatePicker(
      context: context,
      initialDate: current.toLocal(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected == null || !mounted) return;

    final date = selected.toUtc();
    final app = context.read<AppState>();
    var updated = false;
    if (_editableLedgerId != null) {
      updated = app.updateLedgerDate(
        _editableLedgerId!,
        date,
        parserInput: _controller.text.trim(),
      );
    } else if (_editableTransactionId != null) {
      final transaction = app.transactions
          .where((tx) => tx.id == _editableTransactionId)
          .firstOrNull;
      if (transaction != null) {
        updated = app
            .updateSavingTransaction(
              id: transaction.id,
              amountSatang: transaction.amountSatang,
              note: transaction.note,
              date: date,
              parserInput: _controller.text.trim(),
            )
            .success;
      }
    }
    if (updated && mounted) setState(() => _selectedDate = date);
  }

  List<String> _categoryChoices() {
    return <String>{
      _selectedCategory!,
      ...expenseCategories,
      ...incomeCategories,
    }.toList();
  }
}
