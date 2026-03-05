import 'package:drift/drift.dart';

import '../database.dart';

part 'manufacturers_dao.g.dart';

/// DAO для работы с производителями
@DriftAccessor(tables: [Manufacturers])
class ManufacturersDao extends DatabaseAccessor<AppDatabase>
    with _$ManufacturersDaoMixin {
  ManufacturersDao(super.db);

  /// Получить всех производителей
  Future<List<Manufacturer>> getAllManufacturers() async {
    return await (select(
      manufacturers,
    )..orderBy([(m) => OrderingTerm.asc(m.name)])).get();
  }

  /// Получить производителя по ID
  Future<Manufacturer?> getManufacturerById(int id) async {
    return await (select(
      manufacturers,
    )..where((m) => m.id.equals(id))).getSingleOrNull();
  }

  /// Получить производителя по имени
  Future<Manufacturer?> getManufacturerByName(String name) async {
    return await (select(
      manufacturers,
    )..where((m) => m.name.equals(name))).getSingleOrNull();
  }

  /// Создать производителя
  Future<int> insertManufacturer(ManufacturersCompanion manufacturer) async {
    return await into(manufacturers).insert(manufacturer);
  }

  /// Обновить производителя
  Future<bool> updateManufacturer(Manufacturer manufacturer) async {
    return await update(manufacturers).replace(manufacturer);
  }

  /// Удалить производителя
  Future<int> deleteManufacturer(int id) async {
    return await (delete(manufacturers)..where((m) => m.id.equals(id))).go();
  }

  /// Проверка существования производителя
  Future<bool> manufacturerExists(String name) async {
    final manufacturer = await getManufacturerByName(name);
    return manufacturer != null;
  }
}
