import 'dart:async';
import 'dart:convert';

import 'package:dorukhonai_man/features/my_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/config/app_config.dart';
import 'core/database/database_provider.dart';
import 'core/di/dependency_injection.dart';
import 'core/errors/error_handler.dart';
import 'services/telegram_backup_scheduler.dart';
import 'services/update_scheduler.dart';

void main(List<String> args) async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await ErrorHandler.instance.init();

      // Инициализация window_manager для работы с мониторами
      try {
        await windowManager.ensureInitialized();
      } catch (e) {
        ErrorHandler.instance.warning(
          'Ошибка инициализации window_manager: $e',
        );
        // Продолжаем работу даже при ошибке
      }

      // Инициализация конфигурации
      try {
        await AppConfig.init();
        ErrorHandler.instance.debug('Конфигурация загружена');
      } catch (e) {
        ErrorHandler.instance.warning('Ошибка загрузки конфигурации: $e');
      }

      // Инициализация базы данных
      try {
        await DatabaseProvider.getDatabase();
        ErrorHandler.instance.debug('База данных инициализирована');
      } catch (e, stackTrace) {
        ErrorHandler.instance.handleError(e, stackTrace: stackTrace);
        ErrorHandler.instance.warning(
          'Ошибка инициализации БД в main: $e. БД будет инициализирована при первом использовании.',
        );
        // Продолжаем работу - БД будет инициализирована при первом использовании
        // через повторную попытку в репозиториях
      }

      // Инициализация Dependency Injection
      try {
        await setupDependencyInjection();
        ErrorHandler.instance.debug('Dependency Injection инициализирован');
      } catch (e) {
        ErrorHandler.instance.handleError(e);
        // Продолжаем работу даже при ошибке DI (для разработки)
      }

      // Планировщик автоэкспорта в Telegram (1 раз в день при наличии интернета)
      TelegramBackupScheduler.start();

      // Планировщик автообновления (1 раз в день при наличии интернета)
      UpdateScheduler.start(getSettingsRepository());

      Map<String, dynamic>? windowArgs;
      for (final arg in args) {
        if (arg.trim().startsWith('{')) {
          try {
            windowArgs = jsonDecode(arg) as Map<String, dynamic>;
          } catch (_) {
            windowArgs = null;
          }
          break;
        }
      }

      runApp(ProviderScope(child: MyApp(windowArgs: windowArgs)));
    },
    (error, stack) {
      ErrorHandler.instance.handleError(error, stackTrace: stack);
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        // Отключаем вывод логов в консоль
        if (kDebugMode) {
          return;
        }
      },
    ),
  );
}
