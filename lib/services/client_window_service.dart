import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../features/cashier/models/product.dart';
import '../features/cashier/models/receipt.dart';
import '../features/cashier/models/receipt_item.dart';
import '../features/shared/models/client.dart';

/// Сервис для управления окном клиента
/// Хранит текущий чек и клиента для отображения в окне клиента
/// Использует прямой доступ к файлам для синхронизации между процессами multi-window
/// (SharedPreferences не синхронизируется между процессами в desktop приложениях)
class ClientWindowService {
  static final ClientWindowService _instance = ClientWindowService._internal();
  factory ClientWindowService() => _instance;
  ClientWindowService._internal();

  Receipt? _currentReceipt;
  Client? _currentClient;
  Function(Receipt?, Client?)? _onDataChanged;
  Timer? _pollingTimer;
  String? _lastReceiptJson; // Для отслеживания изменений
  String? _lastClientJson; // Для отслеживания изменений
  static const String _receiptFileName = 'client_window_receipt.json';
  static const String _clientFileName = 'client_window_client.json';
  File? _receiptFile;
  File? _clientFile;
  bool _filesInitialized = false;

  // Мьютекс для предотвращения параллельной записи файлов
  Completer<void>? _writeCompleter;

  // Кеш метаданных файлов для оптимизации - проверяем только размер и время модификации
  int? _lastReceiptFileSize;
  DateTime? _lastReceiptFileModified;
  int? _lastClientFileSize;
  DateTime? _lastClientFileModified;

  // Дебаунсинг для callback - не вызываем сразу, а ждем немного
  Timer? _callbackDebounceTimer;
  bool _pendingCallback = false;

  // В multi-window приложениях каждый процесс имеет свою память,
  // поэтому polling должен запускаться в каждом процессе независимо
  // Используем проверку таймера вместо глобального флага
  bool get _isPollingActive => _pollingTimer != null && _pollingTimer!.isActive;

  /// Инициализация сервиса
  /// В multi-window приложениях должен вызываться в каждом процессе отдельно
  /// В процессе клиента должен вызываться ПОСЛЕ subscribe(), чтобы callback был установлен
  Future<void> init() async {
    // Если polling уже запущен в этом процессе, не запускаем повторно
    if (_isPollingActive) {
      final hasCallback = _onDataChanged != null;
      final processType = hasCallback ? '[КЛИЕНТ]' : '[КАССИР]';
      if (kDebugMode) {
        print(
          '🔵 $processType ClientWindowService: Polling уже активен в этом процессе, пропускаем повторную инициализацию',
        );
      }
      return;
    }

    final hasCallback = _onDataChanged != null;
    final processType = hasCallback ? '[КЛИЕНТ]' : '[КАССИР]';
    if (kDebugMode) {
      print(
        '🔵 $processType ClientWindowService: 🚀🚀🚀 ИНИЦИАЛИЗАЦИЯ... Callback: ${hasCallback ? "✅ ЕСТЬ" : "❌ НЕТ"}',
      );
    }

    // Инициализируем файлы для синхронизации
    if (!_filesInitialized) {
      await _initializeFiles();
    }

    // ВАЖНО: Для процесса клиента НЕ устанавливаем _lastReceiptJson при загрузке,
    // чтобы polling мог обнаружить изменения с самого начала
    // Для процесса кассира это не важно, так как там нет callback
    final isClientProcess = hasCallback;

    if (isClientProcess) {
      if (kDebugMode) {
        print(
          '🔵 [КЛИЕНТ] ClientWindowService: Это процесс клиента - загружаем данные БЕЗ установки _lastReceiptJson',
        );
      }
      // Загружаем данные, но НЕ устанавливаем _lastReceiptJson
      // Это позволит polling обнаружить изменения при первом же обновлении
      await _loadFromFilesWithoutSettingLast();
    } else {
      if (kDebugMode) {
        print(
          '🔵 [КАССИР] ClientWindowService: Это процесс кассира - загружаем данные как обычно',
        );
      }
      // Для процесса кассира загружаем данные как обычно
      await _loadFromFiles();
    }

    // Запускаем периодическую проверку изменений (для синхронизации между процессами)
    // ВАЖНО: Для процесса кассира polling не нужен - он только записывает данные
    // Для процесса клиента используем более редкий polling (1000ms) для снижения нагрузки
    _pollingTimer?.cancel(); // На всякий случай отменяем предыдущий таймер

    if (hasCallback) {
      // Только для процесса клиента запускаем polling
      // Используем интервал 1000ms (1 секунда) вместо 200ms для снижения нагрузки
      _pollingTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
        _checkForUpdates();
      });
      if (kDebugMode) {
        print(
          '🔵 [КЛИЕНТ] ClientWindowService: ✅✅✅ ИНИЦИАЛИЗАЦИЯ ЗАВЕРШЕНА! Receipt: ${_currentReceipt?.items.length ?? 0} товаров, Polling: ✅ запущен каждые 1000ms, Callback: ✅ установлен',
        );
        print(
          '🔵 [КЛИЕНТ] ClientWindowService: ✅✅✅ Все готово! Polling будет вызывать callback при обнаружении изменений',
        );
      }
    } else {
      // Для процесса кассира polling не запускаем - он только записывает данные
      if (kDebugMode) {
        print(
          '🔵 [КАССИР] ClientWindowService: ✅✅✅ ИНИЦИАЛИЗАЦИЯ ЗАВЕРШЕНА! Receipt: ${_currentReceipt?.items.length ?? 0} товаров, Polling: ❌ НЕ запущен (не нужен для процесса кассира - только запись данных)',
        );
      }
    }
  }

  /// Инициализация файлов для синхронизации
  Future<void> _initializeFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final syncDir = Directory(path.join(appDir.path, 'client_window_sync'));
      if (!await syncDir.exists()) {
        await syncDir.create(recursive: true);
      }

      _receiptFile = File(path.join(syncDir.path, _receiptFileName));
      _clientFile = File(path.join(syncDir.path, _clientFileName));

      _filesInitialized = true;

      final hasCallback = _onDataChanged != null;
      final processType = hasCallback ? '[КЛИЕНТ]' : '[КАССИР]';
      if (kDebugMode) {
        print(
          '🔵 $processType ClientWindowService: Файлы инициализированы. Receipt: ${_receiptFile!.path}',
        );
      }
    } catch (e, stackTrace) {
      final hasCallback = _onDataChanged != null;
      final processType = hasCallback ? '[КЛИЕНТ]' : '[КАССИР]';
      if (kDebugMode) {
        print(
          '❌ $processType ClientWindowService: Ошибка инициализации файлов: $e',
        );
        print('❌ StackTrace: $stackTrace');
      }
      rethrow;
    }
  }

  /// Проверка обновлений из файлов
  /// Оптимизированная версия - сначала проверяет метаданные файлов (размер, время модификации)
  /// Читает файлы только если метаданные изменились
  Future<void> _checkForUpdates() async {
    try {
      // Убеждаемся, что файлы инициализированы
      if (!_filesInitialized || _receiptFile == null || _clientFile == null) {
        await _initializeFiles();
      }

      // ОПТИМИЗАЦИЯ: Сначала проверяем метаданные файлов (размер и время модификации)
      // Это намного быстрее, чем читать весь файл каждый раз
      bool receiptFileChanged = false;
      bool clientFileChanged = false;

      try {
        if (await _receiptFile!.exists()) {
          final stat = await _receiptFile!.stat();
          final fileSize = stat.size;
          final fileModified = stat.modified;

          // Проверяем, изменились ли метаданные файла
          if (fileSize != _lastReceiptFileSize ||
              fileModified != _lastReceiptFileModified) {
            receiptFileChanged = true;
            _lastReceiptFileSize = fileSize;
            _lastReceiptFileModified = fileModified;
          }
        } else {
          // Файл удален - это тоже изменение
          if (_lastReceiptFileSize != null) {
            receiptFileChanged = true;
            _lastReceiptFileSize = null;
            _lastReceiptFileModified = null;
          }
        }
      } catch (e) {
        // Игнорируем ошибки проверки метаданных
        receiptFileChanged = false;
      }

      try {
        if (await _clientFile!.exists()) {
          final stat = await _clientFile!.stat();
          final fileSize = stat.size;
          final fileModified = stat.modified;

          // Проверяем, изменились ли метаданные файла
          if (fileSize != _lastClientFileSize ||
              fileModified != _lastClientFileModified) {
            clientFileChanged = true;
            _lastClientFileSize = fileSize;
            _lastClientFileModified = fileModified;
          }
        } else {
          // Файл удален - это тоже изменение
          if (_lastClientFileSize != null) {
            clientFileChanged = true;
            _lastClientFileSize = null;
            _lastClientFileModified = null;
          }
        }
      } catch (e) {
        // Игнорируем ошибки проверки метаданных
        clientFileChanged = false;
      }

      // Если метаданные не изменились, ничего не делаем - это оптимизация
      if (!receiptFileChanged && !clientFileChanged) {
        return;
      }

      // Только если метаданные изменились, читаем файлы
      String? receiptJson;
      String? clientJson;

      try {
        if (await _receiptFile!.exists()) {
          receiptJson = await _receiptFile!.readAsString();
        }
      } catch (e) {
        // Если файл не существует или заблокирован, продолжаем с null
        receiptJson = null;
      }

      try {
        if (await _clientFile!.exists()) {
          clientJson = await _clientFile!.readAsString();
        }
      } catch (e) {
        // Если файл не существует или заблокирован, продолжаем с null
        clientJson = null;
      }

      // Сравниваем JSON строки только если метаданные изменились
      bool receiptChanged = receiptJson != _lastReceiptJson;
      bool clientChanged = clientJson != _lastClientJson;

      // Обрабатываем изменения только если JSON действительно изменился
      if (receiptChanged || clientChanged) {
        // Получаем информацию о процессе для логирования
        final hasCallback = _onDataChanged != null;
        final processType = hasCallback ? '[КЛИЕНТ]' : '[КАССИР]';

        Receipt? newReceipt;
        Client? newClient;

        // Парсим чек
        if (receiptJson != null && receiptJson.isNotEmpty) {
          try {
            final receiptMap = jsonDecode(receiptJson) as Map<String, dynamic>;
            newReceipt = _receiptFromJson(receiptMap);
          } catch (e, stackTrace) {
            if (kDebugMode) {
              print(
                '❌ $processType ClientWindowService: Ошибка парсинга чека: $e',
              );
              print('❌ StackTrace: $stackTrace');
              print(
                '❌ JSON: ${receiptJson.substring(0, receiptJson.length > 200 ? 200 : receiptJson.length)}...',
              );
            }
            // Очищаем повреждённый файл
            try {
              if (_receiptFile != null && await _receiptFile!.exists()) {
                await _receiptFile!.delete();
                if (kDebugMode) {
                  print(
                    '🔵 $processType ClientWindowService: Повреждённый файл чека удалён',
                  );
                }
              }
              receiptJson = null;
              newReceipt = null;
            } catch (deleteError) {
              if (kDebugMode) {
                print(
                  '❌ $processType ClientWindowService: Ошибка удаления повреждённого файла: $deleteError',
                );
              }
            }
          }
        } else {
          newReceipt = null;
        }

        // Парсим клиента
        if (clientJson != null && clientJson.isNotEmpty) {
          try {
            final clientMap = jsonDecode(clientJson) as Map<String, dynamic>;
            newClient = _clientFromJson(clientMap);
          } catch (e) {
            if (kDebugMode) {
              print(
                '❌ $processType ClientWindowService: Ошибка парсинга клиента: $e',
              );
            }
            // Очищаем повреждённый файл
            try {
              if (_clientFile != null && await _clientFile!.exists()) {
                await _clientFile!.delete();
                if (kDebugMode) {
                  print(
                    '🔵 $processType ClientWindowService: Повреждённый файл клиента удалён',
                  );
                }
              }
              clientJson = null;
              newClient = null;
            } catch (deleteError) {
              if (kDebugMode) {
                print(
                  '❌ $processType ClientWindowService: Ошибка удаления повреждённого файла: $deleteError',
                );
              }
            }
          }
        }

        // Обновляем данные ТОЛЬКО после успешного парсинга
        // ВАЖНО: Обновляем _lastReceiptJson и _lastClientJson СРАЗУ после парсинга,
        // чтобы следующая проверка не обнаружила это же изменение снова
        _lastReceiptJson = receiptJson;
        _lastClientJson = clientJson;
        _currentReceipt = newReceipt;
        _currentClient = newClient;

        // Вызываем callback ТОЛЬКО если он установлен (только в процессе клиента)
        // Используем дебаунсинг - не вызываем сразу, а ждем 300ms
        // Это предотвращает множественные обновления UI при быстрых изменениях
        if (hasCallback && _onDataChanged != null) {
          _pendingCallback = true;
          _callbackDebounceTimer?.cancel();
          _callbackDebounceTimer = Timer(const Duration(milliseconds: 300), () {
            if (_pendingCallback && _onDataChanged != null) {
              try {
                _onDataChanged!(_currentReceipt, _currentClient);
              } catch (e, stackTrace) {
                if (kDebugMode) {
                  print(
                    '❌ [КЛИЕНТ] ClientWindowService: Ошибка при вызове callback: $e',
                  );
                  print('❌ StackTrace: $stackTrace');
                }
              }
              _pendingCallback = false;
            }
          });
        }
      }
    } catch (e) {
      // Убираем избыточное логирование - ошибки проверки обновлений не критичны
      // Логируем только если это не просто отсутствие файла
      if (!e.toString().contains('No such file') &&
          !e.toString().contains('FileSystemException')) {
        if (kDebugMode) {
          print('❌ ClientWindowService: Ошибка в _checkForUpdates: $e');
        }
      }
    }
  }

  /// Загрузка данных из файлов
  /// Устанавливает _lastReceiptJson и _lastClientJson (для процесса кассира)
  Future<void> _loadFromFiles() async {
    try {
      if (!_filesInitialized || _receiptFile == null || _clientFile == null) {
        await _initializeFiles();
      }

      String? receiptJson;
      String? clientJson;

      try {
        if (await _receiptFile!.exists()) {
          receiptJson = await _receiptFile!.readAsString();
        }
      } catch (e) {
        receiptJson = null;
      }

      try {
        if (await _clientFile!.exists()) {
          clientJson = await _clientFile!.readAsString();
        }
      } catch (e) {
        clientJson = null;
      }

      final hasCallback = _onDataChanged != null;
      final processType = hasCallback ? '[КЛИЕНТ]' : '[КАССИР]';

      if (kDebugMode) {
        print(
          '🔵 $processType ClientWindowService: Загрузка из файлов. Receipt JSON: ${receiptJson != null ? "есть (${receiptJson.length} символов)" : "null"}',
        );
      }

      if (receiptJson != null && receiptJson.isNotEmpty) {
        try {
          final receiptMap = jsonDecode(receiptJson) as Map<String, dynamic>;
          final loadedReceipt = _receiptFromJson(receiptMap);
          _currentReceipt = loadedReceipt;
          _lastReceiptJson =
              receiptJson; // Устанавливаем последнее известное состояние
          if (kDebugMode) {
            print(
              '🔵 $processType ClientWindowService: Чек загружен. Товаров: ${loadedReceipt.items.length}, _lastReceiptJson: ${_lastReceiptJson?.length ?? 0} символов',
            );
          }
        } catch (e, stackTrace) {
          if (kDebugMode) {
            print('❌ $processType ClientWindowService: Ошибка загрузки чека: $e');
            print('❌ StackTrace: $stackTrace');
          }
          // Очищаем повреждённый файл
          try {
            if (_receiptFile != null && await _receiptFile!.exists()) {
              await _receiptFile!.delete();
              if (kDebugMode) {
                print(
                  '🔵 $processType ClientWindowService: Повреждённый файл чека удалён при загрузке',
                );
              }
            }
            receiptJson = null;
            _lastReceiptJson = null;
          } catch (deleteError) {
            print(
              '❌ $processType ClientWindowService: Ошибка удаления повреждённого файла: $deleteError',
            );
          }
        }
      } else {
        // Если JSON пустой, сбрасываем _lastReceiptJson
        _lastReceiptJson = null;
        if (kDebugMode) {
          print(
            '🔵 $processType ClientWindowService: Receipt JSON пустой, _lastReceiptJson сброшен',
          );
        }
      }

      if (clientJson != null && clientJson.isNotEmpty) {
        try {
          final clientMap = jsonDecode(clientJson) as Map<String, dynamic>;
          _currentClient = _clientFromJson(clientMap);
          _lastClientJson = clientJson;
          if (kDebugMode) {
            print(
              '🔵 $processType ClientWindowService: Клиент загружен. Имя: ${_currentClient?.name}',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print(
              '❌ $processType ClientWindowService: Ошибка загрузки клиента: $e',
            );
          }
          // Очищаем повреждённый файл
          try {
            if (_clientFile != null && await _clientFile!.exists()) {
              await _clientFile!.delete();
              if (kDebugMode) {
                print(
                  '🔵 $processType ClientWindowService: Повреждённый файл клиента удалён при загрузке',
                );
              }
            }
            clientJson = null;
            _lastClientJson = null;
          } catch (deleteError) {
            print(
              '❌ $processType ClientWindowService: Ошибка удаления повреждённого файла: $deleteError',
            );
          }
        }
      } else {
        _lastClientJson = null;
      }
    } catch (e, stackTrace) {
      final hasCallback = _onDataChanged != null;
      final processType = hasCallback ? '[КЛИЕНТ]' : '[КАССИР]';
      if (kDebugMode) {
        print(
          '❌ $processType ClientWindowService: Ошибка загрузки из файлов: $e',
        );
        print('❌ StackTrace: $stackTrace');
      }
    }
  }

  /// Загрузка данных из файлов БЕЗ установки _lastReceiptJson и _lastClientJson
  /// Используется в процессе клиента, чтобы polling мог обнаружить изменения при первом же обновлении
  Future<void> _loadFromFilesWithoutSettingLast() async {
    try {
      if (!_filesInitialized || _receiptFile == null || _clientFile == null) {
        await _initializeFiles();
      }

      String? receiptJson;
      String? clientJson;

      try {
        if (await _receiptFile!.exists()) {
          receiptJson = await _receiptFile!.readAsString();
        }
      } catch (e) {
        receiptJson = null;
      }

      try {
        if (await _clientFile!.exists()) {
          clientJson = await _clientFile!.readAsString();
        }
      } catch (e) {
        clientJson = null;
      }

      if (kDebugMode) {
        print(
          '🔵 [КЛИЕНТ] ClientWindowService: Загрузка БЕЗ установки _lastReceiptJson. Receipt JSON: ${receiptJson != null ? "есть (${receiptJson.length} символов)" : "null"}',
        );
      }

      if (receiptJson != null && receiptJson.isNotEmpty) {
        try {
          final receiptMap = jsonDecode(receiptJson) as Map<String, dynamic>;
          final loadedReceipt = _receiptFromJson(receiptMap);
          _currentReceipt = loadedReceipt;
          // НЕ устанавливаем _lastReceiptJson! Это позволит polling обнаружить изменения
          if (kDebugMode) {
            print(
              '🔵 [КЛИЕНТ] ClientWindowService: Чек загружен. Товаров: ${loadedReceipt.items.length}, _lastReceiptJson: НЕ установлен (будет обнаружено при изменении)',
            );
          }
        } catch (e, stackTrace) {
          if (kDebugMode) {
            print('❌ [КЛИЕНТ] ClientWindowService: Ошибка загрузки чека: $e');
            print('❌ StackTrace: $stackTrace');
          }
          // Очищаем повреждённый файл
          try {
            if (_receiptFile != null && await _receiptFile!.exists()) {
              await _receiptFile!.delete();
              if (kDebugMode) {
                print(
                  '🔵 [КЛИЕНТ] ClientWindowService: Повреждённый файл чека удалён при загрузке',
                );
              }
            }
            receiptJson = null;
            _lastReceiptJson = null;
          } catch (deleteError) {
            print(
              '❌ [КЛИЕНТ] ClientWindowService: Ошибка удаления повреждённого файла: $deleteError',
            );
          }
        }
      } else {
        _lastReceiptJson = null;
        if (kDebugMode) {
          print(
            '🔵 [КЛИЕНТ] ClientWindowService: Receipt JSON пустой, _lastReceiptJson: null',
          );
        }
      }

      if (clientJson != null && clientJson.isNotEmpty) {
        try {
          final clientMap = jsonDecode(clientJson) as Map<String, dynamic>;
          _currentClient = _clientFromJson(clientMap);
          // НЕ устанавливаем _lastClientJson! Это позволит polling обнаружить изменения
          if (kDebugMode) {
            print(
              '🔵 [КЛИЕНТ] ClientWindowService: Клиент загружен. Имя: ${_currentClient?.name}, _lastClientJson: НЕ установлен',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ [КЛИЕНТ] ClientWindowService: Ошибка загрузки клиента: $e');
          }
          // Очищаем повреждённый файл
          try {
            if (_clientFile != null && await _clientFile!.exists()) {
              await _clientFile!.delete();
              if (kDebugMode) {
                print(
                  '🔵 [КЛИЕНТ] ClientWindowService: Повреждённый файл клиента удалён при загрузке',
                );
              }
            }
            clientJson = null;
            _lastClientJson = null;
          } catch (deleteError) {
            print(
              '❌ [КЛИЕНТ] ClientWindowService: Ошибка удаления повреждённого файла: $deleteError',
            );
          }
        }
      } else {
        _lastClientJson = null;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [КЛИЕНТ] ClientWindowService: Ошибка загрузки из файлов: $e');
        print('❌ StackTrace: $stackTrace');
      }
    }
  }

  /// Сохранение данных в файлы
  /// Использует мьютекс для предотвращения параллельных записей
  /// НЕ обновляет _lastReceiptJson и _lastClientJson, чтобы polling мог обнаружить изменения
  Future<void> _saveToFiles() async {
    // Ждем завершения предыдущей записи, если она выполняется
    if (_writeCompleter != null) {
      await _writeCompleter!.future;
    }

    // Создаем новый completer для текущей операции записи
    final completer = Completer<void>();
    _writeCompleter = completer;

    try {
      if (!_filesInitialized || _receiptFile == null || _clientFile == null) {
        await _initializeFiles();
      }

      final hasCallback = _onDataChanged != null;
      final processType = hasCallback ? '[КЛИЕНТ]' : '[КАССИР]';

      String? receiptJson;
      if (_currentReceipt != null) {
        try {
          receiptJson = jsonEncode(_receiptToJson(_currentReceipt!));
          // Валидация: проверяем что JSON корректный перед записью
          try {
            jsonDecode(receiptJson); // Проверяем что JSON валидный
          } catch (validationError) {
            if (kDebugMode) {
              print(
                '❌ $processType ClientWindowService: JSON невалидный перед записью! $validationError',
              );
            }
            completer.completeError(validationError);
            return;
          }
          // Записываем напрямую в файл (атомарная операция)
          await _receiptFile!.writeAsString(receiptJson);
          // НЕ обновляем _lastReceiptJson здесь, чтобы polling мог обнаружить изменения
        } catch (e, stackTrace) {
          if (kDebugMode) {
            print(
              '❌ $processType ClientWindowService: Ошибка сохранения чека: $e',
            );
            print('❌ StackTrace: $stackTrace');
          }
          completer.completeError(e);
          return;
        }
      } else {
        // Удаляем файл, если чека нет
        try {
          if (await _receiptFile!.exists()) {
            await _receiptFile!.delete();
          }
        } catch (e) {
          // Игнорируем ошибки удаления
        }
      }

      String? clientJson;
      if (_currentClient != null) {
        try {
          clientJson = jsonEncode(_clientToJson(_currentClient!));
          // Валидация: проверяем что JSON корректный перед записью
          try {
            jsonDecode(clientJson); // Проверяем что JSON валидный
          } catch (validationError) {
            if (kDebugMode) {
              print(
                '❌ $processType ClientWindowService: JSON невалидный перед записью! $validationError',
              );
            }
            completer.completeError(validationError);
            return;
          }
          // Записываем напрямую в файл (атомарная операция)
          await _clientFile!.writeAsString(clientJson);
        } catch (e) {
          if (kDebugMode) {
            print(
              '❌ $processType ClientWindowService: Ошибка сохранения клиента: $e',
            );
          }
          completer.completeError(e);
          return;
        }
      } else {
        // Удаляем файл, если клиента нет
        try {
          if (await _clientFile!.exists()) {
            await _clientFile!.delete();
          }
        } catch (e) {
          // Игнорируем ошибки удаления
        }
      }

      completer.complete();
    } catch (e, stackTrace) {
      final hasCallback = _onDataChanged != null;
      final processType = hasCallback ? '[КЛИЕНТ]' : '[КАССИР]';
      if (kDebugMode) {
        print(
          '❌ $processType ClientWindowService: Ошибка сохранения в файлы: $e',
        );
        print('❌ StackTrace: $stackTrace');
      }
      completer.completeError(e);
    } finally {
      // Очищаем completer только если это текущая операция
      if (_writeCompleter == completer) {
        _writeCompleter = null;
      }
    }
  }

  /// Установить текущий чек и клиента
  /// Сохраняет данные в файлы, но НЕ вызывает callback
  /// Callback будет вызван автоматически через polling в процессе клиента
  Future<void> setReceiptAndClient(Receipt receipt, Client client) async {
    final hasCallback = _onDataChanged != null;
    final processType = hasCallback ? '[КЛИЕНТ]' : '[КАССИР]';
    if (kDebugMode) {
      print(
        '🔵 $processType ClientWindowService: setReceiptAndClient вызван. Товаров: ${receipt.items.length}, Клиент: ${client.name}',
      );
    }
    _currentReceipt = receipt;
    _currentClient = client;
    // Сохраняем в файлы - polling в процессе клиента обнаружит изменения
    await _saveToFiles();
    // НЕ вызываем callback здесь - это делается только через polling в процессе клиента
  }

  /// Обновить только чек
  /// Сохраняет данные в файлы, но НЕ вызывает callback
  /// Callback будет вызван автоматически через polling в процессе клиента
  Future<void> updateReceipt(Receipt receipt) async {
    final hasCallback = _onDataChanged != null;
    final processType = hasCallback ? '[КЛИЕНТ]' : '[КАССИР]';
    if (kDebugMode) {
      print(
        '🔵 $processType ClientWindowService: updateReceipt вызван. Товаров: ${receipt.items.length}',
      );
    }
    _currentReceipt = receipt;
    // Сохраняем в файлы - polling в процессе клиента обнаружит изменения
    await _saveToFiles();
    // НЕ вызываем callback здесь - это делается только через polling в процессе клиента
  }

  /// Получить текущий чек
  Receipt? get currentReceipt {
    return _currentReceipt;
  }

  /// Получить текущего клиента
  Client? get currentClient {
    return _currentClient;
  }

  /// Подписаться на изменения данных
  /// Вызывается ТОЛЬКО в процессе клиента
  /// ВАЖНО: Должен вызываться ДО init(), чтобы callback был установлен при запуске polling
  void subscribe(Function(Receipt?, Client?) onDataChanged) {
    print('🔵 [КЛИЕНТ] ClientWindowService: 📞📞📞 ПОДПИСКА НА ОБНОВЛЕНИЯ');
    _onDataChanged = onDataChanged;
    print(
      '🔵 [КЛИЕНТ] ClientWindowService: ✅ Callback установлен: ${_onDataChanged != null}',
    );

    // Если polling уже запущен (например, если init() был вызван до subscribe), это проблема
    // В этом случае polling уже работает, но callback не был установлен при его запуске
    // Теперь callback установлен, и polling сможет его использовать
    if (_isPollingActive) {
      print(
        '🔵 [КЛИЕНТ] ClientWindowService: ⚠️ ВНИМАНИЕ! Polling уже активен!',
      );
      print(
        '🔵 [КЛИЕНТ] ClientWindowService: ✅ Теперь callback установлен, polling сможет обновлять UI',
      );
      // Polling уже работает, просто отправляем текущие данные
    } else {
      print(
        '🔵 [КЛИЕНТ] ClientWindowService: Polling не активен, будет запущен в init()',
      );
    }

    // Сразу отправляем текущие данные новому подписчику
    print(
      '🔵 [КЛИЕНТ] ClientWindowService: Отправка начальных данных. Receipt: ${_currentReceipt?.items.length ?? 0} товаров',
    );
    onDataChanged(_currentReceipt, _currentClient);
    print(
      '🔵 [КЛИЕНТ] ClientWindowService: ✅✅✅ Подписка завершена. Callback: ${_onDataChanged != null}, Polling активен: $_isPollingActive',
    );
  }

  /// Отписаться от изменений
  void unsubscribe() {
    print('🔵 ClientWindowService: Отписка от обновлений');
    _onDataChanged = null;
  }

  /// Очистить данные
  Future<void> clear() async {
    print('🔵 ClientWindowService: Очистка данных');
    _currentReceipt = null;
    _currentClient = null;
    await _saveToFiles();
    _onDataChanged?.call(null, null);
  }

  /// Освободить ресурсы
  void dispose() {
    print('🔵 ClientWindowService: Освобождение ресурсов');
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _callbackDebounceTimer?.cancel();
    _callbackDebounceTimer = null;
    _onDataChanged = null;
  }

  // Вспомогательные методы для сериализации/десериализации

  Map<String, dynamic> _receiptToJson(Receipt receipt) {
    return {
      'items': receipt.items.map((item) {
        return {
          'id': item.id,
          'product': {
            'id': item.product.id,
            'name': item.product.name,
            'barcode': item.product.barcode,
            'price': item.product.price,
            'stock': item.product.stock,
            'unit': item.product.unit,
            'unitName': item.product.unitName,
            'unitsPerPackage': item.product.unitsPerPackage,
          },
          'quantity': item.quantity,
          'price': item.price,
          'index': item.index,
          'unitsInPackage': item.unitsInPackage,
        };
      }).toList(),
      'discount': receipt.discount,
      'discountPercent': receipt.discountPercent,
      'discountIsPercent': receipt.discountIsPercent,
      'bonuses': receipt.bonuses,
      'received': receipt.received,
      'clientId': receipt.clientId,
    };
  }

  Receipt _receiptFromJson(Map<String, dynamic> json) {
    try {
      // Парсим items
      final itemsList = json['items'] as List<dynamic>?;
      final items = <ReceiptItem>[];

      if (itemsList != null) {
        for (final itemData in itemsList) {
          try {
            final item = _receiptItemFromJson(itemData as Map<String, dynamic>);
            items.add(item);
          } catch (e, stackTrace) {
            print('❌ ClientWindowService: Ошибка парсинга item: $e');
            print('❌ Item data: $itemData');
            print('❌ StackTrace: $stackTrace');
            continue;
          }
        }
      }

      // Парсим остальные поля
      return Receipt(
        items: items,
        discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
        discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
        discountIsPercent: json['discountIsPercent'] as bool? ?? false,
        bonuses: (json['bonuses'] as num?)?.toDouble() ?? 0.0,
        received: (json['received'] as num?)?.toDouble() ?? 0.0,
        clientId: json['clientId'] as int?,
      );
    } catch (e, stackTrace) {
      print('❌ ClientWindowService: Ошибка парсинга Receipt: $e');
      print('❌ JSON: $json');
      print('❌ StackTrace: $stackTrace');
      // В случае ошибки возвращаем пустой чек
      return Receipt();
    }
  }

  ReceiptItem _receiptItemFromJson(Map<String, dynamic> json) {
    try {
      final productJson = json['product'] as Map<String, dynamic>;

      // Парсим product с обязательными полями
      final product = Product(
        id: productJson['id'] as int,
        name: productJson['name'] as String,
        barcode: productJson['barcode'] as String? ?? '',
        price: (productJson['price'] as num).toDouble(),
        stock: (productJson['stock'] as int?) ?? 0,
        unit: productJson['unit'] as String? ?? 'шт',
        unitName: productJson['unitName'] as String? ?? 'шт',
        unitsPerPackage: (productJson['unitsPerPackage'] as int?) ?? 1,
      );

      // Парсим ReceiptItem
      final quantity = (json['quantity'] as num?)?.toDouble() ?? 0.0;
      final price = (json['price'] as num?)?.toDouble() ?? product.price;
      final index = (json['index'] as int?) ?? 1;
      final unitsInPackage =
          (json['unitsInPackage'] as int?) ?? product.unitsPerPackage;
      final id = (json['id'] as int?) ?? DateTime.now().millisecondsSinceEpoch;

      return ReceiptItem(
        id: id,
        product: product,
        quantity: quantity,
        price: price,
        index: index,
        unitsInPackage: unitsInPackage,
      );
    } catch (e, stackTrace) {
      print('❌ ClientWindowService: Ошибка парсинга ReceiptItem: $e');
      print('❌ JSON: $json');
      print('❌ StackTrace: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> _clientToJson(Client client) {
    return {
      'id': client.id,
      'name': client.name,
      'phone': client.phone,
      'qrCode': client.qrCode,
      'bonuses': client.bonuses,
    };
  }

  Client _clientFromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String,
      qrCode: json['qrCode'] as String?,
      bonuses: (json['bonuses'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
