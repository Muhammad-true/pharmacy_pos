import 'dart:io';
import 'package:mysql1/mysql1.dart';

/// Простой скрипт для проверки подключения к MySQL
/// 
/// Запуск: dart test_mysql_connection.dart
Future<void> main() async {
  print('🔍 Проверка подключения к MySQL...\n');

  // Настройки подключения (измените при необходимости)
  final settings = ConnectionSettings(
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: '023637',
    db: 'pharmacy_db', // База данных должна существовать
  );

  try {
    print('📡 Подключение к MySQL серверу...');
    print('   Host: ${settings.host}');
    print('   Port: ${settings.port}');
    print('   User: ${settings.user}');
    print('   Database: ${settings.db}\n');

    final connection = await MySqlConnection.connect(settings);
    print('✅ Подключение успешно!\n');

    // Проверяем версию MySQL
    final versionResult = await connection.query('SELECT VERSION() as version');
    String version = 'неизвестно';
    if (versionResult.isNotEmpty) {
      final row = versionResult.first;
      version = row['version']?.toString() ?? row[0]?.toString() ?? 'неизвестно';
    }
    print('📊 Версия MySQL: $version\n');

    // Проверяем существующие таблицы
    print('📋 Проверка таблиц в базе данных...');
    final tablesResult = await connection.query('SHOW TABLES');
    
    if (tablesResult.isEmpty) {
      print('   ⚠️  Таблицы не найдены (база данных пустая)');
      print('   💡 При первом запуске приложения таблицы будут созданы автоматически\n');
    } else {
      print('   ✅ Найдено таблиц: ${tablesResult.length}');
      for (final row in tablesResult) {
        // Получаем имя таблицы из первого столбца
        final tableName = row[0]?.toString() ?? 'неизвестно';
        print('      - $tableName');
      }
      print('');
    }

    // Проверяем кодировку
    print('🔤 Проверка кодировки...');
    final charsetResult = await connection.query('SHOW VARIABLES LIKE "character_set_database"');
    String charset = 'неизвестно';
    if (charsetResult.isNotEmpty) {
      final row = charsetResult.first;
      charset = row['Value']?.toString() ?? row[1]?.toString() ?? 'неизвестно';
    }
    print('   Кодировка БД: $charset');
    
    if (charset != 'utf8mb4') {
      print('   ⚠️  Рекомендуется использовать utf8mb4 для поддержки всех символов');
    } else {
      print('   ✅ Кодировка корректна\n');
    }

    await connection.close();
    print('✅ Все проверки пройдены успешно!');
    print('🚀 Приложение готово к работе с MySQL\n');

  } on MySqlException catch (e) {
    print('❌ Ошибка MySQL:');
    print('   Код: ${e.errorNumber}');
    print('   Сообщение: ${e.message}\n');
    
    if (e.errorNumber == 1045) {
      print('💡 Проверьте логин и пароль в настройках');
    } else if (e.errorNumber == 1049) {
      print('💡 База данных не существует. Создайте её:');
      print('   CREATE DATABASE pharmacy_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;');
    } else if (e.errorNumber == 2003) {
      print('💡 Не удалось подключиться к серверу. Проверьте:');
      print('   - Запущен ли MySQL сервер');
      print('   - Правильный ли host и port');
    }
    exit(1);
  } catch (e) {
    print('❌ Неожиданная ошибка: $e');
    exit(1);
  }
}

