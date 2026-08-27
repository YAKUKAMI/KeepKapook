import '../utils/format.dart';

class DomainValidationException implements Exception {
  const DomainValidationException(this.code, this.message);

  final String code;
  final String message;

  factory DomainValidationException.invalidAmount(String fieldName) =>
      DomainValidationException(
        'invalid_amount',
        '$fieldName ต้องเป็นจำนวนเต็มสตางค์ที่มากกว่า 0 '
            'และไม่เกินเพดานต่อรายการ',
      );

  factory DomainValidationException.missingGoal(String goalId) =>
      DomainValidationException(
        'missing_goal',
        'ไม่พบกระปุก id "$goalId"',
      );

  factory DomainValidationException.sameGoalTransfer() =>
      const DomainValidationException(
        'same_goal_transfer',
        'กระปุกต้นทางและปลายทางต้องไม่ใช่กระปุกเดียวกัน',
      );

  factory DomainValidationException.missingEntity(
    String entityName,
    String id,
  ) =>
      DomainValidationException(
        'missing_entity',
        'ไม่พบ$entityName id "$id"',
      );

  factory DomainValidationException.operationNotAllowed(String message) =>
      DomainValidationException('operation_not_allowed', message);

  @override
  String toString() => 'DomainValidationException($code): $message';
}

int validateMoneyAmountSatang(
  num value, {
  String fieldName = 'amountSatang',
}) {
  if (!value.isFinite ||
      value is! int ||
      value <= 0 ||
      value > maxMoneyInputSatang) {
    throw DomainValidationException.invalidAmount(fieldName);
  }
  return value;
}
