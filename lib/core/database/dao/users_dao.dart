import 'package:drift/drift.dart';

import '../database.dart';

part 'users_dao.g.dart';

/// DAO для работы с пользователями
@DriftAccessor(tables: [Users])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.db);

  /// Получить всех пользователей
  Future<List<User>> getAllUsers() async {
    return await (select(
      users,
    )..orderBy([(u) => OrderingTerm.asc(u.name)])).get();
  }

  /// Получить пользователя по ID
  Future<User?> getUserById(int id) async {
    return await (select(
      users,
    )..where((u) => u.id.equals(id))).getSingleOrNull();
  }

  /// Получить пользователя по имени пользователя
  Future<User?> getUserByUsername(String username) async {
    return await (select(users)
          ..where((u) => u.username.equals(username.toLowerCase())))
        .getSingleOrNull();
  }

  /// Получить пользователей по роли
  Future<List<User>> getUsersByRole(String role) async {
    return await (select(users)
          ..where((u) => u.role.equals(role.toLowerCase()))
          ..orderBy([(u) => OrderingTerm.asc(u.name)]))
        .get();
  }

  /// Создать пользователя
  Future<int> insertUser(UsersCompanion user) async {
    return await into(users).insert(user);
  }

  /// Обновить пользователя
  Future<bool> updateUser(User user) async {
    return await update(users).replace(user);
  }

  /// Удалить пользователя
  Future<int> deleteUser(int id) async {
    return await (delete(users)..where((u) => u.id.equals(id))).go();
  }

  /// Обновить пароль пользователя
  Future<bool> updateUserPassword(int id, String passwordHash) async {
    final result = await (update(users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(passwordHash: Value(passwordHash)),
    );
    return result > 0;
  }

  /// Проверка существования пользователя
  Future<bool> userExists(String username) async {
    final user = await getUserByUsername(username);
    return user != null;
  }

  /// Аутентификация пользователя
  /// Проверяет имя пользователя и пароль
  Future<User?> authenticateUser(String username, String password) async {
    final user = await getUserByUsername(username.toLowerCase());
    if (user == null) {
      return null;
    }

    // Если пароль не установлен, разрешаем вход только если пароль совпадает с username
    // (для обратной совместимости с тестовыми пользователями)
    if (user.passwordHash == null || user.passwordHash!.isEmpty) {
      if (username.toLowerCase() == password.toLowerCase()) {
        return user;
      }
      return null;
    }

    // Простая проверка пароля (в будущем можно добавить хэширование)
    // Пока сравниваем напрямую - пароль хранится как есть
    // Важно: сравниваем точно, без преобразований
    if (user.passwordHash == password) {
      return user;
    }

    return null;
  }
}
