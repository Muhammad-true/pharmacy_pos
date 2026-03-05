import '../../features/auth/models/user.dart';
import '../database/database_provider.dart';
import '../database/database.dart' as db;
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import 'i_user_repository.dart';
import 'mappers/database_mappers.dart';

/// Реализация репозитория для работы с пользователями
class UserRepository implements IUserRepository {
  final ErrorHandler _errorHandler = ErrorHandler.instance;

  /// Получить БД
  Future<db.AppDatabase> get _database async {
    return await DatabaseProvider.getDatabase();
  }

  @override
  Future<List<User>> getAllUsers() async {
    try {
      final database = await _database;
      final dbUsers = await database.usersDao.getAllUsers();
      return dbUsers.map(DatabaseMappers.toAppUser).toList();
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения пользователей: ${e.toString()}');
    }
  }

  @override
  Future<User?> getUserById(int id) async {
    try {
      final database = await _database;
      final dbUser = await database.usersDao.getUserById(id);
      if (dbUser == null) return null;
      return DatabaseMappers.toAppUser(dbUser);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения пользователя: ${e.toString()}');
    }
  }

  @override
  Future<User?> getUserByUsername(String username) async {
    try {
      final database = await _database;
      final dbUser = await database.usersDao.getUserByUsername(username);
      if (dbUser == null) return null;
      return DatabaseMappers.toAppUser(dbUser);
    } catch (e) {
      // Если произошла ошибка NotInitializedError, это означает, что БД еще не инициализирована
      // В этом случае возвращаем null, чтобы позволить использовать тестовых пользователей
      final errorStr = e.toString();
      if (errorStr.contains('NotInitializedError') || errorStr.contains('not initialized')) {
        _errorHandler.debug('БД еще не инициализирована при getUserByUsername: $e');
        return null;
      }
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения пользователя: ${e.toString()}');
    }
  }

  @override
  Future<List<User>> getUsersByRole(String role) async {
    try {
      final database = await _database;
      final dbUsers = await database.usersDao.getUsersByRole(role);
      return dbUsers.map(DatabaseMappers.toAppUser).toList();
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения пользователей по роли: ${e.toString()}');
    }
  }

  @override
  Future<User> createUser(User user, {String? password}) async {
    try {
      final database = await _database;
      
      // Проверяем, существует ли пользователь
      final exists = await userExists(user.username);
      if (exists) {
        throw ValidationException('Пользователь с именем "${user.username}" уже существует');
      }
      
      // Пароль хранится как есть (в будущем можно добавить хэширование)
      final passwordHash = password;
      final dbUser = DatabaseMappers.toDbUser(user, passwordHash: passwordHash);
      final id = await database.usersDao.insertUser(dbUser);
      return User(
        id: id,
        username: user.username,
        name: user.name,
        role: user.role,
        token: user.token,
      );
    } catch (e) {
      _errorHandler.handleError(e);
      if (e is ValidationException) rethrow;
      throw DatabaseException('Ошибка создания пользователя: ${e.toString()}');
    }
  }

  @override
  Future<User> updateUser(User user) async {
    try {
      final database = await _database;
      final existing = await database.usersDao.getUserById(user.id);
      if (existing == null) {
        throw DatabaseException('Пользователь не найден');
      }
      
      final updatedDbUser = db.User(
        id: user.id,
        username: user.username,
        name: user.name,
        role: user.role,
        passwordHash: existing.passwordHash,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      
      final updated = await database.usersDao.updateUser(updatedDbUser);
      if (!updated) {
        throw DatabaseException('Не удалось обновить пользователя');
      }
      return user;
    } catch (e) {
      _errorHandler.handleError(e);
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Ошибка обновления пользователя: ${e.toString()}');
    }
  }

  @override
  Future<void> updateUserPassword(int id, String passwordHash) async {
    try {
      final database = await _database;
      final updated = await database.usersDao.updateUserPassword(id, passwordHash);
      if (!updated) {
        throw DatabaseException('Не удалось обновить пароль пользователя');
      }
    } catch (e) {
      _errorHandler.handleError(e);
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Ошибка обновления пароля: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteUser(int id) async {
    try {
      final database = await _database;
      await database.usersDao.deleteUser(id);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка удаления пользователя: ${e.toString()}');
    }
  }

  @override
  Future<User?> authenticateUser(String username, String password) async {
    try {
      final database = await _database;
      _errorHandler.debug('Попытка аутентификации пользователя: $username');
      final dbUser = await database.usersDao.authenticateUser(username, password);
      if (dbUser == null) {
        _errorHandler.debug('Пользователь не найден или неверный пароль: $username');
        return null;
      }
      _errorHandler.debug('Пользователь успешно аутентифицирован: ${dbUser.username}');
      return DatabaseMappers.toAppUser(dbUser);
    } catch (e, stackTrace) {
      // Логируем исходную ошибку
      _errorHandler.debug('Ошибка при аутентификации: $e');
      
      // Если это ошибка инициализации БД или любая ошибка БД, пытаемся повторно инициализировать
      final errorStr = e.toString().toLowerCase();
      final isDbError = errorStr.contains('notinitializederror') || 
          errorStr.contains('not initialized') ||
          errorStr.contains('databaseexception') ||
          errorStr.contains('database') ||
          errorStr.contains('sqlite') ||
          errorStr.contains('drift');
      
      if (isDbError) {
        _errorHandler.debug('Попытка повторной инициализации БД при аутентификации');
        try {
          // Пытаемся повторно инициализировать БД
          // Это сбросит состояние и попытается создать БД заново
          await DatabaseProvider.getDatabase();
          
          // Повторяем попытку аутентификации
          final database = await _database;
          final dbUser = await database.usersDao.authenticateUser(username, password);
          if (dbUser == null) return null;
          return DatabaseMappers.toAppUser(dbUser);
        } catch (retryError, retryStackTrace) {
          _errorHandler.warning('Ошибка при повторной инициализации БД: $retryError');
          _errorHandler.handleError(retryError, stackTrace: retryStackTrace);
          throw DatabaseException('Ошибка аутентификации: Не удалось инициализировать базу данных. ${retryError.toString()}');
        }
      }
      
      // Для других ошибок просто пробрасываем дальше
      _errorHandler.handleError(e, stackTrace: stackTrace);
      throw DatabaseException('Ошибка аутентификации: ${e.toString()}');
    }
  }

  @override
  Future<bool> userExists(String username) async {
    try {
      final database = await _database;
      return await database.usersDao.userExists(username);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка проверки существования пользователя: ${e.toString()}');
    }
  }
}

