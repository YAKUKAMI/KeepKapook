import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/product_event_store.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/next_goal_offer.dart';
import '../utils/product_events.dart';
import '../widgets/celebration.dart';
import 'new_goal_screen.dart';

class AddSavingScreen extends StatefulWidget {
  final String? presetGoalId;
  const AddSavingScreen({super.key, this.presetGoalId});
  @override
  State<AddSavingScreen> createState() => _AddSavingScreenState();
}

class _AddSavingScreenState extends State<AddSavingScreen> {
  final _amountCtrl = TextEditingController();
  String _dest = 'unallocated';
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    if (widget.presetGoalId != null) {
      _dest = widget.presetGoalId!;
      _locked = true;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final amountSatang = parseMoneyToSatang(_amountCtrl.text);
    final inputError = _amountCtrl.text.trim().isEmpty
        ? null
        : moneyInputError(_amountCtrl.text);

    Goal? lockedGoal;
    if (_locked) {
      for (final g in app.goals) {
        if (g.id == _dest) lockedGoal = g;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.darkText,
        title: const Text('เพิ่มเงินออม'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('จำนวนเงิน',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixText: '฿ ',
              errorText: inputError,
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('เข้ากระปุก',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          if (lockedGoal != null)
            _destTile('${lockedGoal.emoji} ${lockedGoal.name}', true,
                trailing:
                    const Icon(Icons.lock, size: 16, color: AppColors.mint))
          else ...[
            _destTile('💼 เงินที่ยังไม่จัดสรร', _dest == 'unallocated',
                onTap: () => setState(() => _dest = 'unallocated')),
            ...app.activeGoals.map((g) => _destTile(
                  '${g.emoji} ${g.name}',
                  _dest == g.id,
                  onTap: () => setState(() => _dest = g.id),
                )),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: amountSatang == null || amountSatang <= 0
                ? null
                : () async {
                    final res = app.addSaving(
                      amountSatang: amountSatang,
                      goalId: _dest == 'unallocated' ? null : _dest,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'บันทึก ${formatMoney(amountSatang)} แล้ว${res.exp > 0 ? ' · +${res.exp} EXP' : ''}'),
                      backgroundColor: AppColors.deepGreen,
                    ));
                    if (res.completed != null) {
                      final nextOffer = app.nextGoalOfferAfter(
                        <String>{res.completed!.id},
                      );
                      final action = await showCelebration(
                        context,
                        res.completed!,
                        res.exp,
                        nextOffer: nextOffer,
                      );
                      if (!context.mounted) return;
                      await _handleCelebrationAction(app, nextOffer, action);
                    } else {
                      Navigator.pop(context);
                    }
                  },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCelebrationAction(
    AppState app,
    NextGoalOffer offer,
    CelebrationNextAction? action,
  ) async {
    switch (action) {
      case CelebrationNextAction.allocateUnallocated:
        app.allocateUnallocated(
          offer.allocatableSatang,
          offer.goalId!,
        );
        await _recordNextGoalDecision(
          ProductEventName.nextGoalOfferAccepted,
          offer,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ย้าย ${formatMoney(offer.allocatableSatang)} '
              'เข้า ${offer.goalName} แล้ว',
            ),
            backgroundColor: AppColors.deepGreen,
          ),
        );
        Navigator.pop(context);
        return;
      case CelebrationNextAction.continueGoal:
        await _recordNextGoalDecision(
          ProductEventName.nextGoalOfferAccepted,
          offer,
        );
        if (!mounted) return;
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AddSavingScreen(presetGoalId: offer.goalId),
          ),
        );
        return;
      case CelebrationNextAction.createGoal:
        await _recordNextGoalDecision(
          ProductEventName.nextGoalOfferAccepted,
          offer,
        );
        if (!mounted) return;
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (_) => const NewGoalScreen()),
        );
        return;
      case CelebrationNextAction.later:
        await _recordNextGoalDecision(
          ProductEventName.nextGoalOfferDeferred,
          offer,
        );
        if (!mounted) return;
        Navigator.pop(context);
        return;
      case null:
        Navigator.pop(context);
        return;
    }
  }

  Future<void> _recordNextGoalDecision(
    ProductEventName name,
    NextGoalOffer offer,
  ) async {
    final eventStore = context.read<ProductEventStore?>();
    if (eventStore == null) return;
    try {
      await eventStore.record(
        ProductEventRecord(
          name: name,
          occurredAt: DateTime.now().toUtc(),
          properties: <String, String>{'offerKind': offer.kind.name},
        ),
      );
    } on Object catch (error) {
      debugPrint('บันทึก next-goal event ไม่สำเร็จ: $error');
    }
  }

  Widget _destTile(String label, bool active,
      {VoidCallback? onTap, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active
                ? AppColors.mint.withValues(alpha: 0.1)
                : AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? AppColors.mint : Colors.black12),
          ),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }
}
