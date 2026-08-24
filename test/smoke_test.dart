import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keepkapook/main.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/theme/app_theme.dart';
import 'package:keepkapook/screens/goals_screen.dart';
import 'package:keepkapook/screens/quests_screen.dart';
import 'package:keepkapook/screens/history_screen.dart';
import 'package:keepkapook/screens/settings_screen.dart';
import 'package:keepkapook/screens/ledger_screen.dart';
import 'package:keepkapook/screens/achievements_screen.dart';
import 'package:keepkapook/screens/unallocated_screen.dart';
import 'package:keepkapook/screens/dashboard_screen.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  // ห่อ widget ด้วย MaterialApp + Provider (มี mock data)
  Widget wrap(Widget child, {bool inScaffold = false}) => MaterialApp(
        theme: buildAppTheme(),
        home: ChangeNotifierProvider(
          create: (_) => AppState()..load(),
          child: inScaffold ? Scaffold(body: child) : child,
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('boot แอป (ว่างเปล่า) → onboarding', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState()..load(),
        child: const KeepKapookApp(),
      ),
    );
    await settle(tester);
    expect(find.text('มาทำความรู้จักกัน'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // แต่ละหน้าจอ build ได้ไม่ crash
  final screens = <String, Widget>{
    'Dashboard': const DashboardScreen(),
    'Goals': const GoalsScreen(),
    'Quests': const QuestsScreen(),
    'History': const HistoryScreen(),
    'Settings': const SettingsScreen(),
    'Ledger': const LedgerScreen(),
    'Achievements': const AchievementsScreen(),
    'Unallocated': const UnallocatedScreen(),
  };

  screens.forEach((name, widget) {
    testWidgets('หน้า $name build ไม่ crash', (tester) async {
      await tester.pumpWidget(wrap(widget, inScaffold: name == 'Dashboard'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
