import '../format.dart';
import 'parser_models.dart';

final _numberPattern = RegExp(r'-?\d+(?:\.\d+)?');

List<DetectedAmount> extractDetectedAmounts(String normalizedInput) {
  return _numberPattern.allMatches(normalizedInput).map((match) {
    final raw = match.group(0)!;
    final prefix = normalizedInput.substring(0, match.start).trimRight();
    final isOperatorOperand =
        prefix.endsWith('x') || prefix.endsWith('×') || prefix.endsWith('หาร');
    return DetectedAmount(
      raw: raw,
      start: match.start,
      end: match.end,
      amountSatang: parseMoneyToSatang(raw, maxSatang: null),
      isOperatorOperand: isOperatorOperand,
    );
  }).toList(growable: false);
}
