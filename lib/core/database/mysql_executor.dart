import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:mysql1/mysql1.dart';

import '../config/app_config.dart';
import '../errors/error_handler.dart';

/// Обертка для использования MySQL с Drift
/// 
/// Drift не поддерживает MySQL напрямую, поэтому создаем обертку
/// которая реализует QueryExecutor для работы с MySQL
class MySqlExecutor extends QueryExecutor {
  MySqlConnection _connection;
  final bool _logStatements;
  final ConnectionSettings _connectionSettings;

  MySqlExecutor(this._connection, {bool logStatements = true})
      : _logStatements = logStatements,
        _connectionSettings = ConnectionSettings(
          host: AppConfig.mysqlHost,
          port: AppConfig.mysqlPort,
          user: AppConfig.mysqlUser,
          password: AppConfig.mysqlPassword,
          db: AppConfig.mysqlDatabase,
          useSSL: AppConfig.mysqlSslEnabled,
        );

  @override
  SqlDialect get dialect => SqlDialect.mysql;

  @override
  QueryExecutor beginExclusive() {
    // MySQL не требует exclusive режима, возвращаем себя
    return this;
  }

  @override
  TransactionExecutor beginTransaction() {
    // MySQL транзакции обрабатываются через connection
    return _MySqlTransactionExecutor(_connection, _logStatements);
  }

  @override
  Future<void> close() async {
    await _connection.close();
  }

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async {
    // Проверяем, что соединение активно
    try {
      await _connection.query('SELECT 1');
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> runBatched(BatchedStatements statements) async {
    // BatchedStatements обрабатывается через runCustom для каждого запроса
    // Drift вызывает runCustom для каждого statement в батче
    // Здесь мы просто выполняем их в транзакции
    // Реальная обработка происходит через runCustom
    await _connection.transaction((_) async {
      // BatchedStatements не имеет прямого доступа к statements
      // Drift обрабатывает их через runCustom
    });
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {
    await _runQuery(statement, args);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) async {
    final result = await _runQuery(statement, args);
    return result.affectedRows ?? 0;
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) async {
    final result = await _runQuery(statement, args);
    return result.insertId?.toInt() ?? 0;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) async {
    final result = await _runQuery(statement, args);
    final rows = <Map<String, Object?>>[];
    
    for (final row in result) {
      final map = <String, Object?>{};
      
      // MySQL возвращает поля через row.fields, где ключ - имя поля (String)
      // Значения доступны через row[fieldName] или row[index]
      // row.fields.keys содержит имена полей
      // Используем только имена полей для получения значений
      // НЕ используем индекс, так как порядок полей может не совпадать
      for (final fieldName in row.fields.keys) {
        // Получаем значение ТОЛЬКО по имени поля
        final value = row[fieldName];
        
        // Логируем для отладки (только для первых нескольких записей)
        if (rows.length < 2 && _logStatements) {
          print('MySQL Field: $fieldName = $value (type: ${value.runtimeType}, isNull: ${value == null})');
        }
        
        // Если значение null, оставляем его как null и переходим к следующему полю
        if (value == null) {
          map[fieldName] = null;
          continue;
        }
        
        // Преобразуем типы для совместимости с Drift
        Object? convertedValue = value;
        
        // MySQL может возвращать BLOB/TEXT как Uint8List или другие типы
        // Обрабатываем Blob ПЕРЕД другими проверками
        if (value is Uint8List) {
          // MySQL может возвращать BLOB/TEXT как Uint8List
          // Преобразуем в строку
          try {
            convertedValue = String.fromCharCodes(value);
          } catch (e) {
            // Если не удалось преобразовать, оставляем как есть
            convertedValue = value;
          }
        } else if (value is List<int>) {
          // MySQL может возвращать BLOB/TEXT как List<int>
          // Преобразуем в строку
          try {
            convertedValue = String.fromCharCodes(value);
          } catch (e) {
            convertedValue = value;
          }
        } else if (value is int && fieldName.toLowerCase() == 'phone') {
          // MySQL может возвращать TEXT как int, если значение числовое
          // Преобразуем в строку для поля phone
          convertedValue = value.toString();
        }
        // Drift ожидает DateTime как Unix timestamp (секунды, UTC)
        // MySQL возвращает DateTime как объект DateTime или как строку
        else if (value is DateTime) {
          final utcDateTime = value.isUtc ? value : value.toUtc();
          convertedValue = utcDateTime.millisecondsSinceEpoch ~/ 1000;
          if (_logStatements && rows.length < 2) {
            print('🟢 MySQL DateTime($fieldName) → UTC: $utcDateTime → sec: $convertedValue');
          }
        } else if (value is String) {
          // Пытаемся распарсить строку как DateTime, если это похоже на дату
          // НЕ парсим строки, которые явно не являются датами (например, TEXT поля)
          try {
            // Проверяем, что строка похожа на дату (формат ISO 8601 или MySQL DATETIME)
            if (value.length >= 10 && 
                value.contains('-') && 
                (value.contains('T') || value.contains(' ') || value.contains(':'))) {
              // MySQL возвращает дату в формате 'YYYY-MM-DD HH:MM:SS' без timezone
              // Интерпретируем как локальное время сервера БД
              DateTime dateTime;
              if (value.contains('T')) {
                // ISO 8601 формат с 'T' - может содержать timezone
                dateTime = DateTime.parse(value);
              } else {
                // MySQL DATETIME формат 'YYYY-MM-DD HH:MM:SS' - локальное время
                final parts = value.split(' ');
                if (parts.length == 2) {
                  final dateParts = parts[0].split('-');
                  final timeParts = parts[1].split(':');
                  if (dateParts.length == 3 && timeParts.length >= 2) {
                    dateTime = DateTime(
                      int.parse(dateParts[0]),
                      int.parse(dateParts[1]),
                      int.parse(dateParts[2]),
                      int.parse(timeParts[0]),
                      timeParts.length > 1 ? int.parse(timeParts[1]) : 0,
                      timeParts.length > 2 ? int.parse(timeParts[2].split('.')[0]) : 0,
                    );
                  } else {
                    dateTime = DateTime.parse(value);
                  }
                } else {
                  dateTime = DateTime.parse(value);
                }
              }
              final utcDateTime = dateTime.isUtc ? dateTime : dateTime.toUtc();
              convertedValue = utcDateTime.millisecondsSinceEpoch ~/ 1000;
              if (_logStatements && rows.length < 2) {
                print('🟢 MySQL DateString($fieldName)="$value" → $utcDateTime → sec: $convertedValue');
              }
            }
          } catch (e) {
            // Оставляем как есть, если не удалось распарсить
            convertedValue = value;
          }
        }
        
        // MySQL может возвращать bool как TINYINT(1) - 0 или 1
        // Проверяем по имени поля, если оно содержит паттерны boolean полей
        if (value is int && (value == 0 || value == 1)) {
          final lowerName = fieldName.toLowerCase();
          // Список известных boolean полей в нашей схеме БД
          final booleanFields = [
            'requires_prescription',
            'discount_is_percent',
            'is_active',
            'requiresprescription',
            'discountispercent',
            'isactive',
          ];
          
          // Проверяем точное совпадение или паттерны
          if (booleanFields.contains(lowerName) ||
              lowerName.startsWith('is_') || 
              lowerName.contains('_flag') || 
              lowerName.contains('requires_') ||
              lowerName.endsWith('_bool') ||
              lowerName.contains('ispercent') ||
              lowerName.contains('isprescription')) {
            convertedValue = value == 1;
          }
        }
        
        // MySQL может возвращать INT как double (например, stock)
        // Преобразуем double в int для полей, которые должны быть int
        if (convertedValue is double) {
          final lowerName = fieldName.toLowerCase();
          // Список полей, которые должны быть int, но могут приходить как double
          final intFields = [
            'id',
            'stock',
            'units_per_package',
            'manufacturer_id',
            'client_id',
            'user_id',
            'receipt_id',
            'product_id',
            'units_in_package',
            'index',
            'created_by_user_id',
            'total_receipts',
            'quantity', // для stock_movements
            'stock_before',
            'stock_after',
          ];
          
          // Если поле должно быть int, преобразуем double в int
          if (intFields.contains(lowerName) || 
              lowerName.endsWith('_id') ||
              lowerName == 'index') {
            // Проверяем, что значение целое
            if (convertedValue == convertedValue.truncateToDouble()) {
              convertedValue = convertedValue.toInt();
            }
          }
        }
        
        map[fieldName] = convertedValue;
      }
      
      // Логируем первую строку для отладки
      if (rows.isEmpty && _logStatements) {
        print('MySQL Row mapped: $map');
      }
      
      rows.add(map);
    }
    
    if (_logStatements && rows.isNotEmpty) {
      print('MySQL: Возвращено ${rows.length} строк');
    }
    
    return rows;
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async {
    final result = await _runQuery(statement, args);
    return result.affectedRows ?? 0;
  }

  /// Преобразует SQL запрос от Drift (SQLite синтаксис) в MySQL синтаксис
  /// 
  /// Drift генерирует SQL с двойными кавычками для идентификаторов (SQLite),
  /// но MySQL требует обратные кавычки для идентификаторов.
  /// 
  /// Пример: "users" -> `users`
  String _convertSqlToMysql(String sql) {
    // Заменяем двойные кавычки на обратные кавычки для идентификаторов
    // Drift всегда использует двойные кавычки для идентификаторов,
    // а строковые литералы передаются через параметры (?)
    // Поэтому можно безопасно заменить все двойные кавычки на обратные
    
    // Используем регулярное выражение для замены двойных кавычек
    // которые окружают идентификаторы (буквы, цифры, подчеркивания)
    // Паттерн: "identifier" -> `identifier`
    return sql.replaceAllMapped(
      RegExp(r'"([a-zA-Z_][a-zA-Z0-9_]*)"'),
      (match) => '`${match.group(1)}`',
    );
  }

  /// Проверяет соединение и переподключается если нужно
  Future<void> _ensureConnection() async {
    try {
      // Пытаемся выполнить простой запрос для проверки соединения
      await _connection.query('SELECT 1');
    } catch (e) {
      // Соединение закрыто, переподключаемся
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socket') || 
          errorStr.contains('connection') ||
          errorStr.contains('cannot write to socket') ||
          errorStr.contains('connection closed')) {
        ErrorHandler.instance.debug('[БД] Соединение закрыто, переподключаемся...');
        try {
          // Закрываем старое соединение если оно еще открыто
          try {
            await _connection.close();
          } catch (_) {
            // Игнорируем ошибки при закрытии
          }
          
          // Создаем новое соединение
          _connection = await MySqlConnection.connect(_connectionSettings);
          
          // Устанавливаем настройки кодировки после переподключения
          try {
            await _connection.query('SET NAMES utf8mb4');
            await _connection.query('SET CHARACTER SET utf8mb4');
          } catch (_) {
            // Игнорируем ошибки установки кодировки
          }
          
          ErrorHandler.instance.debug('[БД] ✅ Переподключение успешно!');
        } catch (reconnectError) {
          ErrorHandler.instance.warning('[БД] ❌ Ошибка переподключения: $reconnectError');
          rethrow;
        }
      } else {
        // Другая ошибка, пробрасываем дальше
        rethrow;
      }
    }
  }

  Future<Results> _runQuery(String sql, List<Object?>? args) async {
    // Проверяем соединение перед запросом
    await _ensureConnection();
    
    // Преобразуем SQL из SQLite синтаксиса в MySQL синтаксис
    final mysqlSql = _convertSqlToMysql(sql);
    
    if (_logStatements) {
      print('MySQL (original): $sql');
      print('MySQL (converted): $mysqlSql');
      if (args != null && args.isNotEmpty) {
        print('Args: $args');
      }
    }

    // Преобразуем аргументы для mysql1
    final mysqlArgs = _convertArgs(args);
    
    try {
      return await _connection.query(mysqlSql, mysqlArgs);
    } catch (e) {
      // Если ошибка соединения, пробуем переподключиться и повторить запрос
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socket') || 
          errorStr.contains('connection') ||
          errorStr.contains('cannot write to socket') ||
          errorStr.contains('connection closed')) {
        ErrorHandler.instance.debug('[БД] Ошибка при запросе, пробуем переподключиться...');
        await _ensureConnection();
        // Повторяем запрос после переподключения
        return await _connection.query(mysqlSql, mysqlArgs);
      }
      rethrow;
    }
  }

  List<Object?> _convertArgs(List<Object?>? args) {
    if (args == null) return [];

    return args.map((arg) {
      if (arg == null) {
        return null;
      }

      if (arg is DateTime) {
        return _formatDateTime(arg);
      }

      if (arg is int) {
        final dateTime = _tryParseUnixTimestamp(arg);
        if (dateTime != null) {
          return _formatDateTime(dateTime);
        }
      }

      if (arg is num && arg % 1 == 0) {
        final dateTime = _tryParseUnixTimestamp(arg.toInt());
        if (dateTime != null) {
          return _formatDateTime(dateTime);
        }
      }

      if (arg is bool) {
        return arg ? 1 : 0;
      }

      return arg;
    }).toList();
  }

  DateTime? _tryParseUnixTimestamp(int value) {
    final absValue = value.abs();

    if (absValue < 946684800) {
      return null;
    }

    if (absValue >= 1000000000000) {
      if (absValue >= 1000000000000000) {
        try {
          return DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true);
        } catch (_) {
          return null;
        }
      }
      try {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      } catch (_) {
        return null;
      }
    }

    try {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    } catch (_) {
      return null;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final utc = dateTime.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    final year = utc.year.toString().padLeft(4, '0');
    final month = two(utc.month);
    final day = two(utc.day);
    final hour = two(utc.hour);
    final minute = two(utc.minute);
    final second = two(utc.second);
    final millisecond = three(utc.millisecond);
    return '$year-$month-$day $hour:$minute:$second.$millisecond';
  }
}

/// Executor для транзакций MySQL
class _MySqlTransactionExecutor extends TransactionExecutor {
  final MySqlConnection _connection;
  final bool _logStatements;

  _MySqlTransactionExecutor(this._connection, this._logStatements);

  @override
  SqlDialect get dialect => SqlDialect.mysql;

  @override
  bool get supportsNestedTransactions => false;

  @override
  QueryExecutor beginExclusive() {
    // MySQL не требует exclusive режима, возвращаем себя
    return this;
  }

  @override
  TransactionExecutor beginTransaction() {
    // Вложенные транзакции не поддерживаются
    return this;
  }

  @override
  Future<void> close() async {
    // Транзакция закрывается автоматически
  }

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async {
    return true;
  }

  @override
  Future<void> runBatched(BatchedStatements statements) async {
    // В транзакции batched statements обрабатываются через runCustom
    // Drift вызывает runCustom для каждого statement
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {
    await _runQuery(statement, args);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) async {
    final result = await _runQuery(statement, args);
    return result.affectedRows ?? 0;
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) async {
    final result = await _runQuery(statement, args);
    return result.insertId?.toInt() ?? 0;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) async {
    final result = await _runQuery(statement, args);
    final rows = <Map<String, Object?>>[];
    
    for (final row in result) {
      final map = <String, Object?>{};
      
      // MySQL возвращает поля через row.fields, где ключ - имя поля (String)
      // Значения доступны через row[fieldName] или row[index]
      // row.fields.keys содержит имена полей
      // Используем только имена полей для получения значений
      // НЕ используем индекс, так как порядок полей может не совпадать
      for (final fieldName in row.fields.keys) {
        // Получаем значение ТОЛЬКО по имени поля
        final value = row[fieldName];
        
        // Логируем для отладки (только для первых нескольких записей)
        if (rows.length < 2 && _logStatements) {
          print('MySQL Transaction Field: $fieldName = $value (type: ${value.runtimeType}, isNull: ${value == null})');
        }
        
        // Если значение null, оставляем его как null и переходим к следующему полю
        if (value == null) {
          map[fieldName] = null;
          continue;
        }
        
        // Преобразуем типы для совместимости с Drift
        Object? convertedValue = value;
        
        // MySQL может возвращать BLOB/TEXT как Uint8List или другие типы
        // Обрабатываем Blob ПЕРЕД другими проверками
        if (value is Uint8List) {
          // MySQL может возвращать BLOB/TEXT как Uint8List
          // Преобразуем в строку
          try {
            convertedValue = String.fromCharCodes(value);
          } catch (e) {
            // Если не удалось преобразовать, оставляем как есть
            convertedValue = value;
          }
        } else if (value is List<int>) {
          // MySQL может возвращать BLOB/TEXT как List<int>
          // Преобразуем в строку
          try {
            convertedValue = String.fromCharCodes(value);
          } catch (e) {
            convertedValue = value;
          }
        } else if (value is int && fieldName.toLowerCase() == 'phone') {
          // MySQL может возвращать TEXT как int, если значение числовое
          // Преобразуем в строку для поля phone
          convertedValue = value.toString();
        }
        // Drift ожидает DateTime как Unix timestamp (секунды, UTC)
        // MySQL возвращает DateTime как объект DateTime или как строку
        else if (value is DateTime) {
          final utcDateTime = value.isUtc ? value : value.toUtc();
          convertedValue = utcDateTime.millisecondsSinceEpoch ~/ 1000;
          if (_logStatements && rows.length < 2) {
            print('🟢 MySQL TX DateTime($fieldName) → UTC: $utcDateTime → sec: $convertedValue');
          }
        } else if (value is String) {
          // Пытаемся распарсить строку как DateTime, если это похоже на дату
          // НЕ парсим строки, которые явно не являются датами (например, TEXT поля)
          try {
            // Проверяем, что строка похожа на дату (формат ISO 8601 или MySQL DATETIME)
            if (value.length >= 10 && 
                value.contains('-') && 
                (value.contains('T') || value.contains(' ') || value.contains(':'))) {
              // MySQL возвращает дату в формате 'YYYY-MM-DD HH:MM:SS' без timezone
              // Интерпретируем как локальное время сервера БД
              DateTime dateTime;
              if (value.contains('T')) {
                // ISO 8601 формат с 'T' - может содержать timezone
                dateTime = DateTime.parse(value);
              } else {
                // MySQL DATETIME формат 'YYYY-MM-DD HH:MM:SS' - локальное время
                final parts = value.split(' ');
                if (parts.length == 2) {
                  final dateParts = parts[0].split('-');
                  final timeParts = parts[1].split(':');
                  if (dateParts.length == 3 && timeParts.length >= 2) {
                    dateTime = DateTime(
                      int.parse(dateParts[0]),
                      int.parse(dateParts[1]),
                      int.parse(dateParts[2]),
                      int.parse(timeParts[0]),
                      timeParts.length > 1 ? int.parse(timeParts[1]) : 0,
                      timeParts.length > 2 ? int.parse(timeParts[2].split('.')[0]) : 0,
                    );
                  } else {
                    dateTime = DateTime.parse(value);
                  }
                } else {
                  dateTime = DateTime.parse(value);
                }
              }
              final utcDateTime = dateTime.isUtc ? dateTime : dateTime.toUtc();
              convertedValue = utcDateTime.millisecondsSinceEpoch ~/ 1000;
              if (_logStatements && rows.length < 2) {
                print('🟢 MySQL TX DateString($fieldName)="$value" → $utcDateTime → sec: $convertedValue');
              }
            }
          } catch (e) {
            // Оставляем как есть, если не удалось распарсить
            convertedValue = value;
          }
        }
        
        // MySQL может возвращать bool как TINYINT(1) - 0 или 1
        // Проверяем по имени поля, если оно содержит паттерны boolean полей
        if (value is int && (value == 0 || value == 1)) {
          final lowerName = fieldName.toLowerCase();
          // Список известных boolean полей в нашей схеме БД
          final booleanFields = [
            'requires_prescription',
            'discount_is_percent',
            'is_active',
            'requiresprescription',
            'discountispercent',
            'isactive',
          ];
          
          // Проверяем точное совпадение или паттерны
          if (booleanFields.contains(lowerName) ||
              lowerName.startsWith('is_') || 
              lowerName.contains('_flag') || 
              lowerName.contains('requires_') ||
              lowerName.endsWith('_bool') ||
              lowerName.contains('ispercent') ||
              lowerName.contains('isprescription')) {
            convertedValue = value == 1;
          }
        }
        
        // MySQL может возвращать INT как double (например, stock)
        // Преобразуем double в int для полей, которые должны быть int
        if (convertedValue is double) {
          final lowerName = fieldName.toLowerCase();
          // Список полей, которые должны быть int, но могут приходить как double
          final intFields = [
            'id',
            'stock',
            'units_per_package',
            'manufacturer_id',
            'client_id',
            'user_id',
            'receipt_id',
            'product_id',
            'units_in_package',
            'index',
            'created_by_user_id',
            'total_receipts',
            'quantity', // для stock_movements
            'stock_before',
            'stock_after',
          ];
          
          // Если поле должно быть int, преобразуем double в int
          if (intFields.contains(lowerName) || 
              lowerName.endsWith('_id') ||
              lowerName == 'index') {
            // Проверяем, что значение целое
            if (convertedValue == convertedValue.truncateToDouble()) {
              convertedValue = convertedValue.toInt();
            }
          }
        }
        
        map[fieldName] = convertedValue;
      }
      
      // Логируем первую строку для отладки
      if (rows.isEmpty && _logStatements) {
        print('MySQL Row mapped: $map');
      }
      
      rows.add(map);
    }
    
    if (_logStatements && rows.isNotEmpty) {
      print('MySQL: Возвращено ${rows.length} строк');
    }
    
    return rows;
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async {
    final result = await _runQuery(statement, args);
    return result.affectedRows ?? 0;
  }

  @override
  Future<void> rollback() async {
    // Откат транзакции обрабатывается через connection
    // В mysql1 транзакции откатываются автоматически при ошибке
  }

  @override
  Future<void> send() async {
    // Отправка транзакции обрабатывается через connection
  }

  /// Преобразует SQL запрос от Drift (SQLite синтаксис) в MySQL синтаксис
  String _convertSqlToMysql(String sql) {
    return sql.replaceAllMapped(
      RegExp(r'"([a-zA-Z_][a-zA-Z0-9_]*)"'),
      (match) => '`${match.group(1)}`',
    );
  }

  Future<Results> _runQuery(String sql, List<Object?>? args) async {
    // Преобразуем SQL из SQLite синтаксиса в MySQL синтаксис
    final mysqlSql = _convertSqlToMysql(sql);
    
    if (_logStatements) {
      print('MySQL Transaction (original): $sql');
      print('MySQL Transaction (converted): $mysqlSql');
      if (args != null && args.isNotEmpty) {
        print('Args: $args');
      }
    }

    final mysqlArgs = _convertArgs(args);
    return await _connection.query(mysqlSql, mysqlArgs);
  }

  List<Object?> _convertArgs(List<Object?>? args) {
    if (args == null) return [];
    
    return args.map((arg) {
      if (arg is DateTime) {
        return arg.toIso8601String();
      }
      if (arg is bool) {
        return arg ? 1 : 0;
      }
      return arg;
    }).toList();
  }
}

