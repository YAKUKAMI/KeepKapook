import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/format.dart';
import '../../utils/quick_entry.dart';

const quickSavingAmountsKey = 'keepkapook_quick_saving_amounts_satang';
const quickExpenseCategoryKey = 'keepkapook_quick_expense_category';

class QuickEntryPreferences {
  const QuickEntryPreferences({
    this.savingAmountsSatang = defaultQuickSavingAmountsSatang,
    this.lastExpenseCategory = 'อาหาร',
  });

  final List<int> savingAmountsSatang;
  final String lastExpenseCategory;

  QuickEntryPreferences copyWith({
    List<int>? savingAmountsSatang,
    String? lastExpenseCategory,
  }) {
    return QuickEntryPreferences(
      savingAmountsSatang: savingAmountsSatang ?? this.savingAmountsSatang,
      lastExpenseCategory: lastExpenseCategory ?? this.lastExpenseCategory,
    );
  }
}

abstract interface class QuickEntryPreferencesStore {
  Future<QuickEntryPreferences> load();

  Future<void> save(QuickEntryPreferences preferences);
}

class SharedPreferencesQuickEntryPreferencesStore
    implements QuickEntryPreferencesStore {
  const SharedPreferencesQuickEntryPreferencesStore();

  @override
  Future<QuickEntryPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored =
        prefs.getStringList(quickSavingAmountsKey) ?? const <String>[];
    final parsed = stored.map(int.tryParse).whereType<int>().toList();
    final category = prefs.getString(quickExpenseCategoryKey);
    return QuickEntryPreferences(
      savingAmountsSatang: validQuickSavingAmountsOrDefault(parsed),
      lastExpenseCategory:
          expenseCategories.contains(category) ? category! : 'อาหาร',
    );
  }

  @override
  Future<void> save(QuickEntryPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    final results = await Future.wait(<Future<bool>>[
      prefs.setStringList(
        quickSavingAmountsKey,
        preferences.savingAmountsSatang.map((amount) => '$amount').toList(),
      ),
      prefs.setString(
        quickExpenseCategoryKey,
        preferences.lastExpenseCategory,
      ),
    ]);
    if (results.any((saved) => !saved)) {
      throw StateError('บันทึกการตั้งค่าทางลัดไม่สำเร็จ');
    }
  }
}
