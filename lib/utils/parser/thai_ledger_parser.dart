import '../format.dart';
import 'date_parser.dart';
import 'money_extractor.dart';
import 'normalizer.dart';
import 'parser_dictionary.dart';
import 'parser_models.dart';

ParseResult parseThaiLedgerLine(
  String input, {
  required DateTime referenceDate,
  List<String> availableGoalNames = const [],
}) {
  final normalized = normalizeThaiLedgerInput(input);
  final detected = extractDetectedAmounts(normalized);
  final date = parseLedgerDate(normalized, referenceDate);

  if (normalized.isEmpty || detected.isEmpty) {
    return _reject(
      input,
      normalized,
      detected,
      'ไม่พบจำนวนเงิน กรุณาใส่ยอดที่ต้องการบันทึก',
      date,
    );
  }

  final moneyCandidates = detected
      .where((amount) => !amount.isOperatorOperand)
      .toList(growable: false);
  if (moneyCandidates.isEmpty) {
    return _reject(
      input,
      normalized,
      detected,
      'ไม่พบจำนวนเงินหลักที่ต้องการบันทึก',
      date,
    );
  }
  if (moneyCandidates.any((amount) => amount.raw.startsWith('-'))) {
    return _reject(
      input,
      normalized,
      detected,
      'จำนวนเงินต้องไม่ติดลบ',
      date,
    );
  }
  if (moneyCandidates.any((amount) => amount.amountSatang == null)) {
    return _reject(
      input,
      normalized,
      detected,
      'รูปแบบจำนวนเงินไม่ถูกต้องหรือมีขนาดใหญ่เกินไป',
      date,
    );
  }
  if (moneyCandidates.any((amount) => amount.amountSatang == 0)) {
    return _reject(
      input,
      normalized,
      detected,
      'จำนวนเงินต้องมากกว่า 0',
      date,
    );
  }
  if (moneyCandidates.any(
    (amount) => amount.amountSatang! > maxMoneyInputSatang,
  )) {
    return _reject(
      input,
      normalized,
      detected,
      'จำนวนเงินต้องไม่เกิน 100,000,000 บาทต่อรายการ',
      date,
    );
  }

  final ambiguity = _ambiguityFor(normalized);
  if (ambiguity != null) {
    return ParseResult(
      originalInput: input,
      normalizedInput: normalized,
      items: const [],
      detectedAmounts: detected,
      confidence: FieldConfidence(
        amount: 0.99,
        type: 0.2,
        category: 0.2,
        date: date.confidence,
      ),
      tier: ParseTier.low,
      question: ambiguity,
    );
  }

  final resolved = _resolveOperator(normalized, moneyCandidates, detected);
  if (resolved.error != null) {
    return _reject(
      input,
      normalized,
      detected,
      resolved.error!,
      date,
    );
  }

  if (resolved.amountSatang != null) {
    return _singleItemResult(
      originalInput: input,
      normalized: normalized,
      detected: detected,
      amountSatang: resolved.amountSatang!,
      date: date,
      availableGoalNames: availableGoalNames,
    );
  }

  if (moneyCandidates.length > 1) {
    return _multipleItemResult(
      originalInput: input,
      normalized: normalized,
      detected: detected,
      candidates: moneyCandidates,
      date: date,
    );
  }

  return _singleItemResult(
    originalInput: input,
    normalized: normalized,
    detected: detected,
    amountSatang: moneyCandidates.single.amountSatang!,
    date: date,
    availableGoalNames: availableGoalNames,
  );
}

ParseResult _singleItemResult({
  required String originalInput,
  required String normalized,
  required List<DetectedAmount> detected,
  required int amountSatang,
  required ParsedDate date,
  required List<String> availableGoalNames,
}) {
  if (amountSatang <= 0) {
    return _reject(
      originalInput,
      normalized,
      detected,
      'จำนวนเงินต้องมากกว่า 0',
      date,
    );
  }
  if (amountSatang > maxMoneyInputSatang) {
    return _reject(
      originalInput,
      normalized,
      detected,
      'จำนวนเงินต้องไม่เกิน 100,000,000 บาทต่อรายการ',
      date,
    );
  }

  final classification = _classify(normalized);
  if (classification.type == null) {
    return ParseResult(
      originalInput: originalInput,
      normalizedInput: normalized,
      items: const [],
      detectedAmounts: detected,
      confidence: FieldConfidence(
        amount: 0.99,
        type: 0.2,
        category: classification.category == null ? 0.2 : 0.9,
        date: date.confidence,
      ),
      tier: ParseTier.low,
      question: unknownTypeQuestion,
    );
  }

  final category = classification.category ?? 'อื่น ๆ';
  final categoryConfidence =
      classification.category == null ? 0.5 : classification.categoryConfidence;
  final confidence = FieldConfidence(
    amount: 0.99,
    type: classification.typeConfidence,
    category: categoryConfidence,
    date: date.confidence,
  );
  final item = ParsedLedgerItem(
    amountSatang: amountSatang,
    type: classification.type!,
    category: category,
    date: date.value,
    description: _descriptionFrom(normalized),
    confidence: confidence,
  );

  if (item.type == ParsedEntryType.goalDeposit &&
      availableGoalNames.length > 1) {
    return ParseResult(
      originalInput: originalInput,
      normalizedInput: normalized,
      items: [item],
      detectedAmounts: detected,
      confidence: confidence,
      tier: ParseTier.low,
      question: ParseQuestion(
        prompt: 'ต้องการเก็บเงินเข้ากระปุกไหน?',
        options: [
          for (var index = 0; index < availableGoalNames.length; index++)
            ParseOption(
              id: 'goal_$index',
              label: availableGoalNames[index],
            ),
          const ParseOption(id: 'cancel', label: 'ยกเลิก'),
        ],
      ),
    );
  }

  return ParseResult(
    originalInput: originalInput,
    normalizedInput: normalized,
    items: [item],
    detectedAmounts: detected,
    confidence: confidence,
    tier: _tierFor(confidence),
  );
}

ParseResult _multipleItemResult({
  required String originalInput,
  required String normalized,
  required List<DetectedAmount> detected,
  required List<DetectedAmount> candidates,
  required ParsedDate date,
}) {
  final items = <ParsedLedgerItem>[];
  var previousEnd = 0;

  for (final candidate in candidates) {
    final segment = normalized.substring(previousEnd, candidate.start).trim();
    previousEnd = candidate.end;
    final classification = _classify(segment);
    if (segment.isEmpty ||
        classification.type == null ||
        classification.category == null) {
      return ParseResult(
        originalInput: originalInput,
        normalizedInput: normalized,
        items: const [],
        detectedAmounts: detected,
        confidence: FieldConfidence(
          amount: 0.99,
          type: 0.4,
          category: 0.3,
          date: date.confidence,
        ),
        tier: ParseTier.low,
        question: _multipleAmountsQuestion(candidates.length),
      );
    }

    final confidence = FieldConfidence(
      amount: 0.99,
      type: classification.typeConfidence,
      category: classification.categoryConfidence,
      date: date.confidence,
    );
    items.add(
      ParsedLedgerItem(
        amountSatang: candidate.amountSatang!,
        type: classification.type!,
        category: classification.category!,
        date: date.value,
        description: _descriptionFrom(segment),
        confidence: confidence,
      ),
    );
  }

  return ParseResult(
    originalInput: originalInput,
    normalizedInput: normalized,
    items: items,
    detectedAmounts: detected,
    confidence: FieldConfidence.minimum(
      items.map((item) => item.confidence),
    ),
    tier: ParseTier.low,
    question: _multipleAmountsQuestion(items.length),
  );
}

_ResolvedAmount _resolveOperator(
  String normalized,
  List<DetectedAmount> moneyCandidates,
  List<DetectedAmount> allDetected,
) {
  final reducedAt = normalized.indexOf('ลดเหลือ');
  if (reducedAt >= 0) {
    final finalAmounts = moneyCandidates
        .where((amount) => amount.start > reducedAt)
        .toList(growable: false);
    if (finalAmounts.length != 1) {
      return const _ResolvedAmount(
          error: 'ไม่แน่ใจว่ายอดหลังลดเหลือคือจำนวนใด');
    }
    return _ResolvedAmount(amountSatang: finalAmounts.single.amountSatang);
  }

  final paidAt = normalized.lastIndexOf('จ่ายไป');
  if (paidAt >= 0 && moneyCandidates.length > 1) {
    final paidAmounts = moneyCandidates
        .where((amount) => amount.start > paidAt)
        .toList(growable: false);
    if (paidAmounts.length == 1) {
      return _ResolvedAmount(amountSatang: paidAmounts.single.amountSatang);
    }
    return const _ResolvedAmount(error: 'ไม่แน่ใจว่ายอดที่จ่ายจริงคือจำนวนใด');
  }

  final multiply = RegExp(r'(?:x|×)\s*(\d+)').firstMatch(normalized);
  if (multiply != null) {
    final base = _lastAmountBefore(moneyCandidates, multiply.start);
    final factor = int.tryParse(multiply.group(1)!);
    if (base == null || factor == null || factor <= 0) {
      return const _ResolvedAmount(error: 'รูปแบบตัวคูณไม่ถูกต้อง');
    }
    final result = BigInt.from(base.amountSatang!) * BigInt.from(factor);
    if (result > BigInt.from(maxMoneyInputSatang)) {
      return const _ResolvedAmount(error: 'ยอดหลังคูณเกิน 100,000,000 บาท');
    }
    return _ResolvedAmount(amountSatang: result.toInt());
  }

  final divide = RegExp(r'หาร\s*(\d+)').firstMatch(normalized);
  if (divide != null) {
    final base = _lastAmountBefore(moneyCandidates, divide.start);
    final divisor = int.tryParse(divide.group(1)!);
    if (base == null || divisor == null || divisor <= 0) {
      return const _ResolvedAmount(error: 'ตัวหารต้องมากกว่า 0');
    }
    return _ResolvedAmount(
      amountSatang: _divideHalfUp(base.amountSatang!, divisor),
    );
  }

  if (moneyCandidates.length == 1) {
    return _ResolvedAmount(amountSatang: moneyCandidates.single.amountSatang);
  }

  // ยืนยันว่าเลข operand ถูก tag แล้ว แม้ตอนนี้ caller ยังไม่ต้องใช้ค่าโดยตรง
  assert(allDetected.length >= moneyCandidates.length);
  return const _ResolvedAmount();
}

DetectedAmount? _lastAmountBefore(
  List<DetectedAmount> candidates,
  int position,
) {
  DetectedAmount? result;
  for (final candidate in candidates) {
    if (candidate.end <= position) result = candidate;
  }
  return result;
}

int _divideHalfUp(int amountSatang, int divisor) {
  final quotient = amountSatang ~/ divisor;
  final remainder = amountSatang % divisor;
  return remainder * 2 >= divisor ? quotient + 1 : quotient;
}

_Classification _classify(String input) {
  ParsedEntryType? type;
  var typeConfidence = 0.2;
  for (final rule in typeKeywordRules) {
    if (rule.keywords.any(input.contains)) {
      type = rule.value;
      typeConfidence = 1;
      break;
    }
  }

  CategoryRule? matchedCategory;
  for (final rule in categoryKeywordRules) {
    if (rule.keywords.any(input.contains)) {
      matchedCategory = rule;
      break;
    }
  }

  if (type == null && matchedCategory != null) {
    type = matchedCategory.impliedType;
    typeConfidence = 0.96;
  }
  return _Classification(
    type: type,
    category: matchedCategory?.category,
    typeConfidence: typeConfidence,
    categoryConfidence: matchedCategory == null ? 0.2 : 0.98,
  );
}

ParseQuestion? _ambiguityFor(String input) {
  final hasClearGoal = typeKeywordRules.first.keywords.any(input.contains);
  if (input.contains('โอน') && !hasClearGoal) return transferQuestion;
  if (input.contains('คืนเงินเพื่อน')) return repaymentQuestion;
  if (input.contains('ยืมเพื่อน')) return lendingQuestion;
  return null;
}

ParseQuestion _multipleAmountsQuestion(int count) {
  return ParseQuestion(
    prompt: 'พบ $count จำนวนเงิน ต้องการแยกเป็นหลายรายการหรือไม่?',
    options: const [
      ParseOption(id: 'split', label: 'แยกเป็นหลายรายการ'),
      ParseOption(id: 'combine', label: 'รวมเป็นรายการเดียว'),
      ParseOption(id: 'cancel', label: 'ยกเลิก'),
    ],
  );
}

ParseTier _tierFor(FieldConfidence confidence) {
  if (confidence.amount >= 0.98 &&
      confidence.type >= 0.95 &&
      confidence.category >= 0.9 &&
      confidence.date >= 0.7) {
    return ParseTier.high;
  }
  if (confidence.amount >= 0.98 && confidence.type >= 0.95) {
    return ParseTier.medium;
  }
  return ParseTier.low;
}

String _descriptionFrom(String input) {
  var description = input
      .replaceAll(RegExp(r'-?\d+(?:\.\d+)?'), ' ')
      .replaceAll(RegExp(r'เมื่อวานซืน|เมื่อวาน|วันนี้'), ' ')
      .replaceAll(
          RegExp(
              r'(?:วัน)?(?:จันทร์|อังคาร|พุธ|พฤหัสบดี|พฤหัส|ศุกร์|เสาร์|อาทิตย์)ที่แล้ว'),
          ' ')
      .replaceAll(RegExp(r'(?:x|×|หาร|ลดเหลือ)'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (description.isEmpty) description = input.trim();
  return description;
}

ParseResult _reject(
  String originalInput,
  String normalized,
  List<DetectedAmount> detected,
  String reason,
  ParsedDate date,
) {
  return ParseResult(
    originalInput: originalInput,
    normalizedInput: normalized,
    items: const [],
    detectedAmounts: detected,
    confidence: FieldConfidence(
      amount: detected.isEmpty ? 0 : 0.4,
      type: 0,
      category: 0,
      date: date.confidence,
    ),
    tier: ParseTier.reject,
    rejectReason: reason,
  );
}

class _Classification {
  const _Classification({
    required this.type,
    required this.category,
    required this.typeConfidence,
    required this.categoryConfidence,
  });

  final ParsedEntryType? type;
  final String? category;
  final double typeConfidence;
  final double categoryConfidence;
}

class _ResolvedAmount {
  const _ResolvedAmount({this.amountSatang, this.error});

  final int? amountSatang;
  final String? error;
}
