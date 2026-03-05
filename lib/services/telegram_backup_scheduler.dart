import 'dart:async';
import 'dart:io';

import '../core/di/dependency_injection.dart';
import '../core/errors/error_handler.dart';
import 'telegram_export_service.dart';

class TelegramBackupScheduler {
  static Timer? _timer;
  static bool _started = false;
  static const _interval = Duration(minutes: 30);
  static const _lastExportKey = 'telegram_last_export_date';

  static void start() {
    if (_started) return;
    _started = true;
    _timer = Timer.periodic(_interval, (_) => _runIfNeeded());
    _runIfNeeded();
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  static Future<void> _runIfNeeded() async {
    try {
      final settingsRepo = getSettingsRepository();
      final settings = await settingsRepo.getSettings();
      if (!settings.telegramAutoExportEnabled) return;
      if (settings.telegramBotToken == null ||
          settings.telegramBotToken!.trim().isEmpty ||
          settings.telegramChatId == null ||
          settings.telegramChatId!.trim().isEmpty) {
        return;
      }

      if (!await _hasInternet()) return;

      final lastDate = await settingsRepo.getSetting(_lastExportKey);
      final today = _todayKey();
      if (lastDate == today) return;

      final exporter = TelegramExportService(settingsRepository: settingsRepo);
      await exporter.sendExportToTelegram();
      await settingsRepo.setSetting(_lastExportKey, today);
    } catch (e, stack) {
      ErrorHandler.instance.handleError(e, stackTrace: stack);
    }
  }

  static String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('api.telegram.org')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

