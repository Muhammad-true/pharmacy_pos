import '../../features/shared/models/advertisement.dart';
import '../database/database_provider.dart';
import '../database/database.dart' as db;
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import 'i_advertisement_repository.dart';
import 'mappers/database_mappers.dart';

/// Реализация репозитория для работы с рекламой
class AdvertisementRepository implements IAdvertisementRepository {
  final ErrorHandler _errorHandler = ErrorHandler.instance;

  /// Получить БД
  Future<db.AppDatabase> get _database async => await DatabaseProvider.getDatabase();

  @override
  Future<List<Advertisement>> getAllAdvertisements() async {
    try {
      final database = await _database;
      final dbAdvertisements = await database.advertisementsDao.getAllAdvertisements();
      return dbAdvertisements.map(DatabaseMappers.toAppAdvertisement).toList();
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения рекламы: ${e.toString()}');
    }
  }

  @override
  Future<List<Advertisement>> getActiveAdvertisements({int? userId}) async {
    try {
      final database = await _database;
      final dbAdvertisements = await database.advertisementsDao
          .getActiveAdvertisements(userId: userId);
      return dbAdvertisements.map(DatabaseMappers.toAppAdvertisement).toList();
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения активной рекламы: ${e.toString()}');
    }
  }

  @override
  Future<Advertisement?> getAdvertisementById(int id) async {
    try {
      final database = await _database;
      final dbAdvertisement = await database.advertisementsDao.getAdvertisementById(id);
      if (dbAdvertisement == null) return null;
      return DatabaseMappers.toAppAdvertisement(dbAdvertisement);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения рекламы: ${e.toString()}');
    }
  }

  @override
  Future<Advertisement> createAdvertisement(Advertisement advertisement) async {
    try {
      final database = await _database;
      final dbAdvertisement = DatabaseMappers.toDbAdvertisement(advertisement, isUpdate: false);
      final created = await database.advertisementsDao.createAdvertisement(dbAdvertisement);
      return DatabaseMappers.toAppAdvertisement(created);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка создания рекламы: ${e.toString()}');
    }
  }

  @override
  Future<Advertisement> updateAdvertisement(Advertisement advertisement) async {
    try {
      final database = await _database;
      final dbAdvertisement = DatabaseMappers.toDbAdvertisement(advertisement, isUpdate: true);
      await database.advertisementsDao.updateAdvertisement(advertisement.id, dbAdvertisement);
      final updated = await database.advertisementsDao.getAdvertisementById(advertisement.id);
      if (updated == null) {
        throw DatabaseException('Реклама не найдена после обновления');
      }
      return DatabaseMappers.toAppAdvertisement(updated);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка обновления рекламы: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteAdvertisement(int id) async {
    try {
      final database = await _database;
      await database.advertisementsDao.deleteAdvertisement(id);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка удаления рекламы: ${e.toString()}');
    }
  }

  @override
  Future<void> toggleAdvertisementActive(int id, bool isActive) async {
    try {
      final database = await _database;
      await database.advertisementsDao.toggleAdvertisementActive(id, isActive);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка изменения статуса рекламы: ${e.toString()}');
    }
  }
}

