import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/auth/models/user.dart';
import 'repository_providers.dart';
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';

part 'auth_notifier.g.dart';

/// Состояние аутентификации
@riverpod
class AuthState extends _$AuthState {
  @override
  User? build() {
    ref.keepAlive();
    return null;
  }

  /// Вход пользователя
  /// 
  /// Сначала пытается аутентифицировать через репозиторий (БД)
  Future<User> login(String username, String password) async {
    try {
      final userRepo = ref.read(userRepositoryProvider);
      
      // Пытаемся аутентифицировать через БД
      final user = await userRepo.authenticateUser(username, password);
      
      if (user != null) {
        state = user;
        return user;
      }
      
      // Если пользователь не найден в БД, пробрасываем ошибку
      throw AuthenticationException('Неверный логин или пароль');
    } catch (e) {
      ErrorHandler.instance.handleError(e);
      
      // Если это AuthenticationException, пробрасываем дальше
      if (e is AuthenticationException) {
        rethrow;
      }
      
      // Иначе пробрасываем ошибку как ошибку аутентификации
      throw AuthenticationException('Ошибка аутентификации: ${e.toString()}');
    }
  }

  /// Выход пользователя
  void logout() {
    state = null;
  }

}

