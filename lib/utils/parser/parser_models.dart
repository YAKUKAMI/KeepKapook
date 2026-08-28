enum ParsedEntryType { income, expense, goalDeposit }

enum ParseTier { high, medium, low, reject }

class FieldConfidence {
  const FieldConfidence({
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
  })  : assert(amount >= 0 && amount <= 1),
        assert(type >= 0 && type <= 1),
        assert(category >= 0 && category <= 1),
        assert(date >= 0 && date <= 1);

  final double amount;
  final double type;
  final double category;
  final double date;

  static FieldConfidence minimum(Iterable<FieldConfidence> values) {
    final iterator = values.iterator;
    if (!iterator.moveNext()) {
      return const FieldConfidence(amount: 0, type: 0, category: 0, date: 0);
    }

    var amount = iterator.current.amount;
    var type = iterator.current.type;
    var category = iterator.current.category;
    var date = iterator.current.date;
    while (iterator.moveNext()) {
      final current = iterator.current;
      if (current.amount < amount) amount = current.amount;
      if (current.type < type) type = current.type;
      if (current.category < category) category = current.category;
      if (current.date < date) date = current.date;
    }
    return FieldConfidence(
      amount: amount,
      type: type,
      category: category,
      date: date,
    );
  }
}

class DetectedAmount {
  const DetectedAmount({
    required this.raw,
    required this.start,
    required this.end,
    required this.amountSatang,
    required this.isOperatorOperand,
  });

  final String raw;
  final int start;
  final int end;
  final int? amountSatang;
  final bool isOperatorOperand;
}

class ParseOption {
  const ParseOption({required this.id, required this.label});

  final String id;
  final String label;
}

class ParseQuestion {
  const ParseQuestion({required this.prompt, required this.options});

  final String prompt;
  final List<ParseOption> options;
}

class ParsedLedgerItem {
  const ParsedLedgerItem({
    required this.amountSatang,
    required this.type,
    required this.category,
    required this.date,
    required this.description,
    required this.confidence,
  });

  final int amountSatang;
  final ParsedEntryType type;
  final String category;
  final DateTime date;
  final String description;
  final FieldConfidence confidence;
}

class ParseResult {
  const ParseResult({
    required this.originalInput,
    required this.normalizedInput,
    required this.items,
    required this.detectedAmounts,
    required this.confidence,
    required this.tier,
    this.rejectReason,
    this.question,
  });

  final String originalInput;
  final String normalizedInput;
  final List<ParsedLedgerItem> items;
  final List<DetectedAmount> detectedAmounts;
  final FieldConfidence confidence;
  final ParseTier tier;
  final String? rejectReason;
  final ParseQuestion? question;
}
