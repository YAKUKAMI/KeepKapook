import '../models/models.dart';
import 'format.dart';

// สถานะตามแผน + ตัวเลือกกู้แผน (port จากเว็บ lib/coach.ts)

class PlanStatus {
  final bool behind;
  final double shortfall;
  final int onTrackPct;
  PlanStatus(this.behind, this.shortfall, this.onTrackPct);
}

PlanStatus planStatus(Goal g) {
  final total = g.targetDate.difference(g.startDate).inDays.clamp(1, 1 << 30);
  final elapsed =
      DateTime.now().difference(g.startDate).inDays.clamp(0, total);
  final expected =
      (g.targetAmount * elapsed / total).clamp(0, g.targetAmount);
  final shortfall = (expected - g.currentAmount).clamp(0, double.infinity);
  final onTrackPct =
      expected > 0 ? (g.currentAmount / expected * 100).round() : 100;
  return PlanStatus(shortfall > 0, shortfall.toDouble(), onTrackPct);
}

class RecoveryOptions {
  final double catchUpPerDay;
  final int catchUpDays;
  final int extendDays;
  final double reducedTarget;
  RecoveryOptions(
      this.catchUpPerDay, this.catchUpDays, this.extendDays, this.reducedTarget);
}

RecoveryOptions recoveryOptions(Goal g, PlanStatus status, double avgPerDay) {
  final rem = g.remaining;
  final left = daysLeft(g.targetDate).clamp(1, 1 << 30);
  final catchUpDays = left.clamp(3, 7);
  final catchUpPerDay = (status.shortfall / catchUpDays).ceilToDouble();
  final pace = avgPerDay > 0 ? avgPerDay : (rem / left);
  final neededDays = (rem / (pace <= 0 ? 1 : pace)).ceil();
  final extendDays = (neededDays - left).clamp(3, 1 << 30);
  final reachable = g.currentAmount + (pace * left);
  final reducedTarget =
      reachable.clamp(g.currentAmount + 1, g.targetAmount).toDouble();
  return RecoveryOptions(
      catchUpPerDay, catchUpDays, extendDays, reducedTarget);
}
