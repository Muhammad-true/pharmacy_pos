import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_exception.dart';
import '../logging/file_log_output.dart';

/// Централизованный обработчик ошибок
///
/// Обрабатывает все ошибки приложения и предоставляет
/// понятные сообщения для пользователя
class ErrorHandler {
  ErrorHandler._();

  static final ErrorHandler _instance = ErrorHandler._();
  static ErrorHandler get instance => _instance;

  Logger? _logger;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    if (kReleaseMode) {
      final dir = await getApplicationSupportDirectory();
      final logFile = File(p.join(dir.path, 'libiss_pos.log'));
      _logger = Logger(
        printer: SimplePrinter(colors: false, printTime: true),
        level: Level.warning,
        output: FileLogOutput(logFile),
      );
    } else {
      // В debug/prod не пишем логи в консоль
      _logger = Logger(
        level: Level.off,
        output: FileLogOutput(File(p.join(
          (await getTemporaryDirectory()).path,
          'libiss_pos_debug.log',
        ))),
      );
    }

    _initialized = true;
  }

  Logger get _safeLogger {
    return _logger ??
        Logger(
          level: Level.off,
          output: _NullLogOutput(),
        );
  }

  /// Обработка ошибки
  ///
  /// Логирует ошибку и возвращает понятное сообщение для пользователя
  String handleError(dynamic error, {StackTrace? stackTrace}) {
    // Логируем ошибку
    if (error is AppException) {
      _safeLogger.e(
        _sanitize('AppException: ${error.message}'),
        error: _sanitize(error.originalError?.toString()),
        stackTrace: stackTrace,
      );
      return error.message;
    } else if (error is Exception) {
      _safeLogger.e(
        _sanitize('Exception: $error'),
        error: _sanitize(error.toString()),
        stackTrace: stackTrace,
      );
      return _getUserFriendlyMessage(_sanitize(error.toString()));
    } else {
      _safeLogger.e(
        _sanitize('Error: $error'),
        error: _sanitize(error.toString()),
        stackTrace: stackTrace,
      );
      return _getUserFriendlyMessage(_sanitize(error.toString()));
    }
  }

  /// Получить понятное сообщение для пользователя
  String _getUserFriendlyMessage(String error) {
    // Преобразуем технические ошибки в понятные сообщения
    if (error.contains('DatabaseException') || error.contains('SQLite')) {
      return 'Ошибка базы данных. Проверьте подключение к базе данных.';
    }

    if (error.contains('ValidationException')) {
      return 'Ошибка валидации данных. Проверьте введенные данные.';
    }

    if (error.contains('NetworkException') ||
        error.contains('SocketException')) {
      return 'Ошибка сети. Проверьте подключение к интернету.';
    }

    if (error.contains('AuthenticationException')) {
      return 'Ошибка аутентификации. Проверьте логин и пароль.';
    }

    // По умолчанию возвращаем общее сообщение
    return 'Произошла ошибка. Попробуйте еще раз.';
  }

  /// Логирование информационного сообщения
  void info(String message) {
    _safeLogger.i(_sanitize(message));
  }

  /// Логирование предупреждения
  void warning(String message) {
    _safeLogger.w(_sanitize(message));
  }

  /// Логирование отладочного сообщения
  /// В продакшене эти сообщения не выводятся
  void debug(String message) {
    _safeLogger.d(_sanitize(message));
  }

  String _sanitize(String? message) {
    if (message == null) return '';
    var result = message;
    final patterns = [
      RegExp(r'(password[_\s-]*hash\s*=\s*)([^,\s]+)',
          caseSensitive: false),
      RegExp(r'(password\s*=\s*)([^,\s]+)', caseSensitive: false),
      RegExp(r'(пароль\s*=\s*)([^,\s]+)', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      result = result.replaceAllMapped(
        pattern,
        (match) => '${match.group(1)}***',
      );
    }
    return result;
  }
}

class _NullLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // no-op
  }
}
