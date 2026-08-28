import 'package:flutter/foundation.dart';

import '../../utils/format.dart';
import '../../utils/quick_entry.dart';
import 'quick_entry_preferences_store.dart';

class QuickEntryController extends ChangeNotifier {
  QuickEntryController({QuickEntryPreferencesStore? store})
      : _store = store ?? const SharedPreferencesQuickEntryPreferencesStore();

  final QuickEntryPreferencesStore _store;

  QuickEntryPreferences preferences = const QuickEntryPreferences();
  bool loaded = false;
  String? errorMessage;

  List<int> get savingAmountsSatang => preferences.savingAmountsSatang;
  String get lastExpenseCategory => preferences.lastExpenseCategory;

  Future<void> load() async {
    try {
      preferences = await _store.load();
    } catch (_) {
      preferences = const QuickEntryPreferences();
      errorMessage =
          'โหลดการตั้งค่าทางลัดไม่สำเร็จ จึงใช้ค่าเริ่มต้น 20 / 50 / 100';
    } finally {
      loaded = true;
      notifyListeners();
    }
  }

  Future<bool> updateSavingAmounts(List<int> amountsSatang) async {
    final error = validateQuickSavingAmounts(amountsSatang);
    if (error != null) {
      errorMessage = error;
      notifyListeners();
      return false;
    }
    final previous = preferences;
    preferences = preferences.copyWith(
      savingAmountsSatang: List<int>.unmodifiable(amountsSatang),
    );
    notifyListeners();
    return _persistOrRestore(previous);
  }

  Future<bool> rememberExpenseCategory(String category) async {
    if (!expenseCategories.contains(category)) return false;
    if (category == preferences.lastExpenseCategory) return true;
    final previous = preferences;
    preferences = preferences.copyWith(lastExpenseCategory: category);
    notifyListeners();
    return _persistOrRestore(previous);
  }

  Future<bool> _persistOrRestore(QuickEntryPreferences previous) async {
    try {
      await _store.save(preferences);
      errorMessage = null;
      return true;
    } catch (_) {
      preferences = previous;
      errorMessage = 'บันทึกการตั้งค่าทางลัดไม่สำเร็จ กรุณาลองอีกครั้ง';
      notifyListeners();
      return false;
    }
  }
}
