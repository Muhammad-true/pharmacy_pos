import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../errors/error_handler.dart';

/// Конфигурация приложения
///
/// Содержит все настройки приложения, загружаемые из .env файла
/// или используемые по умолчанию
class AppConfig {
  AppConfig._();

  static AppConfig? _instance;
  static AppConfig get instance {
    _instance ??= AppConfig._();
    return _instance!;
  }

  static bool _isInitialized = false;
  static Map<String, String>? _envMap;

  /// Инициализация конфигурации
  /// Загружает .env файл и настраивает параметры
  /// Если файл не найден, инициализирует dotenv с пустыми значениями
  static Future<void> init() async {
    if (_isInitialized) {
      return; // Уже инициализирован
    }

    try {
      // Пытаемся найти .env файл в разных местах
      String? envPath;

      // 1. Проверяем текущую рабочую директорию
      final currentDir = Directory.current;
      final envInCurrentDir = File(path.join(currentDir.path, '.env'));
      if (await envInCurrentDir.exists()) {
        envPath = envInCurrentDir.path;
        ErrorHandler.instance.debug('[CONFIG] .env найден в текущей директории: $envPath');
      } else {
        // 2. Проверяем директорию приложения (для Flutter)
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final appDirParent = appDir.parent;
          final envInAppDir = File(path.join(appDirParent.path, '.env'));
          if (await envInAppDir.exists()) {
            envPath = envInAppDir.path;
            ErrorHandler.instance.debug('[CONFIG] .env найден в директории приложения: $envPath');
          }
        } catch (e) {
          // Игнорируем ошибки path_provider
        }

        // 3. Пытаемся найти относительно корня проекта (ищем pubspec.yaml)
        if (envPath == null) {
          var searchDir = currentDir;
          for (var i = 0; i < 10; i++) {
            final testEnv = File(path.join(searchDir.path, '.env'));
            final pubspecYaml = File(path.join(searchDir.path, 'pubspec.yaml'));

            // Если нашли pubspec.yaml, значит это корень проекта
            if (await pubspecYaml.exists()) {
              if (await testEnv.exists()) {
                envPath = testEnv.path;
                ErrorHandler.instance.debug('[CONFIG] .env найден в корне проекта: $envPath');
                break;
              } else {
                ErrorHandler.instance.debug('[CONFIG] Корень проекта найден: ${searchDir.path}');
                ErrorHandler.instance.debug('   Но .env файл не найден в этой директории');
                break;
              }
            }

            final parent = searchDir.parent;
            if (parent.path == searchDir.path)
              break; // Достигли корня файловой системы
            searchDir = parent;
          }
        }
      }

      if (envPath != null) {
        try {
          // Вычисляем относительный путь от текущей директории
          final currentDir = Directory.current.path;
          final envFile = File(envPath);
          final envDir = envFile.parent.path;

          // Если файл в текущей директории, используем просто имя файла
          String relativePath;
          if (envDir == currentDir) {
            relativePath = '.env';
          } else {
            // Пытаемся вычислить относительный путь
            try {
              relativePath = path.relative(envPath, from: currentDir);
            } catch (e) {
              // Если не получилось, используем абсолютный путь
              relativePath = envPath;
            }
          }

          // Пытаемся загрузить через dotenv.load
          await dotenv.load(fileName: relativePath);
          _isInitialized = true;
        } catch (e) {
          // Если не получилось, читаем файл вручную и инициализируем dotenv
          final envFile = File(envPath);
          final envContent = await envFile.readAsString();

          // Парсим .env файл вручную
          final envMap = <String, String>{};
          final lines = envContent.split('\n');
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
            final parts = trimmed.split('=');
            if (parts.length >= 2) {
              final key = parts[0].trim();
              var value = parts.sublist(1).join('=').trim();
              // Убираем кавычки если есть
              if (value.startsWith('"') && value.endsWith('"')) {
                value = value.substring(1, value.length - 1);
              } else if (value.startsWith("'") && value.endsWith("'")) {
                value = value.substring(1, value.length - 1);
              }
              envMap[key] = value;
            }
          }

          // Инициализируем dotenv вручную, записывая в dotenv.env
          // Сначала загружаем пустой файл для инициализации
          try {
            await dotenv.load(fileName: '.env', mergeWith: envMap);
          } catch (_) {
            // Если .env не существует, создаем временный файл
            final tempFile = File(
              path.join(Directory.current.path, '.env.temp'),
            );
            try {
              final buffer = StringBuffer();
              envMap.forEach((key, value) {
                buffer.writeln('$key=$value');
              });
              await tempFile.writeAsString(buffer.toString());
              await dotenv.load(fileName: '.env.temp');
              await tempFile.delete();
            } catch (e2) {
              // Последняя попытка - сохраняем в статическую карту
              ErrorHandler.instance.warning('[CONFIG] Не удалось загрузить .env через dotenv: $e2');
              ErrorHandler.instance.debug('   Используется ручная инициализация...');
              _envMap = envMap;
              _isInitialized = true;
              // Продолжаем выполнение, чтобы залогировать значения
            }
          }
          _isInitialized = true;
        }

        // Логируем загруженные значения для отладки
        ErrorHandler.instance.debug('[CONFIG] .env файл загружен успешно');
        ErrorHandler.instance.debug('   MYSQL_HOST: ${_getEnv('MYSQL_HOST') ?? 'не указан'}');
        ErrorHandler.instance.debug(
          '   MYSQL_DATABASE: ${_getEnv('MYSQL_DATABASE') ?? 'не указан'}',
        );
      } else {
        // Пытаемся загрузить из корня проекта (стандартный путь)
        try {
          await dotenv.load(fileName: '.env');
          _isInitialized = true;

          ErrorHandler.instance.debug('[CONFIG] .env файл загружен (стандартный путь)');
          ErrorHandler.instance.debug('   MYSQL_HOST: ${dotenv.env['MYSQL_HOST'] ?? 'не указан'}');
          ErrorHandler.instance.debug(
            '   MYSQL_DATABASE: ${dotenv.env['MYSQL_DATABASE'] ?? 'не указан'}',
          );
        } catch (e) {
          ErrorHandler.instance.warning(
            '[CONFIG] Не удалось загрузить .env стандартным способом: $e',
          );
          _isInitialized = true;
        }
      }
    } catch (e) {
      // Если .env файл не найден, dotenv останется неинициализированным
      // Это нормально - метод _getEnv() безопасно обрабатывает NotInitializedError
      // и возвращает null, после чего используются значения по умолчанию
      ErrorHandler.instance.warning('[CONFIG] Ошибка загрузки .env: $e');
      ErrorHandler.instance.debug('   Текущая директория: ${Directory.current.path}');
      ErrorHandler.instance.debug('   Используются значения по умолчанию для MySQL');
      _isInitialized = true;
    }
  }

  /// Настройки MySQL
  static String get mysqlHost => _getEnv('MYSQL_HOST') ?? 'localhost';
  static int get mysqlPort =>
      int.tryParse(_getEnv('MYSQL_PORT') ?? '3306') ?? 3306;
  static String get mysqlUser => _getEnv('MYSQL_USER') ?? 'root';
  static String get mysqlPassword => _getEnv('MYSQL_PASSWORD') ?? '';
  static String get mysqlDatabase => _getEnv('MYSQL_DATABASE') ?? 'pharmacy_db';
  static bool get mysqlSslEnabled =>
      _getEnv('MYSQL_SSL_ENABLED')?.toLowerCase() == 'true';

  /// Флаг для включения тестовых данных (только для разработки)
  static bool get enableMockData {
    final envValue = _getEnv('ENABLE_MOCK_DATA');
    return envValue?.toLowerCase() == 'true';
  }

  /// Безопасно получить значение из dotenv
  static String? _getEnv(String key) {
    // Сначала проверяем _envMap (если dotenv не инициализирован)
    if (_envMap != null) {
      return _envMap![key];
    }

    try {
      return dotenv.env[key];
    } catch (e) {
      // Если dotenv не инициализирован, возвращаем null
      return null;
    }
  }

  /// Имя приложения
  String get appName => _getEnv('APP_NAME') ?? 'libiss pos';

  /// Версия приложения
  String get appVersion => _getEnv('APP_VERSION') ?? '1.0.0';

  /// URL для проверки обновлений (JSON)
  String get updateUrl => _getEnv('UPDATE_URL') ?? '';

  /// Уровень логирования
  String get logLevel => _getEnv('LOG_LEVEL') ?? 'debug';

  /// Имя кассы
  String get cashierName => _getEnv('CASHIER_NAME') ?? 'Касса 1';

  /// Режим разработки
  bool get isDevelopment => _getEnv('ENVIRONMENT') != 'production';

  /// Режим production
  bool get isProduction => _getEnv('ENVIRONMENT') == 'production';
}
