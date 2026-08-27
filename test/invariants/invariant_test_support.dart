import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime invariantTime = DateTime.utc(2026, 8, 27, 12);

void configureInvariantTestEnvironment() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });
}

Goal invariantGoal({
  required String id,
  required String name,
  required int targetSatang,
  int currentSatang = 0,
  bool flexible = false,
}) =>
    Goal(
      id: id,
      name: name,
      targetSatang: targetSatang,
      currentSatang: currentSatang,
      startDate: invariantTime,
      targetDate: invariantTime.add(const Duration(days: 90)),
      flexible: flexible,
    );

int invariantTotal(AppState app) => app.goals.fold<int>(
      app.unallocatedSatang,
      (sum, goal) => sum + goal.currentSatang,
    );

String invariantStateJson(AppState app) => jsonEncode(app.toJson());

Future<AppState> loadEmptyInvariantApp() async {
  final app = AppState();
  await app.load();
  return app;
}
