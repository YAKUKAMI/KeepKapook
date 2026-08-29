import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/product_events.dart';

const productEventStorageKey = 'keepkapook_product_events_v1';

abstract interface class ProductEventStore {
  Future<void> record(ProductEventRecord event);
  Future<List<ProductEventRecord>> readAll();
}

class SharedPreferencesProductEventStore implements ProductEventStore {
  @override
  Future<void> record(ProductEventRecord event) async {
    final preferences = await SharedPreferences.getInstance();
    final existing = await readAll();
    final updated = appendProductEvent(existing, event);
    final encoded = jsonEncode(
      updated.map((record) => record.toJson()).toList(growable: false),
    );
    final saved = await preferences.setString(productEventStorageKey, encoded);
    if (!saved) throw StateError('บันทึก product event ไม่สำเร็จ');
  }

  @override
  Future<List<ProductEventRecord>> readAll() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(productEventStorageKey);
    if (raw == null) return const <ProductEventRecord>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <ProductEventRecord>[];
      return List<ProductEventRecord>.unmodifiable(
        decoded.map(
          (entry) => ProductEventRecord.fromJson(
            Map<String, dynamic>.from(entry as Map),
          ),
        ),
      );
    } on FormatException {
      return const <ProductEventRecord>[];
    } on TypeError {
      return const <ProductEventRecord>[];
    }
  }
}
