import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_notifier.dart';

/// Утилита для работы с темой и цветами из настроек
class ThemeUtils {
  /// Получить основной цвет из настроек
  static Color getPrimaryColor(WidgetRef ref) {
    final settingsAsync = ref.read(appSettingsStateProvider);
    return settingsAsync.maybeWhen(
      data: (settings) => _parseColor(settings.primaryColor),
      orElse: () => const Color(0xFF1976D2),
    );
  }

  /// Получить основной цвет из BuildContext (через Theme)
  static Color getPrimaryColorFromContext(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  /// Парсинг цвета из hex строки
  static Color _parseColor(String colorCode) {
    try {
      return Color(int.parse(colorCode.replaceAll('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF1976D2);
    }
  }

  /// Получить цвет для кнопки из темы
  static Color getButtonColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  /// Получить цвет текста для кнопки из темы
  static Color getButtonTextColor(BuildContext context) {
    return Theme.of(context).colorScheme.onPrimary;
  }

  /// Получить цвет фона из темы
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  /// Получить цвет поверхности из темы
  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  /// Получить цвет текста из темы
  static Color getTextColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }
}

