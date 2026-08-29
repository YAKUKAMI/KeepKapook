enum ProductEventName {
  nextGoalOfferAccepted,
  nextGoalOfferDeferred,
}

class ProductEventRecord {
  const ProductEventRecord({
    required this.name,
    required this.occurredAt,
    this.properties = const <String, String>{},
  });

  final ProductEventName name;
  final DateTime occurredAt;
  final Map<String, String> properties;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name.name,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'properties': properties,
      };

  factory ProductEventRecord.fromJson(Map<String, dynamic> json) {
    final rawName = json['name']?.toString();
    final name = ProductEventName.values
        .where((candidate) => candidate.name == rawName)
        .firstOrNull;
    final occurredAt = DateTime.tryParse(json['occurredAt']?.toString() ?? '');
    if (name == null || occurredAt == null) {
      throw const FormatException('product event ไม่ถูกต้อง');
    }
    final rawProperties = json['properties'];
    final properties = rawProperties is Map
        ? rawProperties.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : const <String, String>{};
    return ProductEventRecord(
      name: name,
      occurredAt: occurredAt.toUtc(),
      properties: Map<String, String>.unmodifiable(properties),
    );
  }
}

List<ProductEventRecord> appendProductEvent(
  Iterable<ProductEventRecord> existing,
  ProductEventRecord event, {
  int limit = 500,
}) {
  if (limit <= 0) return const <ProductEventRecord>[];
  final events = <ProductEventRecord>[...existing, event];
  final start = events.length > limit ? events.length - limit : 0;
  return List<ProductEventRecord>.unmodifiable(events.sublist(start));
}

class NextGoalOfferEventSummary {
  const NextGoalOfferEventSummary({
    required this.accepted,
    required this.deferred,
  });

  final int accepted;
  final int deferred;
  int get totalDecisions => accepted + deferred;
  double get acceptedRate =>
      totalDecisions == 0 ? 0 : accepted / totalDecisions;
  double get deferredRate =>
      totalDecisions == 0 ? 0 : deferred / totalDecisions;
}

NextGoalOfferEventSummary summarizeNextGoalOfferEvents(
  Iterable<ProductEventRecord> events,
) {
  var accepted = 0;
  var deferred = 0;
  for (final event in events) {
    switch (event.name) {
      case ProductEventName.nextGoalOfferAccepted:
        accepted++;
      case ProductEventName.nextGoalOfferDeferred:
        deferred++;
    }
  }
  return NextGoalOfferEventSummary(accepted: accepted, deferred: deferred);
}
