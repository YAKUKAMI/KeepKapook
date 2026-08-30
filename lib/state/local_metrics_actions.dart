part of 'app_state.dart';

extension LocalMetricsActions on AppState {
  LocalMetricsSummary localMetricsSummary({required DateTime now}) =>
      summarizeLocalMetrics(localMetrics, asOf: now);

  void recordQuickEntryResult(
    ParseTier tier,
    String input, {
    DateTime? occurredAt,
  }) {
    final metricTier = switch (tier) {
      ParseTier.high => MetricQuickEntryTier.high,
      ParseTier.medium => MetricQuickEntryTier.medium,
      ParseTier.low => MetricQuickEntryTier.low,
      ParseTier.reject => MetricQuickEntryTier.reject,
    };
    localMetrics = recordQuickEntryAttempt(
      localMetrics,
      tier: metricTier,
      input: input,
      occurredAt: occurredAt ?? _now(),
    );
    _saveAndNotify();
  }

  void recordRecoveryPlanUse() {
    localMetrics = recordRecoveryPlanAccepted(localMetrics);
    _saveAndNotify();
  }

  void recordNextGoalDecision({required bool accepted}) {
    localMetrics = recordNextGoalOfferDecision(
      localMetrics,
      accepted: accepted,
    );
    _saveAndNotify();
  }

  void setParserCorpusCollectionEnabled(bool enabled) {
    if (localMetrics.parserCorpusCollectionEnabled == enabled) return;
    localMetrics = localMetrics.copyWith(
      parserCorpusCollectionEnabled: enabled,
    );
    _saveAndNotify();
  }

  void clearParserCorpus() {
    if (localMetrics.parserCorpus.isEmpty) return;
    localMetrics = localMetrics.copyWith(
      parserCorpus: const <ParserCorpusSample>[],
    );
    _saveAndNotify();
  }

  void _recordLoggingMetric(DateTime occurredAt, LoggingKind kind) {
    localMetrics = recordLoggingActivity(
      localMetrics,
      occurredAt: occurredAt,
      kind: kind,
    );
  }

  void _recordUndoMetric() {
    localMetrics = recordUndo(localMetrics);
  }

  void _recordCorrectionMetric({String? parserInput}) {
    localMetrics = recordCorrection(
      localMetrics,
      occurredAt: _now(),
      parserInput: parserInput,
    );
  }

  void _recordWeeklyReviewMetric() {
    localMetrics = recordWeeklyReviewOpen(localMetrics);
  }
}
