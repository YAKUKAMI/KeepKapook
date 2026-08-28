import 'package:flutter/material.dart';

import '../services/quick_entry/quick_entry_controller.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/quick_entry.dart';

class QuickAmountSettings extends StatelessWidget {
  const QuickAmountSettings({required this.controller, super.key});

  final QuickEntryController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          controller.savingAmountsSatang.map(formatMoney).join('  ·  '),
          key: const Key('quick-amount-values'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.deepGreen,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'ปุ่มจำนวนที่แสดงในเมนูออมเร็ว',
          style: TextStyle(fontSize: 12, color: AppColors.mutedText),
        ),
        if (controller.errorMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            controller.errorMessage!,
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('edit-quick-amounts'),
          onPressed: () => _edit(context),
          icon: const Icon(Icons.tune),
          label: const Text('แก้ชุดจำนวน'),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context) async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _QuickAmountsDialog(
        initialAmountsSatang: controller.savingAmountsSatang,
      ),
    );
    if (result == null || !context.mounted) return;
    final saved = await controller.updateSavingAmounts(result);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'อัปเดตปุ่มจำนวนออมเร็วแล้ว'
              : 'บันทึกชุดจำนวนไม่สำเร็จ กรุณาลองอีกครั้ง',
        ),
      ),
    );
  }
}

class _QuickAmountsDialog extends StatefulWidget {
  const _QuickAmountsDialog({required this.initialAmountsSatang});

  final List<int> initialAmountsSatang;

  @override
  State<_QuickAmountsDialog> createState() => _QuickAmountsDialogState();
}

class _QuickAmountsDialogState extends State<_QuickAmountsDialog> {
  late final List<TextEditingController> _inputs;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _inputs = widget.initialAmountsSatang
        .map((amount) => TextEditingController(text: formatMoneyInput(amount)))
        .toList();
  }

  @override
  void dispose() {
    for (final input in _inputs) {
      input.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      title: const Text('แก้ปุ่มจำนวนออมเร็ว'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < _inputs.length; index++) ...[
              TextField(
                key: Key('quick-amount-input-$index'),
                controller: _inputs[index],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'จำนวนที่ ${index + 1} (บาท)',
                  prefixText: '฿ ',
                ),
              ),
              if (index < _inputs.length - 1) const SizedBox(height: 8),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          key: const Key('save-quick-amounts'),
          onPressed: _submit,
          child: const Text('บันทึก'),
        ),
      ],
    );
  }

  void _submit() {
    final values = <int>[];
    for (final input in _inputs) {
      final inputError = moneyInputError(input.text);
      final value = parseMoneyToSatang(input.text);
      if (inputError != null || value == null) {
        setState(
          () => _errorMessage = inputError ?? 'จำนวนเงินไม่ถูกต้อง',
        );
        return;
      }
      values.add(value);
    }
    final valuesError = validateQuickSavingAmounts(values);
    if (valuesError != null) {
      setState(() => _errorMessage = valuesError);
      return;
    }
    Navigator.pop(context, values);
  }
}
