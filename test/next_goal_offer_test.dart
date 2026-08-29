import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/utils/next_goal_offer.dart';

NextGoalOfferInput _goal(
  String id, {
  int currentSatang = 20000,
  int targetSatang = 100000,
  bool completed = false,
  bool flexible = false,
}) =>
    NextGoalOfferInput(
      id: id,
      name: 'เป้าหมาย $id',
      currentSatang: currentSatang,
      targetSatang: targetSatang,
      completed: completed,
      flexible: flexible,
    );

void main() {
  group('selectNextGoalOffer', () {
    test('มีเป้าหมายค้างอยู่ เสนอเป้าที่ใกล้ถึงที่สุดก่อน', () {
      final offer = selectNextGoalOffer(
        goals: <NextGoalOfferInput>[
          _goal('completed', currentSatang: 100000, completed: true),
          _goal('far', currentSatang: 10000),
          _goal('near', currentSatang: 85000),
        ],
        newlyCompletedGoalIds: const <String>{'completed'},
        unallocatedSatang: 0,
      );

      expect(offer.kind, NextGoalOfferKind.continueExisting);
      expect(offer.goalId, 'near');
      expect(offer.remainingSatang, 15000);
      expect(offer.allocatableSatang, 0);
    });

    test('ไม่มีเป้าหมายอื่น เสนอทางลัดสร้างเป้าหมายใหม่', () {
      final offer = selectNextGoalOffer(
        goals: <NextGoalOfferInput>[
          _goal('completed', currentSatang: 100000, completed: true),
        ],
        newlyCompletedGoalIds: const <String>{'completed'},
        unallocatedSatang: 0,
      );

      expect(offer.kind, NextGoalOfferKind.createNew);
      expect(offer.goalId, isNull);
    });

    test('มียอดยังไม่จัดสรร เสนอจำนวนที่ย้ายได้จริงในคลิกเดียว', () {
      final offer = selectNextGoalOffer(
        goals: <NextGoalOfferInput>[
          _goal('completed', currentSatang: 100000, completed: true),
          _goal('next', currentSatang: 70000),
        ],
        newlyCompletedGoalIds: const <String>{'completed'},
        unallocatedSatang: 50000,
      );

      expect(offer.kind, NextGoalOfferKind.continueExisting);
      expect(offer.remainingSatang, 30000);
      expect(offer.unallocatedSatang, 50000);
      expect(offer.allocatableSatang, 30000);
    });

    test('ถึงเป้าพร้อมกันสองอัน ไม่เสนอเป้าที่เพิ่งสำเร็จซ้ำ', () {
      final offer = selectNextGoalOffer(
        goals: <NextGoalOfferInput>[
          _goal('first'),
          _goal('second'),
          _goal('third', currentSatang: 60000),
        ],
        newlyCompletedGoalIds: const <String>{'first', 'second'},
        unallocatedSatang: 0,
      );

      expect(offer.kind, NextGoalOfferKind.continueExisting);
      expect(offer.goalId, 'third');
    });

    test('Cloud Pocket ไม่นับเป็นเป้าหมายถัดไป', () {
      final offer = selectNextGoalOffer(
        goals: <NextGoalOfferInput>[
          _goal('completed', currentSatang: 100000, completed: true),
          _goal(
            'pocket',
            currentSatang: 50000,
            targetSatang: 0,
            flexible: true,
          ),
        ],
        newlyCompletedGoalIds: const <String>{'completed'},
        unallocatedSatang: 0,
      );

      expect(offer.kind, NextGoalOfferKind.createNew);
    });
  });
}
