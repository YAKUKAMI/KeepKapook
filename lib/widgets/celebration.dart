import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

// popup แสดงความยินดีเมื่อทำเป้าหมายสำเร็จ
void showCelebration(BuildContext context, Goal goal, int exp) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(goal.emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            const Text('🎉 สำเร็จแล้ว!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepGreen)),
            const SizedBox(height: 4),
            Text('คุณพิชิต ${goal.name} ได้แล้ว',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat('ยอดเป้าหมาย', formatMoney(goal.targetAmount)),
                _stat('ได้รับ', '+$exp EXP'),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx); // ปิด dialog
                Navigator.pop(context); // กลับหน้าก่อน
              },
              child: const Text('เยี่ยมมาก!'),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _stat(String label, String value) => Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedText)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
