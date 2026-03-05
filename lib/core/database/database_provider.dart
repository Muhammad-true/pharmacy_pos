import 'package:drift/drift.dart' show Value;

import '../config/app_config.dart';
import '../errors/error_handler.dart';
import 'database.dart';

/// Провайдер для базы данных
///
/// Создает единственный экземпляр БД для всего приложения
/// Инициализирует БД и создает администратора при первом запуске
class DatabaseProvider {
  DatabaseProvider._();

  static AppDatabase? _database;
  static bool _isInitialized = false;

  /// Получить экземпляр базы данных
  ///
  /// Создает БД при первом вызове и инициализирует её
  /// Создает администратора при первом запуске
  static Future<AppDatabase> getDatabase() async {
    if (_database != null && _isInitialized) {
      return _database!;
    }

    // Инициализируем конфигурацию, если еще не инициализирована
    try {
      await AppConfig.init();
    } catch (e) {
      // Игнорируем ошибки загрузки .env
      ErrorHandler.instance.warning('Ошибка инициализации конфигурации: $e');
    }

    AppDatabase? newDatabase;

    try {
      ErrorHandler.instance.debug('Начало инициализации БД...');

      // Создаем соединение с БД
      final executor = await createDatabaseConnection();
      ErrorHandler.instance.debug(
        '✅ Соединение с MySQL создано',
      );

      // Создаем экземпляр БД с соединением
      newDatabase = AppDatabase(executor);
      ErrorHandler.instance.debug('Экземпляр AppDatabase создан');

      // Инициализируем БД - первый запрос автоматически создаст таблицы через onCreate
      // Используем простой запрос для инициализации миграций
      try {
        ErrorHandler.instance.debug(
          'Выполнение первого запроса к БД для инициализации таблиц...',
        );

        // Для MySQL сначала проверяем, существуют ли таблицы
        // Если нет, Drift создаст их через onCreate
        // Для MySQL сначала проверяем существование таблицы users
        try {
          await newDatabase.customStatement('SELECT 1 FROM users LIMIT 1');
          ErrorHandler.instance.debug('Таблица users уже существует в MySQL');
        } catch (e) {
          // Таблица не существует, Drift создаст её при первом запросе
          ErrorHandler.instance.debug('Таблица users не найдена, будет создана при первом запросе');
        }

        // Проверяем, была ли БД только что создана (нет пользователей)
        // Этот запрос заставит Drift выполнить миграцию и создать таблицы
        List<User> users = [];
        try {
          users = await newDatabase.usersDao.getAllUsers();
        } catch (e) {
          // Если произошла ошибка при получении пользователей (например, таблица пуста или структура отличается),
          // проверяем количество пользователей через прямой SQL запрос
          ErrorHandler.instance.debug('Ошибка при getAllUsers(), проверяем через SQL: $e');
          try {
            final result = await newDatabase.customSelect(
              'SELECT COUNT(*) as count FROM users',
              readsFrom: {newDatabase.users},
            ).getSingle();
            final count = result.read<int>('count');
            ErrorHandler.instance.debug('Количество пользователей в БД: $count');
            if (count == 0) {
              users = [];
            } else {
              // Если есть пользователи, но getAllUsers() не работает, это проблема маппинга
              ErrorHandler.instance.warning('В БД есть $count пользователей, но getAllUsers() не работает');
              rethrow;
            }
          } catch (sqlError) {
            ErrorHandler.instance.warning('Ошибка при проверке количества пользователей: $sqlError');
            // Продолжаем, предполагая что таблица пуста
            users = [];
          }
        }
        final isFirstRun = users.isEmpty;

        ErrorHandler.instance.debug(
          'Первый запрос выполнен успешно, пользователей: ${users.length}',
        );

        ErrorHandler.instance.debug(
          'БД инициализирована, версия схемы: ${newDatabase.schemaVersion}, пользователей: ${users.length}',
        );

        // Если это первый запуск, создаем администратора
        if (isFirstRun) {
          await _createDefaultAdmin(newDatabase);
        }
      } catch (dbError, dbStackTrace) {
        // Проверяем, не является ли это ошибкой дубликата колонки при миграции
        // Такая ошибка уже обрабатывается в миграции и не должна пробрасываться
        final errorStr = dbError.toString().toLowerCase();
        final isDuplicateColumnError =
            errorStr.contains('duplicate column') &&
            errorStr.contains('created_by_user_id');

        if (isDuplicateColumnError) {
          // Ошибка дубликата колонки уже обработана в миграции,
          // просто продолжаем выполнение без логирования
          ErrorHandler.instance.debug(
            'Колонка created_by_user_id уже существует, миграция пропущена',
          );
        } else {
          // Если это другая ошибка, логируем и пробрасываем дальше
          ErrorHandler.instance.warning(
            'Ошибка при первом запросе к БД: $dbError',
          );
          ErrorHandler.instance.handleError(dbError, stackTrace: dbStackTrace);
          rethrow; // Пробрасываем ошибку дальше
        }
      }

      // Только после успешной инициализации сохраняем БД и помечаем как инициализированную
      _database = newDatabase;
      _isInitialized = true;

      ErrorHandler.instance.debug('База данных успешно инициализирована');
    } catch (e, stackTrace) {
      // Проверяем, не является ли это ошибкой дубликата колонки при миграции
      final errorStr = e.toString().toLowerCase();
      final isDuplicateColumnError =
          errorStr.contains('duplicate column') &&
          errorStr.contains('created_by_user_id');
      
      // Проверяем, является ли это ошибкой соединения
      final isConnectionError = errorStr.contains('socket') ||
          errorStr.contains('connection') ||
          errorStr.contains('cannot write to socket') ||
          errorStr.contains('connection closed');

      if (isDuplicateColumnError) {
        // Ошибка дубликата колонки уже обработана в миграции,
        // БД инициализирована успешно, просто продолжаем
        ErrorHandler.instance.debug(
          'Колонка created_by_user_id уже существует, БД инициализирована',
        );
        _database = newDatabase;
        _isInitialized = true;
        return _database!;
      }

      // Если это ошибка соединения, даем более понятное сообщение
      if (isConnectionError) {
        ErrorHandler.instance.warning(
          'Ошибка соединения с MySQL: $e\n'
          'Убедитесь, что:\n'
          '1. MySQL сервер запущен\n'
          '2. MySQL сервер доступен по адресу ${AppConfig.mysqlHost}:${AppConfig.mysqlPort}\n'
          '3. Указаны правильные учетные данные в .env файле\n'
          '4. База данных ${AppConfig.mysqlDatabase} существует',
        );
      } else {
        // Если это другая ошибка, логируем её
        ErrorHandler.instance.handleError(e, stackTrace: stackTrace);
        ErrorHandler.instance.warning('Ошибка при инициализации БД: $e');
      }

      // Закрываем БД, если она была создана
      if (newDatabase != null) {
        try {
          await newDatabase.close();
        } catch (_) {
          // Игнорируем ошибки при закрытии
        }
      }

      // Сбрасываем состояние, чтобы можно было повторить попытку
      _database = null;
      _isInitialized = false;

      // Пробрасываем ошибку дальше
      rethrow;
    }

    return _database!;
  }

  /// Создать администратора по умолчанию
  static Future<void> _createDefaultAdmin(AppDatabase database) async {
    try {
      // Проверяем, существует ли уже администратор
      final existingAdmin = await database.usersDao.getUserByUsername('admin');
      if (existingAdmin != null) {
        ErrorHandler.instance.debug('Администратор уже существует');
        return;
      }

      // Создаем администратора
      final adminUser = UsersCompanion.insert(
        username: 'admin',
        name: 'Администратор',
        role: 'admin',
        passwordHash: Value(
          'admin',
        ), // Пароль: admin (в будущем можно добавить хэширование)
      );

      await database.usersDao.insertUser(adminUser);
      ErrorHandler.instance.debug('Администратор создан: admin / admin');
    } catch (e, stackTrace) {
      ErrorHandler.instance.handleError(e, stackTrace: stackTrace);
      ErrorHandler.instance.warning('Ошибка создания администратора: $e');
      rethrow; // Пробрасываем ошибку, так как создание администратора критично
    }
  }

  /// Закрыть соединение с БД
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _isInitialized = false;
    }
  }
}
