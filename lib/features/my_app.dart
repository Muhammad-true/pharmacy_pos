import 'package:dorukhonai_man/core/localization/app_localizations.dart';
import 'package:dorukhonai_man/core/providers/settings_notifier.dart';
import 'package:dorukhonai_man/core/theme/app_theme.dart';
import 'package:dorukhonai_man/features/auth/screens/login_screen.dart';
import 'package:dorukhonai_man/features/client/screens/client_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

class MyApp extends ConsumerStatefulWidget {
  final Map<String, dynamic>? windowArgs;

  const MyApp({super.key, this.windowArgs});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Используем addPostFrameCallback, чтобы окно успело полностью загрузиться
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Если это окно клиента, устанавливаем его позицию и размер
      if (widget.windowArgs != null && widget.windowArgs!['route'] == 'client') {
        _setupClientWindow();
      } else {
        // Если это главное окно кассы, устанавливаем полноэкранный режим
        _setupMainWindow();
      }
    });
  }

  /// Настройка главного окна кассы - окно внизу экрана, оставляя место для панели задач
  Future<void> _setupMainWindow() async {
    try {
      // Небольшая задержка для полной инициализации окна
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (kDebugMode) {
        print('🔧 Настраиваем главное окно кассы внизу экрана');
      }
      
      // Получаем размеры основного экрана
      double screenWidth = 1920.0;
      double screenHeight = 1080.0;
      double screenX = 0.0;
      double screenY = 0.0;
      
      try {
        final MethodChannel channel = const MethodChannel('window_manager');
        List<dynamic>? displaysData;
        
        try {
          displaysData = await channel.invokeMethod('getDisplays');
        } catch (e) {
          try {
            displaysData = await channel.invokeMethod('getAllDisplays');
          } catch (e2) {
            if (kDebugMode) {
              print('⚠️ Не удалось получить информацию о мониторах: $e2');
            }
          }
        }
        
        if (displaysData != null && displaysData.isNotEmpty) {
          // Ищем основной монитор
          for (var displayData in displaysData) {
            final display = displayData as Map<String, dynamic>;
            final bool isPrimary = display['isPrimary'] as bool? ?? false;
            
            if (isPrimary) {
              final bounds = display['bounds'] as Map<String, dynamic>?;
              if (bounds != null) {
                screenX = (bounds['x'] as num).toDouble();
                screenY = (bounds['y'] as num).toDouble();
                screenWidth = (bounds['width'] as num).toDouble();
                screenHeight = (bounds['height'] as num).toDouble();
                if (kDebugMode) {
                  print('✅ Найден основной монитор: ${screenWidth}x${screenHeight} at ($screenX, $screenY)');
                }
                break;
              }
            }
          }
          
          // Если не нашли основной, используем первый
          if (screenWidth == 1920.0 && displaysData.isNotEmpty) {
            final firstDisplay = displaysData[0] as Map<String, dynamic>;
            final bounds = firstDisplay['bounds'] as Map<String, dynamic>?;
            if (bounds != null) {
              screenX = (bounds['x'] as num).toDouble();
              screenY = (bounds['y'] as num).toDouble();
              screenWidth = (bounds['width'] as num).toDouble();
              screenHeight = (bounds['height'] as num).toDouble();
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Ошибка получения размеров экрана, используем значения по умолчанию: $e');
        }
      }
      
      // Высота панели задач Windows (обычно 40-50 пикселей, но может быть больше)
      const double taskbarHeight = 50.0;
      
      // Высота окна - почти на весь экран, но оставляем место для панели задач
      final double windowHeight = screenHeight - taskbarHeight;
      
      // Ширина окна - на всю ширину экрана
      final double windowWidth = screenWidth;
      
      // Позиция окна - внизу экрана
      final double windowX = screenX;
      final double windowY = screenY + taskbarHeight;
      
      if (kDebugMode) {
        print('📍 Устанавливаем окно кассы: ${windowWidth}x${windowHeight} at ($windowX, $windowY)');
      }
      
      // Устанавливаем размер и позицию окна
      await windowManager.setBounds(
        Rect.fromLTWH(
          windowX,
          windowY,
          windowWidth,
          windowHeight,
        ),
      );
      
      // Дополнительно устанавливаем позицию и размер для надежности
      await windowManager.setPosition(Offset(windowX, windowY));
      await windowManager.setSize(Size(windowWidth, windowHeight));
      
      // Убеждаемся, что окно не в полноэкранном режиме
      try {
        await windowManager.setFullScreen(false);
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Не удалось отключить полноэкранный режим: $e');
        }
      }
      
      if (kDebugMode) {
        print('✅ Главное окно кассы установлено внизу экрана: ${windowWidth}x${windowHeight} at ($windowX, $windowY)');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Ошибка настройки главного окна: $e');
        print('❌ StackTrace: $stackTrace');
      }
    }
  }

  Future<void> _setupClientWindow() async {
    try {
      // Небольшая задержка для полной инициализации окна
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Получаем параметры окна из аргументов
      final windowX = widget.windowArgs?['windowX'] as int?;
      final windowY = widget.windowArgs?['windowY'] as int?;
      final windowWidth = widget.windowArgs?['windowWidth'] as int?;
      final windowHeight = widget.windowArgs?['windowHeight'] as int?;
      final isFullScreen = widget.windowArgs?['isFullScreen'] as bool? ?? false;

      if (windowX != null && windowY != null && windowWidth != null && windowHeight != null) {
        if (kDebugMode) {
          print('🔧 Устанавливаем позицию окна клиента: ${windowWidth}x${windowHeight} at ($windowX, $windowY), fullScreen: $isFullScreen');
        }
        
        // Устанавливаем позицию и размер окна
        await windowManager.setBounds(
          Rect.fromLTWH(
            windowX.toDouble(),
            windowY.toDouble(),
            windowWidth.toDouble(),
            windowHeight.toDouble(),
          ),
        );
        
        // Дополнительно устанавливаем позицию через setPosition для надежности
        await windowManager.setPosition(Offset(windowX.toDouble(), windowY.toDouble()));
        await windowManager.setSize(Size(windowWidth.toDouble(), windowHeight.toDouble()));
        
        // Если нужно полноэкранное окно, устанавливаем его
        if (isFullScreen) {
          try {
            // Убираем рамки окна для полноэкранного режима (опционально)
            await windowManager.setFullScreen(true);
            if (kDebugMode) {
              print('✅ Окно клиента установлено в полноэкранный режим');
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Не удалось установить полноэкранный режим: $e');
            }
            // Если полноэкранный режим не поддерживается, просто используем максимальный размер
          }
        }
        
        if (kDebugMode) {
          print('✅ Окно клиента позиционировано: ${windowWidth}x${windowHeight} at ($windowX, $windowY)');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ Параметры окна не найдены в аргументах');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Ошибка установки позиции окна клиента: $e');
        print('❌ StackTrace: $stackTrace');
      }
    }
  }

  Color _parseColor(String colorCode) {
    try {
      return Color(int.parse(colorCode.replaceAll('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF1976D2);
    }
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsStateProvider);

    Widget home = const LoginScreen();

    // Для окон клиента показываем экран клиента напрямую
    if (widget.windowArgs != null && widget.windowArgs!['route'] == 'client') {
      final targetUserId = widget.windowArgs?['userId'];
      home = ClientScreen(
        targetUserId: targetUserId is int ? targetUserId : null,
      );
    }

    return settingsAsync.when(
      data: (settings) {
        final primaryColor = _parseColor(settings.primaryColor);
        final appTitle = '${settings.pharmacyName} - POS';

        return MaterialApp(
          title: appTitle,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ru'),
            Locale('uz'),
            Locale('en'),
            Locale('tj'),
            Locale('kk'),
            Locale('ky'),
          ],
          themeMode: _parseThemeMode(settings.themeMode),
          theme: AppTheme.lightTheme(primaryColor),
          darkTheme: AppTheme.darkTheme(primaryColor),
          home: home,
        );
      },
      loading: () {
        return MaterialApp(
          title: 'libiss pos',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ru'),
            Locale('uz'),
            Locale('en'),
            Locale('tj'),
            Locale('kk'),
            Locale('ky'),
          ],
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      },
      error: (error, stack) {
        final loc = ref.watch(appLocalizationsProvider);
        return MaterialApp(
          title: 'libiss pos',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ru'),
            Locale('uz'),
            Locale('en'),
            Locale('tj'),
            Locale('kk'),
            Locale('ky'),
          ],
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    loc.settingsLoadError,
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(appSettingsStateProvider);
                    },
                    child: Text(loc.retry),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
