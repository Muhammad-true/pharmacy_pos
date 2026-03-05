import '../../features/shared/models/manufacturer.dart';

/// Интерфейс репозитория для работы с производителями
abstract class IManufacturerRepository {
  /// Получить всех производителей
  Future<List<Manufacturer>> getAllManufacturers();

  /// Получить производителя по ID
  Future<Manufacturer?> getManufacturerById(int id);

  /// Получить производителя по имени
  Future<Manufacturer?> getManufacturerByName(String name);

  /// Создать производителя
  Future<Manufacturer> createManufacturer(Manufacturer manufacturer);

  /// Обновить производителя
  Future<Manufacturer> updateManufacturer(Manufacturer manufacturer);

  /// Удалить производителя
  Future<void> deleteManufacturer(int id);

  /// Проверить существование производителя
  Future<bool> manufacturerExists(String name);
}

