import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/services/product_event_store.dart';
import 'package:keepkapook/utils/product_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('เก็บ event รับข้อเสนอและไว้ก่อนโดยไม่เก็บข้อมูลการเงิน', () async {
    final store = SharedPreferencesProductEventStore();
    await store.record(
      ProductEventRecord(
        name: ProductEventName.nextGoalOfferAccepted,
        occurredAt: DateTime.utc(2026, 8, 29, 2),
        properties: const <String, String>{'offerKind': 'continueExisting'},
      ),
    );
    await store.record(
      ProductEventRecord(
        name: ProductEventName.nextGoalOfferDeferred,
        occurredAt: DateTime.utc(2026, 8, 29, 3),
        properties: const <String, String>{'offerKind': 'createNew'},
      ),
    );

    final events = await store.readAll();
    final summary = summarizeNextGoalOfferEvents(events);
    expect(summary.accepted, 1);
    expect(summary.deferred, 1);
    expect(summary.totalDecisions, 2);
    expect(summary.acceptedRate, 0.5);
    expect(summary.deferredRate, 0.5);
    expect(events.first.toJson().toString(), isNot(contains('amount')));
    expect(events.first.toJson().toString(), isNot(contains('goalId')));
  });

  test('event JSON ที่พังไม่ทำให้ celebration crash', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      productEventStorageKey: 'not-json',
    });
    final store = SharedPreferencesProductEventStore();

    expect(await store.readAll(), isEmpty);
  });
}
