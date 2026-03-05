import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/app_settings.dart';
import '../providers/repository_providers.dart';

part 'settings_notifier.g.dart';

/// Провайдер для настроек приложения
@Riverpod(keepAlive: true)
class AppSettingsState extends _$AppSettingsState {
  @override
  Future<AppSettings> build() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    try {
      return await settingsRepo.getSettings();
    } catch (e) {
      // Если ошибка, возвращаем настройки по умолчанию
      return AppSettings.defaults();
    }
  }

  /// Обновить настройки
  Future<void> updateSettings(AppSettings newSettings) async {
    state = const AsyncValue.loading();
    try {
      final settingsRepo = ref.read(settingsRepositoryProvider);
      await settingsRepo.saveSettings(newSettings);
      state = AsyncValue.data(newSettings);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Обновить имя аптеки
  Future<void> updatePharmacyName(String name) async {
    final current = await future;
    await updateSettings(current.copyWith(pharmacyName: name));
  }

  /// Обновить язык
  Future<void> updateLanguage(String language) async {
    final current = await future;
    await updateSettings(current.copyWith(language: language));
  }

  /// Обновить тему
  Future<void> updateThemeMode(String themeMode) async {
    final current = await future;
    await updateSettings(current.copyWith(themeMode: themeMode));
  }

  /// Обновить основной цвет
  Future<void> updatePrimaryColor(String color) async {
    final current = await future;
    await updateSettings(current.copyWith(primaryColor: color));
  }
}

