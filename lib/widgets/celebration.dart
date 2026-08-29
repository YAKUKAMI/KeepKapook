import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/next_goal_offer.dart';

enum CelebrationNextAction {
  continueGoal,
  allocateUnallocated,
  createGoal,
  later,
}

Future<CelebrationNextAction?> showCelebration(
  BuildContext context,
  Goal goal,
  int exp, {
  required NextGoalOffer nextOffer,
}) {
  return showDialog<CelebrationNextAction>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.white,
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: const Key('celebration-close'),
                  tooltip: 'ปิด',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
              ),
              Text(goal.emoji, style: const TextStyle(fontSize: 60)),
              const SizedBox(height: 8),
              const Text(
                'ถึงเป้าหมายแล้ว! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.deepGreen,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${goal.name}\n${formatMoney(goal.currentSatang)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              if (exp > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '+$exp EXP',
                  style: const TextStyle(
                    color: AppColors.coral,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              _NextGoalInvitation(offer: nextOffer),
              const SizedBox(height: 12),
              TextButton(
                key: const Key('celebration-later'),
                onPressed: () => Navigator.pop(
                  dialogContext,
                  CelebrationNextAction.later,
                ),
                child: const Text('ไว้ก่อน'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NextGoalInvitation extends StatelessWidget {
  const _NextGoalInvitation({required this.offer});

  final NextGoalOffer offer;

  @override
  Widget build(BuildContext context) {
    return switch (offer.kind) {
      NextGoalOfferKind.continueExisting => _existingGoal(context),
      NextGoalOfferKind.createNew => _newGoal(context),
    };
  }

  Widget _existingGoal(BuildContext context) {
    final canAllocate = offer.allocatableSatang > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'เก็บต่อให้ ${offer.goalName} ไหม\n'
          'อีก ${formatMoney(offer.remainingSatang)} ก็ถึงแล้ว',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (canAllocate) ...[
          const SizedBox(height: 8),
          Text(
            'มียอดยังไม่จัดสรร ${formatMoney(offer.unallocatedSatang)} '
            'ย้ายเข้าเป้านี้ได้เลย',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedText),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          key: Key(
            canAllocate ? 'celebration-allocate' : 'celebration-continue',
          ),
          onPressed: () => Navigator.pop(
            context,
            canAllocate
                ? CelebrationNextAction.allocateUnallocated
                : CelebrationNextAction.continueGoal,
          ),
          child: Text(
            canAllocate
                ? 'ย้าย ${formatMoney(offer.allocatableSatang)} เข้าเป้านี้'
                : 'ไปออมเป้านี้',
          ),
        ),
      ],
    );
  }

  Widget _newGoal(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'ฉลองให้เต็มที่ก่อนนะ ถ้าอยากไปต่อเมื่อพร้อม '
          'สร้างเป้าหมายถัดไปไว้ได้เลย',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (offer.unallocatedSatang > 0) ...[
          const SizedBox(height: 8),
          Text(
            'ยอดยังไม่จัดสรร ${formatMoney(offer.unallocatedSatang)} '
            'พร้อมรอเป้าหมายใหม่อยู่',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedText),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('celebration-create-goal'),
          onPressed: () => Navigator.pop(
            context,
            CelebrationNextAction.createGoal,
          ),
          child: const Text('สร้างเป้าหมายถัดไป'),
        ),
      ],
    );
  }
}
