import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/screens/settings_screen.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/theme/app_theme.dart';
import 'package:keepkapook/utils/parser/parser.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Settings แสดง metrics ทั้งหมดและปิด/ล้าง corpus ได้',
      (tester) async {
    final now = DateTime.utc(2026, 1, 29);
    final app = AppState(now: () => now)
      ..loaded = true
      ..user = AppUser(name: 'เมย์', onboarded: true);
    app.recordQuickEntryResult(
      ParseTier.reject,
      'ข้าว',
      occurredAt: now,
    );
    app.recordNextGoalDecision(accepted: true);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const Key('local-metrics-card')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('ข้อมูลการใช้งานในเครื่อง'), findsOneWidget);
    expect(find.text('W4 logging retention'), findsOneWidget);
    expect(find.text('บันทึกการออม'), findsOneWidget);
    expect(find.text('บันทึกรายจ่าย'), findsOneWidget);
    expect(find.textContaining('ไม่ถูกส่งออกอัตโนมัติ'), findsOneWidget);

    final corpusToggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('parser-corpus-toggle'), skipOffstage: false),
    );
    corpusToggle.onChanged!(false);
    await tester.pump();
    expect(app.localMetrics.parserCorpusCollectionEnabled, isFalse);

    expect(
      find.text('ข้อความที่เก็บไว้ 1 ประโยค', skipOffstage: false),
      findsOneWidget,
    );
    app.clearParserCorpus();
    await tester.pump();
    expect(app.localMetrics.parserCorpus, isEmpty);
    await app.flushPendingSaves();
  });
}
