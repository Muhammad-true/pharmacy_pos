import '../../features/shared/models/manufacturer.dart';
import '../database/database_provider.dart';
import '../database/database.dart' as db;
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import 'i_manufacturer_repository.dart';
import 'mappers/database_mappers.dart';

/// Реализация репозитория для работы с производителями
class ManufacturerRepository implements IManufacturerRepository {
  final ErrorHandler _errorHandler = ErrorHandler.instance;

  /// Получить БД
  Future<db.AppDatabase> get _database async {
    return await DatabaseProvider.getDatabase();
  }

  @override
  Future<List<Manufacturer>> getAllManufacturers() async {
    try {
      final database = await _database;
      final dbManufacturers = await database.manufacturersDao.getAllManufacturers();
      return dbManufacturers.map(DatabaseMappers.toAppManufacturer).toList();
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения производителей: ${e.toString()}');
    }
  }

  @override
  Future<Manufacturer?> getManufacturerById(int id) async {
    try {
      final database = await _database;
      final dbManufacturer = await database.manufacturersDao.getManufacturerById(id);
      if (dbManufacturer == null) return null;
      return DatabaseMappers.toAppManufacturer(dbManufacturer);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения производителя: ${e.toString()}');
    }
  }

  @override
  Future<Manufacturer?> getManufacturerByName(String name) async {
    try {
      final database = await _database;
      final dbManufacturer = await database.manufacturersDao.getManufacturerByName(name);
      if (dbManufacturer == null) return null;
      return DatabaseMappers.toAppManufacturer(dbManufacturer);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения производителя: ${e.toString()}');
    }
  }

  @override
  Future<Manufacturer> createManufacturer(Manufacturer manufacturer) async {
    try {
      final database = await _database;
      
      // Проверяем, существует ли производитель
      final exists = await manufacturerExists(manufacturer.name);
      if (exists) {
        throw ValidationException('Производитель с именем "${manufacturer.name}" уже существует');
      }
      
      final dbManufacturer = DatabaseMappers.toDbManufacturer(manufacturer);
      final id = await database.manufacturersDao.insertManufacturer(dbManufacturer);
      return manufacturer.copyWith(id: id);
    } catch (e) {
      _errorHandler.handleError(e);
      if (e is ValidationException) rethrow;
      throw DatabaseException('Ошибка создания производителя: ${e.toString()}');
    }
  }

  @override
  Future<Manufacturer> updateManufacturer(Manufacturer manufacturer) async {
    try {
      final database = await _database;
      final existing = await database.manufacturersDao.getManufacturerById(manufacturer.id);
      if (existing == null) {
        throw DatabaseException('Производитель не найден');
      }
      
      final updatedDbManufacturer = db.Manufacturer(
        id: manufacturer.id,
        name: manufacturer.name,
        country: manufacturer.country,
        address: manufacturer.address,
        phone: manufacturer.phone,
        email: manufacturer.email,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      
      final updated = await database.manufacturersDao.updateManufacturer(updatedDbManufacturer);
      if (!updated) {
        throw DatabaseException('Не удалось обновить производителя');
      }
      return manufacturer;
    } catch (e) {
      _errorHandler.handleError(e);
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Ошибка обновления производителя: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteManufacturer(int id) async {
    try {
      final database = await _database;
      await database.manufacturersDao.deleteManufacturer(id);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка удаления производителя: ${e.toString()}');
    }
  }

  @override
  Future<bool> manufacturerExists(String name) async {
    try {
      final database = await _database;
      return await database.manufacturersDao.manufacturerExists(name);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка проверки существования производителя: ${e.toString()}');
    }
  }
}

