import 'habit_streak.dart';

const int maxParserCorpusSamples = 200;

enum LoggingKind { saving, expense, other }

enum MetricQuickEntryTier { high, medium, low, reject }

enum ParserCorpusReason { low, reject, corrected }

enum W4LoggingRetentionStatus { waiting, retained, notRetained }

class ParserCorpusSample {
  const ParserCorpusSample({
    required this.input,
    required this.reason,
    required this.recordedDay,
  });

  final String input;
  final ParserCorpusReason reason;
  final String recordedDay;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'input': input,
        'reason': reason.name,
        'recordedDay': recordedDay,
      };

  factory ParserCorpusSample.fromJson(Map<String, dynamic> json) {
    final rawReason = json['reason']?.toString();
    final reason = ParserCorpusReason.values
        .where((candidate) => candidate.name == rawReason)
        .firstOrNull;
    return ParserCorpusSample(
      input: json['input']?.toString() ?? '',
      reason: reason ?? ParserCorpusReason.reject,
      recordedDay: json['recordedDay']?.toString() ?? '',
    );
  }
}

class LocalMetrics {
  const LocalMetrics({
    required this.installedDay,
    required this.recordingDays,
    required this.quickEntryTierCounts,
    required this.undoCount,
    required this.correctionCount,
    required this.weeklyReviewOpenCount,
    required this.recoveryPlanAcceptedCount,
    required this.nextGoalOfferAcceptedCount,
    required this.nextGoalOfferDeferredCount,
    required this.savingRecordCount,
    required this.expenseRecordCount,
    required this.parserCorpusCollectionEnabled,
    required this.parserCorpus,
  });

  factory LocalMetrics.empty({required DateTime installedAt}) => LocalMetrics(
        installedDay: metricDayKey(installedAt),
        recordingDays: const <String>{},
        quickEntryTierCounts: const <MetricQuickEntryTier, int>{
          MetricQuickEntryTier.high: 0,
          MetricQuickEntryTier.medium: 0,
          MetricQuickEntryTier.low: 0,
          MetricQuickEntryTier.reject: 0,
        },
        undoCount: 0,
        correctionCount: 0,
        weeklyReviewOpenCount: 0,
        recoveryPlanAcceptedCount: 0,
        nextGoalOfferAcceptedCount: 0,
        nextGoalOfferDeferredCount: 0,
        savingRecordCount: 0,
        expenseRecordCount: 0,
        parserCorpusCollectionEnabled: true,
        parserCorpus: const <ParserCorpusSample>[],
      );

  final String installedDay;
  final Set<String> recordingDays;
  final Map<MetricQuickEntryTier, int> quickEntryTierCounts;
  final int undoCount;
  final int correctionCount;
  final int weeklyReviewOpenCount;
  final int recoveryPlanAcceptedCount;
  final int nextGoalOfferAcceptedCount;
  final int nextGoalOfferDeferredCount;
  final int savingRecordCount;
  final int expenseRecordCount;
  final bool parserCorpusCollectionEnabled;
  final List<ParserCorpusSample> parserCorpus;

  double get nextGoalOfferAcceptanceRate {
    return nextGoalOfferDecisionCount == 0
        ? 0
        : nextGoalOfferAcceptedCount / nextGoalOfferDecisionCount;
  }

  int get nextGoalOfferDecisionCount =>
      nextGoalOfferAcceptedCount + nextGoalOfferDeferredCount;

  int get nextGoalOfferAcceptancePercent =>
      (nextGoalOfferAcceptanceRate * 100).round();

  LocalMetrics copyWith({
    String? installedDay,
    Set<String>? recordingDays,
    Map<MetricQuickEntryTier, int>? quickEntryTierCounts,
    int? undoCount,
    int? correctionCount,
    int? weeklyReviewOpenCount,
    int? recoveryPlanAcceptedCount,
    int? nextGoalOfferAcceptedCount,
    int? nextGoalOfferDeferredCount,
    int? savingRecordCount,
    int? expenseRecordCount,
    bool? parserCorpusCollectionEnabled,
    List<ParserCorpusSample>? parserCorpus,
  }) =>
      LocalMetrics(
        installedDay: installedDay ?? this.installedDay,
        recordingDays: Set<String>.unmodifiable(
          recordingDays ?? this.recordingDays,
        ),
        quickEntryTierCounts: Map<MetricQuickEntryTier, int>.unmodifiable(
          quickEntryTierCounts ?? this.quickEntryTierCounts,
        ),
        undoCount: undoCount ?? this.undoCount,
        correctionCount: correctionCount ?? this.correctionCount,
        weeklyReviewOpenCount:
            weeklyReviewOpenCount ?? this.weeklyReviewOpenCount,
        recoveryPlanAcceptedCount:
            recoveryPlanAcceptedCount ?? this.recoveryPlanAcceptedCount,
        nextGoalOfferAcceptedCount:
            nextGoalOfferAcceptedCount ?? this.nextGoalOfferAcceptedCount,
        nextGoalOfferDeferredCount:
            nextGoalOfferDeferredCount ?? this.nextGoalOfferDeferredCount,
        savingRecordCount: savingRecordCount ?? this.savingRecordCount,
        expenseRecordCount: expenseRecordCount ?? this.expenseRecordCount,
        parserCorpusCollectionEnabled:
            parserCorpusCollectionEnabled ?? this.parserCorpusCollectionEnabled,
        parserCorpus: List<ParserCorpusSample>.unmodifiable(
          parserCorpus ?? this.parserCorpus,
        ),
      );

  Map<String, dynamic> toJson() {
    final sortedDays = recordingDays.toList()..sort();
    return <String, dynamic>{
      'installedDay': installedDay,
      'recordingDays': sortedDays,
      'quickEntryTierCounts': <String, int>{
        for (final tier in MetricQuickEntryTier.values)
          tier.name: quickEntryTierCounts[tier] ?? 0,
      },
      'undoCount': undoCount,
      'correctionCount': correctionCount,
      'weeklyReviewOpenCount': weeklyReviewOpenCount,
      'recoveryPlanAcceptedCount': recoveryPlanAcceptedCount,
      'nextGoalOfferAcceptedCount': nextGoalOfferAcceptedCount,
      'nextGoalOfferDeferredCount': nextGoalOfferDeferredCount,
      'savingRecordCount': savingRecordCount,
      'expenseRecordCount': expenseRecordCount,
      'parserCorpusCollectionEnabled': parserCorpusCollectionEnabled,
      'parserCorpus':
          parserCorpus.map((sample) => sample.toJson()).toList(growable: false),
    };
  }

  factory LocalMetrics.fromJson(Map<String, dynamic> json) {
    final rawTierCounts = json['quickEntryTierCounts'];
    final tierCounts = <MetricQuickEntryTier, int>{
      for (final tier in MetricQuickEntryTier.values)
        tier: _nonNegativeInt(
          rawTierCounts is Map ? rawTierCounts[tier.name] : null,
        ),
    };
    final rawCorpus = json['parserCorpus'];
    final corpus = <ParserCorpusSample>[];
    if (rawCorpus is List) {
      for (final rawSample in rawCorpus) {
        if (rawSample is! Map) continue;
        final sample = ParserCorpusSample.fromJson(
          Map<String, dynamic>.from(rawSample),
        );
        if (sample.input.trim().isNotEmpty &&
            DateTime.tryParse(sample.recordedDay) != null) {
          corpus.add(sample);
        }
      }
    }
    final rawDays = json['recordingDays'];
    final days = <String>{};
    if (rawDays is List) {
      for (final rawDay in rawDays) {
        final day = rawDay.toString();
        if (DateTime.tryParse(day) != null) days.add(day);
      }
    }
    return LocalMetrics(
      installedDay: _validDayKey(json['installedDay']) ?? '',
      recordingDays: Set<String>.unmodifiable(days),
      quickEntryTierCounts:
          Map<MetricQuickEntryTier, int>.unmodifiable(tierCounts),
      undoCount: _nonNegativeInt(json['undoCount']),
      correctionCount: _nonNegativeInt(json['correctionCount']),
      weeklyReviewOpenCount: _nonNegativeInt(json['weeklyReviewOpenCount']),
      recoveryPlanAcceptedCount:
          _nonNegativeInt(json['recoveryPlanAcceptedCount']),
      nextGoalOfferAcceptedCount:
          _nonNegativeInt(json['nextGoalOfferAcceptedCount']),
      nextGoalOfferDeferredCount:
          _nonNegativeInt(json['nextGoalOfferDeferredCount']),
      savingRecordCount: _nonNegativeInt(json['savingRecordCount']),
      expenseRecordCount: _nonNegativeInt(json['expenseRecordCount']),
      parserCorpusCollectionEnabled:
          json['parserCorpusCollectionEnabled'] is bool
              ? json['parserCorpusCollectionEnabled'] as bool
              : true,
      parserCorpus: List<ParserCorpusSample>.unmodifiable(
        corpus.length <= maxParserCorpusSamples
            ? corpus
            : corpus.sublist(corpus.length - maxParserCorpusSamples),
      ),
    );
  }
}

class LocalMetricsSummary {
  const LocalMetricsSummary({
    required this.loggingDayCount,
    required this.activeWeekNumbers,
    required this.w4Status,
  });

  final int loggingDayCount;
  final List<int> activeWeekNumbers;
  final W4LoggingRetentionStatus w4Status;

  int get activeLoggingWeekCount => activeWeekNumbers.length;
}

String metricDayKey(DateTime timestamp) =>
    habitDayKey(bangkokLocalDay(timestamp));

LocalMetrics recordLoggingActivity(
  LocalMetrics metrics, {
  required DateTime occurredAt,
  required LoggingKind kind,
}) {
  final days = <String>{...metrics.recordingDays, metricDayKey(occurredAt)};
  return metrics.copyWith(
    recordingDays: days,
    savingRecordCount:
        metrics.savingRecordCount + (kind == LoggingKind.saving ? 1 : 0),
    expenseRecordCount:
        metrics.expenseRecordCount + (kind == LoggingKind.expense ? 1 : 0),
  );
}

LocalMetrics recordQuickEntryAttempt(
  LocalMetrics metrics, {
  required MetricQuickEntryTier tier,
  required String input,
  required DateTime occurredAt,
}) {
  final counts = <MetricQuickEntryTier, int>{...metrics.quickEntryTierCounts};
  counts[tier] = (counts[tier] ?? 0) + 1;
  final reason = switch (tier) {
    MetricQuickEntryTier.low => ParserCorpusReason.low,
    MetricQuickEntryTier.reject => ParserCorpusReason.reject,
    MetricQuickEntryTier.high || MetricQuickEntryTier.medium => null,
  };
  return metrics.copyWith(
    quickEntryTierCounts: counts,
    parserCorpus: reason == null
        ? metrics.parserCorpus
        : _appendCorpusSample(
            metrics,
            input: input,
            reason: reason,
            occurredAt: occurredAt,
          ),
  );
}

LocalMetrics recordUndo(LocalMetrics metrics) =>
    metrics.copyWith(undoCount: metrics.undoCount + 1);

LocalMetrics recordCorrection(
  LocalMetrics metrics, {
  required DateTime occurredAt,
  String? parserInput,
}) =>
    metrics.copyWith(
      correctionCount: metrics.correctionCount + 1,
      parserCorpus: parserInput == null
          ? metrics.parserCorpus
          : _appendCorpusSample(
              metrics,
              input: parserInput,
              reason: ParserCorpusReason.corrected,
              occurredAt: occurredAt,
            ),
    );

LocalMetrics recordWeeklyReviewOpen(LocalMetrics metrics) => metrics.copyWith(
      weeklyReviewOpenCount: metrics.weeklyReviewOpenCount + 1,
    );

LocalMetrics recordRecoveryPlanAccepted(LocalMetrics metrics) =>
    metrics.copyWith(
      recoveryPlanAcceptedCount: metrics.recoveryPlanAcceptedCount + 1,
    );

LocalMetrics recordNextGoalOfferDecision(
  LocalMetrics metrics, {
  required bool accepted,
}) =>
    accepted
        ? metrics.copyWith(
            nextGoalOfferAcceptedCount: metrics.nextGoalOfferAcceptedCount + 1,
          )
        : metrics.copyWith(
            nextGoalOfferDeferredCount: metrics.nextGoalOfferDeferredCount + 1,
          );

LocalMetricsSummary summarizeLocalMetrics(
  LocalMetrics metrics, {
  required DateTime asOf,
}) {
  final installed = DateTime.tryParse(metrics.installedDay);
  final asOfDay = bangkokLocalDay(asOf);
  if (installed == null) {
    return const LocalMetricsSummary(
      loggingDayCount: 0,
      activeWeekNumbers: <int>[],
      w4Status: W4LoggingRetentionStatus.waiting,
    );
  }

  final validDays = metrics.recordingDays
      .map(DateTime.tryParse)
      .whereType<DateTime>()
      .where((day) => !day.isBefore(installed) && !day.isAfter(asOfDay))
      .toSet();
  final activeWeeks = validDays
      .map((day) => day.difference(installed).inDays ~/ 7 + 1)
      .where((week) => week > 0)
      .toSet()
      .toList()
    ..sort();
  final hasCompletedWeekFour = asOfDay.difference(installed).inDays >= 28;
  final w4Status = !hasCompletedWeekFour
      ? W4LoggingRetentionStatus.waiting
      : activeWeeks.contains(4)
          ? W4LoggingRetentionStatus.retained
          : W4LoggingRetentionStatus.notRetained;
  return LocalMetricsSummary(
    loggingDayCount: validDays.length,
    activeWeekNumbers: List<int>.unmodifiable(activeWeeks),
    w4Status: w4Status,
  );
}

List<ParserCorpusSample> _appendCorpusSample(
  LocalMetrics metrics, {
  required String input,
  required ParserCorpusReason reason,
  required DateTime occurredAt,
}) {
  final normalized = input.trim();
  if (!metrics.parserCorpusCollectionEnabled || normalized.isEmpty) {
    return metrics.parserCorpus;
  }
  final day = metricDayKey(occurredAt);
  final duplicate = metrics.parserCorpus.any(
    (sample) =>
        sample.input == normalized &&
        sample.reason == reason &&
        sample.recordedDay == day,
  );
  if (duplicate) return metrics.parserCorpus;
  final updated = <ParserCorpusSample>[
    ...metrics.parserCorpus,
    ParserCorpusSample(input: normalized, reason: reason, recordedDay: day),
  ];
  if (updated.length <= maxParserCorpusSamples) return updated;
  return updated.sublist(updated.length - maxParserCorpusSamples);
}

String? _validDayKey(Object? value) {
  final raw = value?.toString();
  if (raw == null || DateTime.tryParse(raw) == null) return null;
  return raw;
}

int _nonNegativeInt(Object? value) => value is int && value > 0 ? value : 0;
