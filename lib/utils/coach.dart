import '../models/models.dart';
import 'format.dart';

// สถานะตามแผน + ตัวเลือกกู้แผน (port จากเว็บ lib/coach.ts)

class PlanStatus {
  final bool behind;
  final int shortfallSatang;
  final int onTrackPct;
  PlanStatus(this.behind, this.shortfallSatang, this.onTrackPct);
}

int _roundDivisionHalfUp(int numerator, int denominator) {
  if (denominator <= 0) throw ArgumentError.value(denominator, 'denominator');
  return (numerator * 2 + denominator) ~/ (denominator * 2);
}

int _ceilDivision(int numerator, int denominator) {
  if (denominator <= 0) throw ArgumentError.value(denominator, 'denominator');
  return numerator <= 0 ? 0 : (numerator + denominator - 1) ~/ denominator;
}

int _clampInt(int value, int minimum, int maximum) {
  if (value < minimum) return minimum;
  if (value > maximum) return maximum;
  return value;
}

PlanStatus planStatus(Goal g) {
  final total = _clampInt(
    g.targetDate.difference(g.startDate).inDays,
    1,
    1 << 30,
  );
  final elapsed = _clampInt(
    DateTime.now().difference(g.startDate).inDays,
    0,
    total,
  );
  final expectedSatang = _clampInt(
    _roundDivisionHalfUp(g.targetSatang * elapsed, total),
    0,
    g.targetSatang,
  );
  final shortfallSatang = _clampInt(
    expectedSatang - g.currentSatang,
    0,
    g.targetSatang,
  );
  final onTrackPct = expectedSatang > 0
      ? _roundDivisionHalfUp(g.currentSatang * 100, expectedSatang)
      : 100;
  return PlanStatus(shortfallSatang > 0, shortfallSatang, onTrackPct);
}

class RecoveryOptions {
  final int catchUpPerDaySatang;
  final int catchUpDays;
  final int extendDays;
  final int reducedTargetSatang;
  RecoveryOptions(this.catchUpPerDaySatang, this.catchUpDays, this.extendDays,
      this.reducedTargetSatang);
}

RecoveryOptions recoveryOptions(
    Goal g, PlanStatus status, int avgPerDaySatang) {
  final remainingSatang = g.remainingSatang;
  final left = _clampInt(daysLeft(g.targetDate), 1, 1 << 30);
  final catchUpDays = _clampInt(left, 3, 7);
  final catchUpPerDaySatang =
      _ceilDivision(status.shortfallSatang, catchUpDays);
  final paceSatang = avgPerDaySatang > 0
      ? avgPerDaySatang
      : _ceilDivision(remainingSatang, left);
  final neededDays =
      _ceilDivision(remainingSatang, paceSatang <= 0 ? 1 : paceSatang);
  final extendDays = _clampInt(neededDays - left, 3, 1 << 30);
  final reachableSatang = g.currentSatang + (paceSatang * left);
  final minimumTargetSatang =
      _clampInt(g.currentSatang + 1, 0, g.targetSatang);
  final reducedTargetSatang = _clampInt(
    reachableSatang,
    minimumTargetSatang,
    g.targetSatang,
  );
  return RecoveryOptions(catchUpPerDaySatang, catchUpDays, extendDays,
      reducedTargetSatang);
}

int averageDepositPerDaySatang(
  Iterable<SavingTransaction> transactions,
  DateTime startDate, {
  DateTime? now,
}) {
  final depositedSatang = transactions
      .where((transaction) =>
          transaction.type != TxType.withdraw &&
          transaction.type != TxType.adjust)
      .fold<int>(
        0,
        (sum, transaction) => sum + transaction.amountSatang,
      );
  final elapsedDays = _clampInt(
    (now ?? DateTime.now()).difference(startDate).inDays,
    1,
    1 << 30,
  );
  return _roundDivisionHalfUp(depositedSatang, elapsedDays);
}
