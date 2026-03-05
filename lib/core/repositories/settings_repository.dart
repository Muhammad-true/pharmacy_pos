import '../database/database_provider.dart';
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import '../models/app_settings.dart';

/// Репозиторий для работы с настройками
class SettingsRepository {
  final ErrorHandler _errorHandler = ErrorHandler.instance;

  /// Получить все настройки
  Future<AppSettings> getSettings() async {
    try {
      final database = await DatabaseProvider.getDatabase();
      final settingsMap = await database.settingsDao.getAllSettings();
      return AppSettings.fromMap(settingsMap);
    } catch (e) {
      _errorHandler.handleError(e);
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Ошибка получения настроек: ${e.toString()}');
    }
  }

  /// Получить значение настройки по ключу
  Future<String?> getSetting(String key) async {
    try {
      final database = await DatabaseProvider.getDatabase();
      return await database.settingsDao.getSetting(key);
    } catch (e) {
      _errorHandler.handleError(e);
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Ошибка получения настройки: ${e.toString()}');
    }
  }

  /// Установить значение настройки
  Future<void> setSetting(String key, String value) async {
    try {
      final database = await DatabaseProvider.getDatabase();
      await database.settingsDao.setSetting(key, value);
    } catch (e) {
      _errorHandler.handleError(e);
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Ошибка сохранения настройки: ${e.toString()}');
    }
  }

  /// Сохранить все настройки
  Future<void> saveSettings(AppSettings settings) async {
    try {
      final database = await DatabaseProvider.getDatabase();
      final map = settings.toMap();
      for (final entry in map.entries) {
        await database.settingsDao.setSetting(entry.key, entry.value);
      }
    } catch (e) {
      _errorHandler.handleError(e);
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Ошибка сохранения настроек: ${e.toString()}');
    }
  }
}

