import 'dart:io';

/// Скрипт для проверки, какая база данных настроена
Future<void> main() async {
  print('🔍 Проверка настроек базы данных...\n');

  // Читаем .env файл напрямую
  final envFile = File('.env');
  Map<String, String> env = {};
  
  if (await envFile.exists()) {
    print('✅ Файл .env найден\n');
    final lines = await envFile.readAsLines();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final parts = trimmed.split('=');
      if (parts.length >= 2) {
        env[parts[0].trim()] = parts.sublist(1).join('=').trim();
      }
    }
  } else {
    print('⚠️  Файл .env не найден\n');
  }

  print('📊 Текущие настройки:');
  print('   MYSQL_HOST: ${env['MYSQL_HOST'] ?? 'localhost'}');
  print('   MYSQL_PORT: ${env['MYSQL_PORT'] ?? '3306'}');
  print('   MYSQL_USER: ${env['MYSQL_USER'] ?? 'root'}');
  print('   MYSQL_DATABASE: ${env['MYSQL_DATABASE'] ?? 'pharmacy_db'}\n');

  final missingKeys = <String>[];
  for (final key in ['MYSQL_HOST', 'MYSQL_PORT', 'MYSQL_USER', 'MYSQL_DATABASE']) {
    if (!env.containsKey(key) || env[key]!.isEmpty) {
      missingKeys.add(key);
    }
  }

  if (missingKeys.isNotEmpty) {
    print('⚠️  Обнаружены отсутствующие параметры: ${missingKeys.join(', ')}');
    print('   Пожалуйста, заполните их в файле .env\n');
  } else {
    print('✅ Все необходимые параметры MySQL присутствуют в .env\n');
  }

  print('💡 Рекомендация:');
  print('   Убедитесь, что база данных ${env['MYSQL_DATABASE'] ?? 'pharmacy_db'} существует и');
  print('   пользователь ${env['MYSQL_USER'] ?? 'root'} имеет права на чтение/запись.\n');
}

