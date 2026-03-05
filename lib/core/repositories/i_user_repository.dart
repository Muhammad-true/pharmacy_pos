import '../../features/auth/models/user.dart';

/// Интерфейс репозитория для работы с пользователями
abstract class IUserRepository {
  /// Получить всех пользователей
  Future<List<User>> getAllUsers();

  /// Получить пользователя по ID
  Future<User?> getUserById(int id);

  /// Получить пользователя по имени пользователя
  Future<User?> getUserByUsername(String username);

  /// Получить пользователей по роли
  Future<List<User>> getUsersByRole(String role);

  /// Создать пользователя
  /// 
  /// [password] - пароль пользователя (опционально, для новых пользователей)
  Future<User> createUser(User user, {String? password});

  /// Обновить пользователя
  Future<User> updateUser(User user);

  /// Обновить пароль пользователя
  Future<void> updateUserPassword(int id, String passwordHash);

  /// Удалить пользователя
  Future<void> deleteUser(int id);

  /// Аутентификация пользователя
  Future<User?> authenticateUser(String username, String password);

  /// Проверка существования пользователя
  Future<bool> userExists(String username);
}

