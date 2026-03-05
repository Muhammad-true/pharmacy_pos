import 'dart:async';
import 'dart:io';

import '../core/config/app_config.dart';
import '../core/errors/error_handler.dart';
import '../core/repositories/settings_repository.dart';
import 'update_service.dart';

class UpdateScheduler {
  static Timer? _timer;
  static bool _started = false;
  static const _interval = Duration(minutes: 30);
  static const _lastCheckKey = 'update_last_check_date';
  static const _autoUpdateKey = 'update_auto_enabled';

  static void start(SettingsRepository settingsRepository) {
    if (_started) return;
    _started = true;
    _timer = Timer.periodic(_interval, (_) => _runIfNeeded(settingsRepository));
    _runIfNeeded(settingsRepository);
  }

  static Future<void> _runIfNeeded(SettingsRepository settingsRepository) async {
    try {
      final autoValue = await settingsRepository.getSetting(_autoUpdateKey);
      final autoEnabled = autoValue == null
          ? true
          : autoValue.toLowerCase() == 'true';
      if (!autoEnabled) return;

      final updateUrl = AppConfig.instance.updateUrl.trim();
      if (updateUrl.isEmpty) return;
      if (!await _hasInternet()) return;

      final lastDate = await settingsRepository.getSetting(_lastCheckKey);
      final today = _todayKey();
      if (lastDate == today) return;

      final service = UpdateService();
      final update = await service.checkForUpdates();
      if (update == null || update.url == null || update.url!.isEmpty) {
        await settingsRepository.setSetting(_lastCheckKey, today);
        return;
      }

      final file = await service.downloadUpdate(update.url!, update.version);
      await service.installUpdate(file);
      await settingsRepository.setSetting(_lastCheckKey, today);
    } catch (e, stack) {
      ErrorHandler.instance.handleError(e, stackTrace: stack);
    }
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
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

