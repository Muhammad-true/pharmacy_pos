import 'package:drift/drift.dart';

import '../database.dart';

part 'settings_dao.g.dart';

/// DAO для работы с настройками
@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  /// Получить значение настройки по ключу
  Future<String?> getSetting(String key) async {
    final setting = await (select(
      settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return setting?.value;
  }

  /// Установить значение настройки
  Future<void> setSetting(String key, String value) async {
    final existing = await (select(
      settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();

    if (existing != null) {
      // Обновляем существующую настройку
      await (update(settings)..where((s) => s.key.equals(key))).write(
        SettingsCompanion(
          value: Value(value),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } else {
      // Создаем новую настройку
      await into(
        settings,
      ).insert(SettingsCompanion(key: Value(key), value: Value(value)));
    }
  }

  /// Получить все настройки
  Future<Map<String, String>> getAllSettings() async {
    final allSettings = await select(settings).get();
    return {for (var s in allSettings) s.key: s.value};
  }

  /// Удалить настройку
  Future<void> deleteSetting(String key) async {
    await (delete(settings)..where((s) => s.key.equals(key))).go();
  }
}
