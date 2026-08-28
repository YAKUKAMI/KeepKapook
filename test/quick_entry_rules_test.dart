import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/utils/quick_entry.dart';

void main() {
  group('quick saving presets', () {
    test('ค่าเริ่มต้นคือ 20 / 50 / 100 บาทในหน่วยสตางค์', () {
      expect(defaultQuickSavingAmountsSatang, <int>[2000, 5000, 10000]);
    });

    test('รับเฉพาะสามค่าที่เป็นบวก ไม่ซ้ำ และไม่เกินเพดาน', () {
      expect(
        validateQuickSavingAmounts(<int>[2500, 7500, 20000]),
        isNull,
      );
      expect(validateQuickSavingAmounts(<int>[2500, 7500]), isNotNull);
      expect(validateQuickSavingAmounts(<int>[0, 7500, 20000]), isNotNull);
      expect(validateQuickSavingAmounts(<int>[2500, 2500, 20000]), isNotNull);
      expect(
        validateQuickSavingAmounts(<int>[2500, 7500, 10000000001]),
        isNotNull,
      );
    });
  });

  group('quick saving goal decision', () {
    const travel = QuickGoalOption(id: 'travel', name: 'เที่ยว');
    const laptop = QuickGoalOption(id: 'laptop', name: 'โน้ตบุ๊ก');

    test('ไม่มีกระปุกปิดการบันทึกออมเร็ว', () {
      expect(
        decideQuickGoalSelection(const <QuickGoalOption>[]).mode,
        QuickGoalSelectionMode.unavailable,
      );
    });

    test('กระปุกเดียวเลือกให้อัตโนมัติ', () {
      final decision =
          decideQuickGoalSelection(const <QuickGoalOption>[travel]);
      expect(decision.mode, QuickGoalSelectionMode.direct);
      expect(decision.selectedGoalId, 'travel');
    });

    test('หลายกระปุกต้องให้เลือกโดยยังอยู่หน้าจอเดิม', () {
      final decision = decideQuickGoalSelection(
        const <QuickGoalOption>[travel, laptop],
      );
      expect(decision.mode, QuickGoalSelectionMode.choose);
      expect(decision.selectedGoalId, isNull);
    });
  });

  test('feedback เป้าหมายคำนวณเปอร์เซ็นต์ใน pure function', () {
    final feedback = buildQuickSavingFeedback(
      goalName: 'เที่ยว',
      beforeSatang: 25000,
      afterSatang: 50000,
      targetSatang: 100000,
      flexible: false,
      expGained: 10,
    );

    expect(feedback.progressPercent, 50);
    expect(feedback.expGained, 10);
  });

  test('feedback กระปุก flexible ไม่มีเปอร์เซ็นต์', () {
    final feedback = buildQuickSavingFeedback(
      goalName: 'ใช้ได้ตลอด',
      beforeSatang: 1500,
      afterSatang: 51500,
      targetSatang: 0,
      flexible: true,
      expGained: 10,
    );

    expect(feedback.progressPercent, isNull);
    expect(feedback.afterSatang, 51500);
  });
}
