/// Базовый класс для всех исключений приложения
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  
  const AppException(
    this.message, {
    this.code,
    this.originalError,
  });
  
  @override
  String toString() => message;
}

/// Исключение базы данных
class DatabaseException extends AppException {
  const DatabaseException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Исключение валидации
class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Исключение сети (для будущих интеграций)
class NetworkException extends AppException {
  const NetworkException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Исключение аутентификации
class AuthenticationException extends AppException {
  const AuthenticationException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Исключение бизнес-логики
class BusinessLogicException extends AppException {
  const BusinessLogicException(
    super.message, {
    super.code,
    super.originalError,
  });
}

