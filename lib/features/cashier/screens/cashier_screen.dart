import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_notifier.dart';
import '../../../core/providers/client_notifier.dart';
import '../../../core/providers/multi_receipt_notifier.dart';
import '../../../core/providers/receipt_notifier.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/settings_notifier.dart';
import '../../../core/providers/shift_notifier.dart';
import '../../../services/client_window_service.dart';
import '../../../utils/formatters.dart';
import '../../admin/screens/receipts_history_screen.dart';
import '../../auth/models/user.dart';
import '../../auth/screens/login_screen.dart';
import '../../shared/models/client.dart';
import '../../shared/models/shift_record.dart';
import '../models/active_receipt.dart';
import '../models/product.dart';
import '../models/receipt.dart';
import '../widgets/calculation_panel.dart';
import '../widgets/discount_dialog.dart';
import '../widgets/numeric_keypad.dart';
import '../widgets/product_search_field.dart';
import '../widgets/receipt_table.dart';

class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});

  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> {
  final ClientWindowService _clientWindowService = ClientWindowService();
  final FocusNode _searchFocus = FocusNode();
  int? _selectedItemIndex;
  String? _clientName;
  // Кэш для имен клиентов, чтобы избежать излишних запросов
  final _clientNameCache = <int, String>{};
  static bool _clientWindowOpen = false;
  static bool _clientWindowCreating =
      false; // Дополнительный флаг для предотвращения дублирования

  // Для работы цифровой клавиатуры
  FocusNode? _activeFocusNode;
  TextEditingController? _activeController;
  FocusNode? _receivedFieldFocusNode; // Ссылка на FocusNode поля "Получено"
  bool _isReceivedFieldActive =
      false; // Флаг для определения типа активного поля

  // Временные переменные для сохранения активного поля из таблицы
  FocusNode? _receiptTableActiveFocusNode;
  TextEditingController? _receiptTableActiveController;

  // Для глобального сканирования штрих-кодов
  String _barcodeBuffer = '';
  Timer? _barcodeTimer;
  bool _keyboardHandlerAdded = false;

  // Дебаунсинг для обновления окна клиента - не вызываем сразу, а ждем 500ms
  Timer? _updateClientWindowDebounceTimer;
  bool _isUpdatingClientWindow = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_handleSearchFocusChanged);
    // Инициализируем сервис окна клиента
    _initializeClientWindowService();

    // Чек создается автоматически через receiptStateProvider
    // Запрашиваем фокус после того, как виджет построен
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Открываем окно клиента (оно само обновит данные после открытия)
        await _ensureClientWindow();
        _searchFocus.requestFocus();
        final currentUser = ref.read(authStateProvider);
        if (currentUser != null) {
          await _ensureShiftForUser(currentUser);
        }
      } catch (e) {
        // Ошибка инициализации не должна прерывать работу приложения
        if (kDebugMode) {
          print('⚠️ Ошибка инициализации экрана кассира: $e');
        }
      }
    });

    // Добавляем глобальный обработчик клавиатуры для сканирования штрих-кодов
    _addGlobalKeyboardHandler();
  }

  Widget _buildActiveShiftBadge(ShiftRecord shift) {
    final loc = ref.watch(appLocalizationsProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, color: Colors.green[700], size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.shiftActive,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                '${loc.shiftOpenedAt}: ${Formatters.formatDateTime(shift.startTime)}',
                style: TextStyle(fontSize: 11, color: Colors.green[700]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _initializeClientWindowService() async {
    // Инициализируем сервис (запускает polling для синхронизации между процессами)
    await _clientWindowService.init();
  }

  @override
  void dispose() {
    _removeGlobalKeyboardHandler();
    _barcodeTimer?.cancel();
    _updateClientWindowDebounceTimer?.cancel();
    _searchFocus.removeListener(_handleSearchFocusChanged);
    _searchFocus.dispose();
    super.dispose();
  }

  void _handleSearchFocusChanged() {
    if (_searchFocus.hasFocus) {
      // Сбрасываем активное поле из таблицы/получено,
      // чтобы ввод снова шел в поиск товаров.
      _activeFocusNode?.unfocus();
      _receiptTableActiveFocusNode?.unfocus();
      _receivedFieldFocusNode?.unfocus();
      _onActiveFieldChanged(null, null, false);
    }
  }

  void _forceSearchFocus() {
    // Полностью сбрасываем текущий фокус и возвращаем его в поле поиска.
    FocusManager.instance.primaryFocus?.unfocus();
    _activeFocusNode?.unfocus();
    _receiptTableActiveFocusNode?.unfocus();
    _receivedFieldFocusNode?.unfocus();
    _onActiveFieldChanged(null, null, false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_searchFocus);
      }
    });
  }

  /// Добавляет глобальный обработчик клавиатуры для сканирования штрих-кодов
  void _addGlobalKeyboardHandler() {
    if (_keyboardHandlerAdded) return;

    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    _keyboardHandlerAdded = true;
  }

  /// Удаляет глобальный обработчик клавиатуры
  void _removeGlobalKeyboardHandler() {
    if (!_keyboardHandlerAdded) return;

    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _keyboardHandlerAdded = false;
  }

  void _showStockError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  /// Глобальный обработчик событий клавиатуры
  bool _handleGlobalKeyEvent(KeyEvent event) {
    // Обрабатываем только события нажатия клавиш
    if (event is! KeyDownEvent) {
      return false;
    }

    final key = event.logicalKey;

    // Игнорируем модификаторы
    if (key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      return false;
    }

    // Обрабатываем функциональные клавиши через общий обработчик
    if (_isSpecialKey(key)) {
      return _handleKeyboardShortcut(event);
    }

    // Получаем символ из события
    final character = event.character;

    // Если есть символ и это не спецклавиша, обрабатываем как возможный штрих-код
    if (character != null && character.isNotEmpty && character.length == 1) {
      // Всегда обрабатываем ввод через глобальный обработчик
      // Это позволяет перехватывать ввод сканера независимо от фокуса
      _handleGlobalBarcodeInput(character);
    }

    // Не блокируем событие, чтобы другие виджеты тоже могли его обработать
    return false;
  }

  void _handleProductSelected(Product product) {
    if (kDebugMode) {
      print('🟢 CashierScreen: Товар выбран: ${product.name}');
    }
    try {
      ref.read(receiptStateProvider.notifier).addProduct(product);
    } on ValidationException catch (e) {
      _showStockError(e.message);
      if (e.code == 'stock_limit_exceeded') {
        _showOutOfStockDialog(product);
      }
      _barcodeBuffer = '';
      _barcodeTimer?.cancel();
      return;
    }
    setState(() {
      _selectedItemIndex = null;
    });
    // Очищаем буфер после добавления товара
    _barcodeBuffer = '';
    _barcodeTimer?.cancel();
    // ref.listen автоматически вызовет _updateClientWindow
    if (kDebugMode) {
      print(
        '🟢 CashierScreen: Товар добавлен в чек, ожидаем обновления окна клиента через ref.listen',
      );
    }
  }

  Future<void> _showOutOfStockDialog(Product product) async {
    if (!mounted) return;
    final loc = ref.read(appLocalizationsProvider);
    final notified = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.outOfStock),
        content: Text(product.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.notify),
          ),
        ],
      ),
    );

    if (notified == true && mounted) {
      final currentUser = ref.read(authStateProvider);
      await ref
          .read(purchaseRequestRepositoryProvider)
          .createRequest(
            productId: product.id,
            productName: product.name,
            requestedByUserId: currentUser?.id,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.notify}: ${product.name}'),
          duration: const Duration(milliseconds: 1500),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Обрабатывает глобальный ввод для сканирования штрих-кодов
  void _handleGlobalBarcodeInput(String character) {
    // Всегда обрабатываем ввод, независимо от фокуса
    // Это позволяет сканировать штрих-коды в любой момент

    // Добавляем символ в буфер
    _barcodeBuffer += character;

    // Отменяем предыдущий таймер
    _barcodeTimer?.cancel();

    // Если буфер длинный (>= 8 символов), возможно это штрих-код
    if (_barcodeBuffer.length >= 8) {
      // Устанавливаем таймер на 100ms после последнего ввода
      // Сканеры обычно вводят очень быстро (все символы за 50-200ms)
      _barcodeTimer = Timer(const Duration(milliseconds: 100), () {
        _processBarcodeInput();
      });
    } else {
      // Для коротких строк устанавливаем таймер на большее время
      _barcodeTimer = Timer(const Duration(milliseconds: 300), () {
        // Если буфер всё ещё короткий, очищаем его (это не штрих-код)
        if (_barcodeBuffer.length < 8 && mounted) {
          _barcodeBuffer = '';
        }
      });
    }
  }

  /// Обрабатывает завершенный ввод штрих-кода
  Future<void> _processBarcodeInput() async {
    if (_barcodeBuffer.isEmpty || _barcodeBuffer.length < 8 || !mounted) {
      _barcodeBuffer = '';
      return;
    }

    final barcode = _barcodeBuffer.trim();
    // Сохраняем копию перед очисткой буфера
    final barcodeToProcess = barcode;
    _barcodeBuffer = '';

    // Игнорируем, если это слишком короткий код
    if (barcodeToProcess.length < 8 || !mounted) {
      return;
    }

    try {
      final productRepo = ref.read(productRepositoryProvider);
      final loc = ref.read(appLocalizationsProvider);

      // Сначала пробуем найти по штрих-коду
      Product? product = await productRepo.getProductByBarcode(
        barcodeToProcess,
      );

      // Если не найден по штрих-коду, пробуем по QR-коду
      if (product == null) {
        product = await productRepo.getProductByQrCode(barcodeToProcess);
      }

      // Если товар найден, автоматически добавляем его в чек
      if (product != null && mounted) {
        if (kDebugMode) {
          print(
            '🟢 CashierScreen: Товар найден по штрих-коду: ${product.name}',
          );
        }
        // Добавляем товар в чек напрямую
        try {
          ref.read(receiptStateProvider.notifier).addProduct(product);
        } on ValidationException catch (e) {
          _showStockError(e.message);
          if (e.code == 'stock_limit_exceeded') {
            _showOutOfStockDialog(product);
          }
          return;
        }
        setState(() {
          _selectedItemIndex = null;
        });
        // ref.listen автоматически вызовет _updateClientWindow

        // Показываем уведомление о добавлении товара
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc.productAdded}: "${product.name}"'),
              duration: const Duration(milliseconds: 1000),
              backgroundColor: Colors.green,
            ),
          );
        }
        print(
          '🟢 CashierScreen: Товар добавлен в чек, ожидаем обновления окна клиента через ref.listen',
        );
      } else if (mounted) {
        // Если товар не найден, показываем сообщение только если поле поиска не активно
        // (чтобы избежать дублирования сообщений)
        if (!_searchFocus.hasFocus) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc.productNotFound}: "$barcodeToProcess"'),
              duration: const Duration(milliseconds: 2000),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // В случае ошибки просто игнорируем (не показываем ошибку пользователю)
      // чтобы не мешать работе
      if (mounted) {
        _barcodeBuffer = '';
      }
    }
  }

  void _handleItemSelected(int index) {
    setState(() {
      _selectedItemIndex = index;
    });
  }

  void _handleItemDelete(int index) {
    ref.read(receiptStateProvider.notifier).removeItem(index);
    setState(() {
      _selectedItemIndex = null;
    });
  }

  void _handleIncreaseQuantity(int index) {
    try {
      ref.read(receiptStateProvider.notifier).increaseQuantityByUnit(index);
    } on ValidationException catch (e) {
      _showStockError(e.message);
    }
  }

  void _handleDecreaseQuantity(int index) {
    final receipt = ref.read(receiptStateProvider);
    if (index < 0 || index >= receipt.items.length) return;

    final item = receipt.items[index];
    // Если количество больше одной упаковки, уменьшаем на одну упаковку
    if (item.quantity > item.unitsInPackage) {
      ref.read(receiptStateProvider.notifier).decreaseQuantityByUnit(index);
    } else {
      // Если осталось меньше одной упаковки, удаляем товар
      ref.read(receiptStateProvider.notifier).removeItem(index);
      setState(() {
        _selectedItemIndex = null;
      });
    }
  }

  void _handleClearReceipt() {
    final loc = ref.read(appLocalizationsProvider);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${loc.clearReceipt}?'),
          content: Text('${loc.confirm} ${loc.clearReceipt.toLowerCase()}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.cancel),
            ),
            TextButton(
              onPressed: () {
                // Очищаем текущий чек (создаем новый пустой чек)
                ref.read(receiptStateProvider.notifier).clearReceipt();
                ref.read(clientStateProvider.notifier).clearClient();
                // Обновляем имя клиента в multiReceiptStateProvider
                final currentReceiptId = ref
                    .read(multiReceiptStateProvider.notifier)
                    .currentReceiptId;
                if (currentReceiptId != null) {
                  ref
                      .read(multiReceiptStateProvider.notifier)
                      .updateClientName(currentReceiptId, null);
                }
                setState(() {
                  _selectedItemIndex = null;
                  _clientName = null;
                  _searchFocus.requestFocus();
                  _clientWindowService.clear(); // async, но не ждем
                });
                Navigator.pop(context);
              },
              child: Text(
                loc.clearReceipt,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleCheckout() async {
    final receipt = ref.read(receiptStateProvider);
    final loc = ref.read(appLocalizationsProvider);

    // Детальная проверка причин, почему оплата невозможна
    if (receipt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.cannotCheckoutEmpty),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // total теперь всегда >= 0 (ограничено в геттере), поэтому проверка total < 0 не нужна
    // Если total == 0, то можно оплатить с received >= 0

    // Проверяем полученную сумму только если total > 0
    // Если total == 0 (например, из-за скидки и бонусов), то received может быть любым >= 0
    if (receipt.total > 0) {
      if (receipt.received < receipt.total) {
        final missing = receipt.total - receipt.received;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${loc.cannotCheckoutInsufficient}\n'
              '${loc.receivedAmount}: ${Formatters.formatMoney(receipt.received)}\n'
              '${loc.requiredAmount}: ${Formatters.formatMoney(receipt.total)}\n'
              '${loc.missingAmount}: ${Formatters.formatMoney(missing)}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    } else {
      // Если total == 0, проверяем, что received >= 0
      if (receipt.received < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.cannotCheckoutNegative),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    // Финальная проверка через canCheckout (на случай других проблем)
    if (!receipt.canCheckout) {
      final loc = ref.read(appLocalizationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.paymentCheckError),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    try {
      // Получаем текущего пользователя из authStateProvider
      final currentUser = ref.read(authStateProvider);
      final userId = currentUser?.id;

      if (kDebugMode) {
        print(
          '🔵 [CashierScreen] _handleCheckout: currentUser = ${currentUser?.name ?? "null"}, userId = $userId',
        );
      }

      if (userId == null) {
        if (kDebugMode) {
          print(
            '⚠️ [CashierScreen] _handleCheckout: ВНИМАНИЕ! userId равен null - чек будет сохранен без информации о кассире!',
          );
        }
      }

      final receiptNumber = await ref
          .read(receiptStateProvider.notifier)
          .checkout(userId: userId);

      await _clientWindowService.clear();
      ref.read(clientStateProvider.notifier).clearClient();

      if (mounted) {
        setState(() {
          _clientName = null;
        });
        String message = '${loc.receiptNumberLabel} $receiptNumber';

        // Добавляем информацию о скидке
        if (receipt.totalDiscount > 0) {
          if (receipt.discountIsPercent) {
            message +=
                '\n${loc.discountPercentLabel}: ${receipt.discountPercent.toStringAsFixed(0)}% (${Formatters.formatMoney(receipt.totalDiscount)})';
          } else {
            message +=
                '\n${loc.discountPercentLabel}: ${Formatters.formatMoney(receipt.totalDiscount)}';
          }
        }

        // Добавляем информацию о списанных бонусах
        if (receipt.bonuses > 0) {
          message +=
              '\n${loc.bonusesWrittenOffLabel} ${Formatters.formatMoney(receipt.bonuses)}';
        }

        // Добавляем информацию о начисленных баллах (только если есть клиент и бонусы не списывались)
        if (receipt.clientId != null && receipt.bonuses == 0) {
          final settings = ref.read(appSettingsStateProvider);
          final bonusPercent = settings.maybeWhen(
            data: (s) => s.bonusAccrualPercent,
            orElse: () => 5.0,
          );
          final accumulatedBonuses = receipt.total * (bonusPercent / 100);
          final bonusPercentText = bonusPercent.toStringAsFixed(
            bonusPercent % 1 == 0 ? 0 : 2,
          );
          message +=
              '\nНачислено баллов ($bonusPercentText% от итога): ${Formatters.formatBonuses(accumulatedBonuses)}';
        }

        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('${loc.checkout} ${loc.success.toLowerCase()}'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedItemIndex = null;
                      _clientName = null;
                      _searchFocus.requestFocus();
                    });
                  },
                  child: Text(loc.ok),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.paymentError}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleApplyDiscount() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const DiscountDialog(),
    );

    if (result != null && mounted) {
      final client = result['client'] as Client;
      final bonusesToUse = (result['bonusesToUse'] as num?)?.toDouble() ?? 0.0;

      // Устанавливаем клиента в receipt и client state
      ref.read(receiptStateProvider.notifier).setClient(client);
      // Обновляем client state через метод (если есть) или напрямую если нужно
      // Пока используем только receipt state для хранения clientId

      setState(() {
        _clientName = client.name;
      });

      // Применяем бонусы клиента (списываемые баллы)
      if (bonusesToUse > 0) {
        final receipt = ref.read(receiptStateProvider);
        // Используем указанную сумму бонусов, но не больше суммы чека после скидки
        final maxBonuses = receipt.subtotal - receipt.totalDiscount;
        final finalBonusesToUse = bonusesToUse > maxBonuses
            ? maxBonuses
            : bonusesToUse;
        if (finalBonusesToUse > 0) {
          ref.read(receiptStateProvider.notifier).setBonuses(finalBonusesToUse);
        }
      }

      // Обновляем окно клиента
      final receipt = ref.read(receiptStateProvider);
      _clientWindowService.setReceiptAndClient(receipt, client);

      final loc = ref.read(appLocalizationsProvider);
      String message = '${loc.clientLabel} ${client.name}';
      if (bonusesToUse > 0) {
        final receipt = ref.read(receiptStateProvider);
        final maxBonuses = receipt.subtotal - receipt.totalDiscount;
        final finalBonusesToUse = bonusesToUse > maxBonuses
            ? maxBonuses
            : bonusesToUse;
        if (finalBonusesToUse > 0) {
          message +=
              '\n${loc.bonusesWrittenOffLabel} ${Formatters.formatMoney(finalBonusesToUse)}';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _handleSelectClient() async {
    Client? client;
    final loc = ref.read(appLocalizationsProvider);

    final receipt = ref.read(receiptStateProvider);
    final clientId = receipt.clientId;
    if (clientId != null) {
      try {
        final clientRepo = ref.read(clientRepositoryProvider);
        client = await clientRepo.getClientById(clientId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc.clientLoadedError}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    if (client == null) {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => const DiscountDialog(),
      );

      if (result != null) {
        client = result['client'] as Client;
      } else {
        return;
      }
    }

    await _openClientWindow(client);
  }

  bool _isOpeningClientWindow =
      false; // Флаг для предотвращения параллельных вызовов

  /// Получает координаты второго монитора (если доступен)
  /// Возвращает null, если второй монитор не найден
  Future<Rect?> _getSecondMonitorBounds() async {
    try {
      // Используем platform channel для получения информации о мониторах
      final MethodChannel channel = const MethodChannel('window_manager');

      // Пробуем разные методы для получения информации о мониторах
      List<dynamic>? displaysData;
      try {
        displaysData = await channel.invokeMethod('getDisplays');
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Метод getDisplays не доступен, пробуем другой способ: $e');
        }
        // Пробуем альтернативный метод
        try {
          displaysData = await channel.invokeMethod('getAllDisplays');
        } catch (e2) {
          if (kDebugMode) {
            print('⚠️ Метод getAllDisplays тоже не доступен: $e2');
          }
        }
      }

      if (displaysData == null || displaysData.isEmpty) {
        // Если не удалось получить через platform channel, используем простую эвристику
        // Размещаем окно справа от основного окна
        try {
          final primaryBounds = await windowManager.getBounds();
          // Предполагаем, что второй монитор находится справа
          // Используем координаты за пределами основного экрана
          final estimatedSecondMonitorX = primaryBounds.right + 100;
          final estimatedSecondMonitorY = primaryBounds.top;

          if (kDebugMode) {
            print(
              '📍 Используем эвристику для второго монитора: ($estimatedSecondMonitorX, $estimatedSecondMonitorY)',
            );
          }

          // Возвращаем предполагаемые координаты второго монитора
          return Rect.fromLTWH(
            estimatedSecondMonitorX,
            estimatedSecondMonitorY,
            1920, // Предполагаемая ширина второго монитора
            1080, // Предполагаемая высота второго монитора
          );
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Не удалось получить информацию о мониторах: $e');
          }
          return null;
        }
      }

      if (kDebugMode) {
        print('🖥️ Найдено мониторов: ${displaysData.length}');
      }

      // Ищем второй монитор (не основной)
      for (var displayData in displaysData) {
        final Map<String, dynamic> display = Map<String, dynamic>.from(
          displayData,
        );
        final bool isPrimary = display['isPrimary'] as bool? ?? false;

        if (!isPrimary) {
          final bounds = display['bounds'] as Map<String, dynamic>?;
          if (bounds != null) {
            final rect = Rect.fromLTWH(
              (bounds['x'] as num).toDouble(),
              (bounds['y'] as num).toDouble(),
              (bounds['width'] as num).toDouble(),
              (bounds['height'] as num).toDouble(),
            );
            if (kDebugMode) {
              print('✅ Найден второй монитор: $rect');
            }
            return rect;
          }
        }
      }

      // Если не нашли неосновной монитор, но есть несколько мониторов,
      // используем второй по порядку
      if (displaysData.length > 1) {
        final secondDisplayData = displaysData[1] as Map<String, dynamic>;
        final bounds = secondDisplayData['bounds'] as Map<String, dynamic>?;
        if (bounds != null) {
          final rect = Rect.fromLTWH(
            (bounds['x'] as num).toDouble(),
            (bounds['y'] as num).toDouble(),
            (bounds['width'] as num).toDouble(),
            (bounds['height'] as num).toDouble(),
          );
          if (kDebugMode) {
            print('✅ Используем второй монитор по порядку: $rect');
          }
          return rect;
        }
      }

      if (kDebugMode) {
        print('⚠️ Второй монитор не найден');
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Ошибка получения информации о мониторах: $e');
        print('❌ StackTrace: $stackTrace');
      }
      return null;
    }
  }

  Future<void> _ensureClientWindow() async {
    // Если окно уже открыто или открывается, не делаем ничего
    if (_clientWindowOpen || _isOpeningClientWindow || _clientWindowCreating) {
      if (kDebugMode) {
        print(
          '🟢 CashierScreen: Окно клиента уже открыто или открывается, пропускаем (open: $_clientWindowOpen, opening: $_isOpeningClientWindow, creating: $_clientWindowCreating)',
        );
      }
      // Все равно обновляем данные, если окно уже открыто
      if (_clientWindowOpen) {
        _scheduleClientWindowUpdate();
      }
      return;
    }

    try {
      _isOpeningClientWindow = true;
      _clientWindowCreating = true; // Устанавливаем флаг создания
      if (kDebugMode) {
        print('🟢 CashierScreen: Открытие окна клиента');
      }

      final currentUser = ref.read(authStateProvider);
      final args = <String, dynamic>{'route': 'client'};
      if (currentUser != null) {
        args['userId'] = currentUser.id;
      }

      // Получаем координаты второго монитора
      final secondMonitorBounds = await _getSecondMonitorBounds();

      // Размер окна клиента - на весь второй монитор или стандартный размер
      double windowWidth = 1200.0;
      double windowHeight = 800.0;

      // Позиция окна - на втором мониторе в полноэкранном режиме
      double windowX = 100.0;
      double windowY = 100.0;
      bool isFullScreen = false;

      if (secondMonitorBounds != null) {
        // Размещаем окно на весь второй монитор (полноэкранный режим)
        windowX = secondMonitorBounds.left;
        windowY = secondMonitorBounds.top;
        windowWidth = secondMonitorBounds.width;
        windowHeight = secondMonitorBounds.height;
        isFullScreen = true;

        if (kDebugMode) {
          print(
            '📍 Размещаем окно клиента в полноэкранном режиме на втором мониторе: ${windowWidth}x${windowHeight} at ($windowX, $windowY)',
          );
        }
      } else {
        // Если второго монитора нет, используем дефолтные координаты
        // Окно откроется в стандартной позиции
        if (kDebugMode) {
          print(
            '📍 Второй монитор не найден, используем дефолтную позицию: ($windowX, $windowY)',
          );
        }
      }

      // Передаем координаты и размер через аргументы, так как WindowConfiguration
      // может не поддерживать эти параметры напрямую
      args['windowX'] = windowX.toInt();
      args['windowY'] = windowY.toInt();
      args['windowWidth'] = windowWidth.toInt();
      args['windowHeight'] = windowHeight.toInt();
      args['isFullScreen'] = isFullScreen;

      final controller = await WindowController.create(
        WindowConfiguration(hiddenAtLaunch: true, arguments: jsonEncode(args)),
      );

      if (kDebugMode) {
        print(
          '✅ Окно клиента создано с параметрами: ${windowWidth}x${windowHeight} at ($windowX, $windowY)',
        );
      }

      // Показываем окно
      await controller.show();
      _clientWindowOpen = true;
      _clientWindowCreating =
          false; // Сбрасываем флаг создания после успешного открытия

      // Небольшая задержка для инициализации окна, затем обновляем данные
      await Future.delayed(const Duration(milliseconds: 500));
      if (kDebugMode) {
        print('🟢 CashierScreen: Окно клиента открыто, обновляем данные');
      }

      // Обновляем данные после открытия окна (используем прямое обновление для первого раза)
      await _updateClientWindow();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ CashierScreen: Ошибка открытия окна клиента: $e');
        print('❌ StackTrace: $stackTrace');
      }
      _clientWindowOpen = false; // Сбрасываем флаг при ошибке
      _clientWindowCreating = false; // Сбрасываем флаг создания при ошибке
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${ref.read(appLocalizationsProvider).clientWindowError}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isOpeningClientWindow = false;
      _clientWindowCreating = false; // Убеждаемся, что флаг сброшен в finally
    }
  }

  Future<void> _openClientWindow(Client client) async {
    try {
      // Обновляем данные в сервисе
      final receipt = ref.read(receiptStateProvider);
      await _clientWindowService.setReceiptAndClient(receipt, client);
      await _ensureClientWindow();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${ref.read(appLocalizationsProvider).clientWindowError}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
        if (kDebugMode) {
          print('Ошибка открытия окна клиента: $e');
        }
      }
    }
  }

  /// Обновление окна клиента с дебаунсингом
  /// Не вызывается сразу, а ждет 500ms для предотвращения множественных вызовов
  void _scheduleClientWindowUpdate() {
    // Отменяем предыдущий таймер, если он есть
    _updateClientWindowDebounceTimer?.cancel();

    // Создаем новый таймер с задержкой 500ms
    _updateClientWindowDebounceTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        if (mounted && !_isUpdatingClientWindow) {
          _updateClientWindow();
        }
      },
    );
  }

  Future<void> _updateClientWindow() async {
    // Предотвращаем параллельные вызовы
    if (_isUpdatingClientWindow) {
      return;
    }

    try {
      _isUpdatingClientWindow = true;

      // Всегда обновляем окно клиента
      // Это обеспечивает отображение товаров даже без выбранного клиента
      final receipt = ref.read(receiptStateProvider);
      final clientState = ref.read(clientStateProvider);

      // Всегда обновляем чек через SharedPreferences
      // Это позволяет синхронизировать данные между процессами multi-window
      if (receipt.clientId != null && clientState != null) {
        // Если есть клиент, обновляем с клиентом
        await _clientWindowService.setReceiptAndClient(receipt, clientState);
      } else if (clientState != null) {
        // Если есть клиент в state, но не в чеке, используем клиента из state
        await _clientWindowService.setReceiptAndClient(receipt, clientState);
      } else {
        // Если клиента нет, обновляем только чек (товары все равно должны отображаться)
        // Это позволяет видеть товары на втором экране даже без выбранного клиента
        await _clientWindowService.updateReceipt(receipt);
      }

      // Если окно не открыто и не открывается, пытаемся его открыть
      // Проверяем все флаги, чтобы избежать дублирования окон
      if (!_clientWindowOpen &&
          !_isOpeningClientWindow &&
          !_clientWindowCreating) {
        await _ensureClientWindow();
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ CashierScreen: Ошибка в _updateClientWindow: $e');
        print('❌ StackTrace: $stackTrace');
      }
    } finally {
      _isUpdatingClientWindow = false;
    }
  }

  void _handleUnitsInPackageChanged(int index, int totalUnits) {
    final receipt = ref.read(receiptStateProvider);
    if (index < 0 || index >= receipt.items.length) {
      return;
    }

    final item = receipt.items[index];
    final standardUnitsPerPackage = item.product.unitsPerPackage;

    // Используем введенное значение напрямую без округления
    // Пользователь может ввести любое количество таблеток (например, 35)
    final newQuantity = totalUnits.toDouble();

    // Всегда используем стандартный размер упаковки для правильного отображения
    // Например: 35 таблеток при стандартной упаковке 20 = 1 упаковка (20) + 15 таблеток из второй
    // Это позволяет правильно показывать, что товар берется из нескольких упаковок
    // Если количество больше стандартной упаковки, unitsInPackage должен быть стандартным,
    // чтобы система правильно рассчитала количество полных упаковок и остаток

    // Обновляем количество
    try {
      ref
          .read(receiptStateProvider.notifier)
          .updateQuantity(index, newQuantity);
    } on ValidationException catch (e) {
      _showStockError(e.message);
      return;
    }

    // Если unitsInPackage отличается от стандартного, возвращаем его к стандартному значению
    // Это гарантирует, что отображение будет правильным:
    // - полные упаковки будут считаться по стандартному размеру
    // - остаток будет показываться как отдельные таблетки из второй/третьей упаковки
    if (item.unitsInPackage != standardUnitsPerPackage) {
      ref
          .read(receiptStateProvider.notifier)
          .updateUnitsInPackage(index, standardUnitsPerPackage);
    }

    // Восстанавливаем фокус если поле было активно
    if (_receiptTableActiveFocusNode != null &&
        _receiptTableActiveController != null &&
        _activeFocusNode == _receiptTableActiveFocusNode) {
      // Используем двойной addPostFrameCallback для более надежного восстановления фокуса
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _receiptTableActiveFocusNode != null) {
            _receiptTableActiveFocusNode!.requestFocus();
            _onActiveFieldChanged(
              _receiptTableActiveFocusNode,
              _receiptTableActiveController,
              false,
            );
          }
        });
      });
    }
  }

  void _handleKeypadKey(String key) {
    if (_activeController != null && _activeFocusNode != null) {
      // Получаем текущее значение и позицию курсора
      final currentValue = _activeController!.value;
      final currentText = currentValue.text;
      final selection = currentValue.selection;

      // Определяем позицию курсора
      final cursorPosition = selection.isValid
          ? selection.start
          : currentText.length;

      // Определяем начало и конец выделения
      final selectionStart = selection.isValid
          ? selection.start
          : cursorPosition;
      final selectionEnd = selection.isValid ? selection.end : cursorPosition;

      if (key == '.') {
        // Для поля "Получено" больше не обрабатываем запятую/точку (только целые числа)
        // Для поля таблеток запятая/точка не обрабатывается
        // Игнорируем точку/запятую для всех полей
      } else {
        // Добавляем цифру в позицию курсора
        final newText = currentText.isEmpty
            ? key
            : currentText.substring(0, selectionStart) +
                  key +
                  currentText.substring(selectionEnd);

        // Новая позиция курсора - после вставленного символа
        final newCursorPosition = selectionStart + 1;

        _activeController!.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newCursorPosition),
        );
        _triggerOnChanged(newText);
      }

      // Возвращаем фокус на активное поле, курсор всегда в конце без выделения
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_activeFocusNode != null && mounted && _activeController != null) {
          _activeFocusNode!.requestFocus();
          // Всегда устанавливаем курсор в конец без выделения
          final textLength = _activeController!.text.length;
          _activeController!.selection = TextSelection.collapsed(
            offset: textLength,
          );
        }
      });
    }
  }

  void _handleKeypadBackspace() {
    if (_activeController != null) {
      final currentValue = _activeController!.value;
      final currentText = currentValue.text;
      final selection = currentValue.selection;

      // Определяем позицию курсора
      final cursorPosition = selection.isValid
          ? selection.start
          : currentText.length;

      // Определяем начало и конец выделения
      final selectionStart = selection.isValid
          ? selection.start
          : cursorPosition;
      final selectionEnd = selection.isValid ? selection.end : cursorPosition;

      if (currentText.isNotEmpty && selectionStart > 0) {
        // Удаляем символ перед курсором или выделенный текст
        final newText =
            currentText.substring(0, selectionStart - 1) +
            currentText.substring(selectionEnd);
        final newCursorPosition = selectionStart - 1;

        _activeController!.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newCursorPosition),
        );
        _triggerOnChanged(newText);
      } else if (currentText.isNotEmpty &&
          selectionStart == 0 &&
          selectionEnd > 0) {
        // Если выделен текст в начале, удаляем его
        final newText = currentText.substring(selectionEnd);
        _activeController!.value = TextEditingValue(
          text: newText,
          selection: const TextSelection.collapsed(offset: 0),
        );
        _triggerOnChanged(newText);
      }

      // Возвращаем фокус на активное поле, курсор всегда в конце без выделения
      if (_activeFocusNode != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_activeFocusNode != null &&
              mounted &&
              _activeController != null) {
            _activeFocusNode!.requestFocus();
            // Всегда устанавливаем курсор в конец без выделения
            final textLength = _activeController!.text.length;
            _activeController!.selection = TextSelection.collapsed(
              offset: textLength,
            );
          }
        });
      }
    }
  }

  void _triggerOnChanged(String newText) {
    // Определяем тип активного поля и вызываем соответствующий обработчик
    if (_isReceivedFieldActive) {
      // Это поле "Получено" - обрабатываем как целое число (без копеек)
      // Убираем все нецифровые символы
      final cleanedText = newText.replaceAll(RegExp(r'[^\d]'), '');

      if (cleanedText.isEmpty) {
        if (kDebugMode) {
          print(
            '🔵 CashierScreen: _triggerOnChanged пустое значение. received: 0',
          );
        }
        ref.read(receiptStateProvider.notifier).setReceived(0);
        return;
      }

      // Парсим как целое число
      final parsed = int.tryParse(cleanedText);
      if (parsed != null && parsed >= 0) {
        final receipt = ref.read(receiptStateProvider);
        if (kDebugMode) {
          print(
            '🔵 CashierScreen: _triggerOnChanged. received: $parsed, total: ${receipt.total}, change: ${parsed - receipt.total}, canCheckout: ${parsed >= receipt.total}',
          );
        }
        ref.read(receiptStateProvider.notifier).setReceived(parsed.toDouble());
      }
    }
    // Если активно поле таблеток, обработка происходит через _handleUnitsInPackageChanged
    // и мы не должны здесь ничего делать, чтобы не конфликтовать
  }

  void _onActiveFieldChanged(
    FocusNode? focusNode,
    TextEditingController? controller,
    bool isReceivedField,
  ) {
    // Явно задаем тип поля, чтобы не путать "Получено" и таблицу
    if (focusNode != null && controller != null) {
      if (isReceivedField) {
        _receivedFieldFocusNode = focusNode;
        _isReceivedFieldActive = true;
      } else {
        _isReceivedFieldActive = false;
        _receiptTableActiveFocusNode = focusNode;
        _receiptTableActiveController = controller;
      }
    }

    // Устанавливаем активное поле только когда оно действительно получает фокус
    // Не сбрасываем при временной потере фокуса (например, при клике на клавиатуру)
    if (focusNode != null && controller != null) {
      // Не вызываем setState здесь, чтобы не терять фокус
      _activeFocusNode = focusNode;
      _activeController = controller;
    }
    // Не сбрасываем активное поле при потере фокуса - оно останется активным для цифровой клавиатуры
    // Но если явно передали null (например, при сохранении), то сбрасываем
    if (focusNode == null && controller == null && _activeFocusNode != null) {
      // Если фокус уже на поиске, сбрасываем сразу
      if (_searchFocus.hasFocus) {
        setState(() {
          _activeFocusNode = null;
          _activeController = null;
          _isReceivedFieldActive = false;
          _receiptTableActiveFocusNode = null;
          _receiptTableActiveController = null;
        });
        return;
      }

      // Иначе проверяем с небольшой задержкой (для цифровой клавиатуры)
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted &&
            (_activeFocusNode == null || !_activeFocusNode!.hasFocus)) {
          setState(() {
            _activeFocusNode = null;
            _activeController = null;
            _isReceivedFieldActive = false;
            _receiptTableActiveFocusNode = null;
            _receiptTableActiveController = null;
          });
        }
      });
    }
  }

  bool _handleKeyboardShortcut(KeyEvent event) {
    // Игнорируем события модификаторов (Alt, Ctrl, Shift, Meta)
    // если они нажаты отдельно без других клавиш
    final key = event.logicalKey;

    // Проверяем, является ли клавиша модификатором
    if (key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      // Игнорируем модификаторы, если они нажаты отдельно
      return false;
    }

    // Глобальная обработка клавиатуры теперь в _handleGlobalKeyEvent
    // через HardwareKeyboard.instance.addHandler
    // Здесь оставляем только обработку функциональных клавиш

    // Обрабатываем функциональные клавиши
    if (key == LogicalKeyboardKey.f1 || key == LogicalKeyboardKey.enter) {
      // Очищаем буфер при нажатии Enter или F1
      _barcodeBuffer = '';
      _barcodeTimer?.cancel();
      _handleCheckout();
      return true;
    }
    if (key == LogicalKeyboardKey.f2) {
      _barcodeBuffer = '';
      _barcodeTimer?.cancel();
      _searchFocus.requestFocus();
      return true;
    }
    if (key == LogicalKeyboardKey.f3) {
      return true;
    }
    if (key == LogicalKeyboardKey.f4) {
      return true;
    }
    if (key == LogicalKeyboardKey.f5) {
      _barcodeBuffer = '';
      _barcodeTimer?.cancel();
      _handleClearReceipt();
      return true;
    }
    if (key == LogicalKeyboardKey.f6) {
      return true;
    }
    if (key == LogicalKeyboardKey.f7) {
      _barcodeBuffer = '';
      _barcodeTimer?.cancel();
      _handleSelectClient();
      return true;
    }
    if (key == LogicalKeyboardKey.delete && _selectedItemIndex != null) {
      _barcodeBuffer = '';
      _barcodeTimer?.cancel();
      _handleItemDelete(_selectedItemIndex!);
      setState(() {
        _selectedItemIndex = null;
      });
      return true;
    }

    // Если нажата Escape или другая спецклавиша, очищаем буфер
    if (_isSpecialKey(key)) {
      _barcodeBuffer = '';
      _barcodeTimer?.cancel();
    }

    return false;
  }

  /// Проверяет, является ли клавиша специальной (не текстовой)
  bool _isSpecialKey(LogicalKeyboardKey key) {
    // Функциональные клавиши
    if (key == LogicalKeyboardKey.f1 ||
        key == LogicalKeyboardKey.f2 ||
        key == LogicalKeyboardKey.f3 ||
        key == LogicalKeyboardKey.f4 ||
        key == LogicalKeyboardKey.f5 ||
        key == LogicalKeyboardKey.f6 ||
        key == LogicalKeyboardKey.f7 ||
        key == LogicalKeyboardKey.f8 ||
        key == LogicalKeyboardKey.f9 ||
        key == LogicalKeyboardKey.f10 ||
        key == LogicalKeyboardKey.f11 ||
        key == LogicalKeyboardKey.f12) {
      return true;
    }

    // Клавиши управления
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.home ||
        key == LogicalKeyboardKey.end ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.pageDown) {
      return true;
    }

    return false;
  }

  Future<void> _handleStartShift(User user) async {
    final loc = ref.read(appLocalizationsProvider);
    try {
      await ref
          .read(shiftStateProvider.notifier)
          .startShift(user.id, user.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.shiftOpenSuccess),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildShiftBanner(ShiftState shiftState, User? currentUser) {
    final loc = ref.watch(appLocalizationsProvider);
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    if (shiftState.isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              '${loc.loading}...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
      );
    }

    final error = shiftState.error;
    final isProcessing = shiftState.isProcessing;

    if (shiftState.activeShift == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_open, color: Colors.orange[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    loc.shiftNoActive,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _handleStartShift(currentUser),
                  icon: const Icon(Icons.play_circle_outline),
                  label: Text(loc.openShift),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(color: Colors.red[700], fontSize: 12),
              ),
            ],
          ],
        ),
      );
    }

    if (shiftState.activeShift == null) {
      return const SizedBox.shrink();
    }
    return const SizedBox.shrink();
  }

  void _openReceiptsHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ReceiptsHistoryScreen()),
    );
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    setState(() {
      _isLoggingOut = true;
    });
    try {
      await _handleShiftClosingBeforeLogout();
      _clientWindowService.clear();
      ref.read(authStateProvider.notifier).logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  Future<void> _ensureShiftForUser(User user) async {
    if (user.role.toLowerCase() != 'cashier') {
      return;
    }
    final shiftNotifier = ref.read(shiftStateProvider.notifier);
    try {
      await shiftNotifier.load(user.id);
      final shiftState = ref.read(shiftStateProvider);
      final activeShift = shiftState.activeShift;
      final loc = ref.read(appLocalizationsProvider);
      if (activeShift != null) {
        _showShiftSnack(
          loc.shiftAlreadyOpen(
            activeShift.userName,
            Formatters.formatDateTime(activeShift.startTime),
          ),
        );
        return;
      }
      final newShift = await shiftNotifier.startShift(user.id, user.name);
      _showShiftSnack(
        loc.shiftOpened(
          newShift.userName,
          Formatters.formatDateTime(newShift.startTime),
        ),
      );
    } catch (e) {
      final loc = ref.read(appLocalizationsProvider);
      _showShiftSnack(loc.shiftOpenError(e.toString()), isError: true);
    }
  }

  Future<void> _handleShiftClosingBeforeLogout() async {
    final user = ref.read(authStateProvider);
    if (user == null || user.role.toLowerCase() != 'cashier') {
      return;
    }
    final shiftNotifier = ref.read(shiftStateProvider.notifier);
    try {
      final loc = ref.read(appLocalizationsProvider);
      final closedShift = await shiftNotifier.closeShift(user.id);
      if (closedShift != null) {
        final endTime = closedShift.endTime ?? DateTime.now();
        _showShiftSnack(
          loc.shiftClosed(
            closedShift.userName,
            Formatters.formatDateTime(closedShift.startTime),
            Formatters.formatDateTime(endTime),
          ),
        );
      } else {
        _showShiftSnack(loc.shiftNotFound);
      }
    } catch (e) {
      final loc = ref.read(appLocalizationsProvider);
      _showShiftSnack(loc.shiftCloseError(e.toString()), isError: true);
    } finally {
      shiftNotifier.reset();
    }
  }

  void _showShiftSnack(String message, {bool isError = false}) {
    if (!mounted || message.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Слушаем изменения чека для обновления окна клиента
    // Используем дебаунсинг - не вызываем сразу, а планируем обновление
    ref.listen<Receipt>(receiptStateProvider, (previous, next) {
      if (mounted) {
        // Планируем обновление окна клиента с дебаунсингом
        _scheduleClientWindowUpdate();

        // Обновляем имя клиента, если он изменился
        final currentClient = ref.read(clientStateProvider);
        if (currentClient != null && currentClient.id == next.clientId) {
          setState(() {
            _clientName = currentClient.name;
          });
        } else if (next.clientId == null) {
          setState(() {
            _clientName = null;
          });
        }
      }
    });

    // Слушаем изменения клиента для обновления окна клиента
    // Используем дебаунсинг - не вызываем сразу, а планируем обновление
    ref.listen<Client?>(clientStateProvider, (previous, next) {
      if (mounted) {
        // Планируем обновление окна клиента с дебаунсингом
        _scheduleClientWindowUpdate();

        setState(() {
          _clientName = next?.name;
        });
      }
    });

    // Слушаем изменения активных чеков для обновления UI при переключении
    ref.listen<Map<String, ActiveReceipt>>(multiReceiptStateProvider, (
      previous,
      next,
    ) {
      if (mounted) {
        // Обновляем имя клиента для текущего чека
        final currentReceipt = ref
            .read(multiReceiptStateProvider.notifier)
            .currentReceipt;
        if (currentReceipt != null) {
          final receipt = currentReceipt.receipt;
          // Используем кэшированное имя, если оно есть
          if (receipt.clientId != null) {
            final cachedName = _clientNameCache[receipt.clientId];
            if (cachedName != null) {
              // Используем кэшированное имя только если оно отличается от текущего
              if (_clientName != cachedName) {
                setState(() {
                  _clientName = cachedName;
                });
              }
              // Обновляем имя в multiReceiptStateProvider только если оно отличается
              if (currentReceipt.clientName != cachedName) {
                ref
                    .read(multiReceiptStateProvider.notifier)
                    .updateClientName(currentReceipt.id, cachedName);
              }
            } else if (currentReceipt.clientName != null &&
                currentReceipt.clientName!.isNotEmpty) {
              // Используем имя из currentReceipt, если оно есть
              if (_clientName != currentReceipt.clientName) {
                setState(() {
                  _clientName = currentReceipt.clientName;
                });
              }
              _clientNameCache[receipt.clientId!] = currentReceipt.clientName!;
            } else {
              // Загружаем клиента только если нет кэша и нет имени в currentReceipt
              final clientRepo = ref.read(clientRepositoryProvider);
              clientRepo
                  .getClientById(receipt.clientId!)
                  .then((client) {
                    if (mounted && client != null) {
                      // Кэшируем имя клиента
                      _clientNameCache[receipt.clientId!] = client.name;
                      if (_clientName != client.name) {
                        setState(() {
                          _clientName = client.name;
                        });
                      }
                      // Обновляем имя клиента в multiReceiptStateProvider только если оно отличается
                      if (currentReceipt.clientName != client.name) {
                        ref
                            .read(multiReceiptStateProvider.notifier)
                            .updateClientName(currentReceipt.id, client.name);
                      }
                    }
                  })
                  .catchError((_) {
                    if (mounted) {
                      setState(() {
                        _clientName = currentReceipt.clientName;
                      });
                    }
                  });
            }
          } else {
            if (_clientName != currentReceipt.clientName) {
              setState(() {
                _clientName = currentReceipt.clientName;
              });
            }
          }
        } else {
          setState(() {
            _clientName = null;
          });
        }
        _scheduleClientWindowUpdate();
      }
    });

    ref.listen<User?>(authStateProvider, (previous, next) {
      final shiftNotifier = ref.read(shiftStateProvider.notifier);
      if (next != null) {
        shiftNotifier.load(next.id);
      } else {
        shiftNotifier.reset();
      }
    });

    final shiftState = ref.watch(shiftStateProvider);
    final currentUser = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Верхняя панель
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/img/logo.PNG',
                      height: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.local_pharmacy,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Builder(
                      builder: (context) {
                        final settingsAsync = ref.watch(
                          appSettingsStateProvider,
                        );
                        final loc = ref.watch(appLocalizationsProvider);
                        final pharmacyName = settingsAsync.maybeWhen(
                          data: (settings) => settings.pharmacyName,
                          orElse: () => loc.defaultPharmacyName,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'libiss pos',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              pharmacyName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const Spacer(),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.4,
                      child: ProductSearchField(
                        focusNode: _searchFocus,
                        onTap: () {
                          _forceSearchFocus();
                        },
                        onProductSelected: _handleProductSelected,
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (shiftState.activeShift != null) ...[
                      _buildActiveShiftBadge(shiftState.activeShift!),
                      const SizedBox(width: 12),
                    ],
                    ElevatedButton.icon(
                      onPressed: _openReceiptsHistory,
                      icon: const Icon(Icons.receipt_long),
                      label: Text(
                        ref.watch(appLocalizationsProvider).receiptsHistory,
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        backgroundColor: Colors.blue[50],
                        foregroundColor: Colors.blue[700],
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoggingOut ? null : _handleLogout,
                      icon: const Icon(Icons.logout),
                      label: _isLoggingOut
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(ref.watch(appLocalizationsProvider).logout),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red[700],
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildShiftBanner(shiftState, currentUser),
              ),
              // Вкладки активных чеков
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Кнопка создания нового чека
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            // Создаем новый чек (новый клиент)
                            ref
                                .read(multiReceiptStateProvider.notifier)
                                .createNewReceipt();
                            ref
                                .read(clientStateProvider.notifier)
                                .clearClient();
                            setState(() {
                              _selectedItemIndex = null;
                              _clientName = null;
                              _searchFocus.requestFocus();
                            });
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  ref
                                      .watch(appLocalizationsProvider)
                                      .newReceipt,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Вкладки активных чеков
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: ref.watch(multiReceiptStateProvider).length,
                        itemBuilder: (context, index) {
                          final activeReceipts = ref
                              .watch(multiReceiptStateProvider)
                              .values
                              .toList();
                          final activeReceipt = activeReceipts[index];
                          final isActive =
                              ref
                                  .read(multiReceiptStateProvider.notifier)
                                  .currentReceiptId ==
                              activeReceipt.id;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  // Переключаемся на выбранный чек
                                  ref
                                      .read(multiReceiptStateProvider.notifier)
                                      .switchToReceipt(activeReceipt.id);
                                  // Обновляем имя клиента для текущего чека
                                  final receipt = ref.read(
                                    receiptStateProvider,
                                  );
                                  if (receipt.clientId != null) {
                                    final clientRepo = ref.read(
                                      clientRepositoryProvider,
                                    );
                                    clientRepo
                                        .getClientById(receipt.clientId!)
                                        .then((client) {
                                          if (mounted && client != null) {
                                            setState(() {
                                              _clientName = client.name;
                                            });
                                          }
                                        })
                                        .catchError((_) {
                                          if (mounted) {
                                            setState(() {
                                              _clientName = null;
                                            });
                                          }
                                        });
                                  } else {
                                    setState(() {
                                      _clientName = activeReceipt.clientName;
                                    });
                                  }
                                  setState(() {
                                    _selectedItemIndex = null;
                                    _searchFocus.requestFocus();
                                  });
                                },
                                onLongPress: () {
                                  // Показываем диалог удаления чека
                                  if (ref
                                          .watch(multiReceiptStateProvider)
                                          .length >
                                      1) {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        final loc = ref.watch(
                                          appLocalizationsProvider,
                                        );
                                        return AlertDialog(
                                          title: Text(
                                            '${loc.delete} ${loc.receipt.toLowerCase()}?',
                                          ),
                                          content: Text(
                                            '${loc.confirm} ${loc.delete.toLowerCase()} ${loc.receipt.toLowerCase()} "${activeReceipt.displayName(loc.newReceipt, loc.receipt)}"?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: Text(loc.cancel),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                ref
                                                    .read(
                                                      multiReceiptStateProvider
                                                          .notifier,
                                                    )
                                                    .removeReceipt(
                                                      activeReceipt.id,
                                                    );
                                                Navigator.pop(context);
                                                // Если удалили текущий чек, переключаемся на первый доступный
                                                final currentReceipt = ref
                                                    .read(
                                                      multiReceiptStateProvider
                                                          .notifier,
                                                    )
                                                    .currentReceipt;
                                                if (currentReceipt != null) {
                                                  final receipt = ref.read(
                                                    receiptStateProvider,
                                                  );
                                                  if (receipt.clientId !=
                                                      null) {
                                                    final clientRepo = ref.read(
                                                      clientRepositoryProvider,
                                                    );
                                                    clientRepo
                                                        .getClientById(
                                                          receipt.clientId!,
                                                        )
                                                        .then((client) {
                                                          if (mounted &&
                                                              client != null) {
                                                            setState(() {
                                                              _clientName =
                                                                  client.name;
                                                            });
                                                          }
                                                        })
                                                        .catchError((_) {
                                                          if (mounted) {
                                                            setState(() {
                                                              _clientName =
                                                                  null;
                                                            });
                                                          }
                                                        });
                                                  } else {
                                                    setState(() {
                                                      _clientName =
                                                          currentReceipt
                                                              .clientName;
                                                    });
                                                  }
                                                } else {
                                                  setState(() {
                                                    _clientName = null;
                                                  });
                                                }
                                              },
                                              child: Text(
                                                loc.delete,
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.primary.withOpacity(0.2)
                                        : Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isActive
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(context).dividerColor,
                                      width: isActive ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        activeReceipt.displayName(
                                          ref
                                              .watch(appLocalizationsProvider)
                                              .newReceipt,
                                          ref
                                              .watch(appLocalizationsProvider)
                                              .receipt,
                                        ),
                                        style: TextStyle(
                                          color: isActive
                                              ? Colors.blue[900]
                                              : Colors.grey[700],
                                          fontWeight: isActive
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (activeReceipt.total > 0) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          Formatters.formatMoney(
                                            activeReceipt.total,
                                          ),
                                          style: TextStyle(
                                            color: isActive
                                                ? Colors.blue[900]
                                                : Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 4),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () {
                                            // Удаляем чек
                                            if (ref
                                                    .watch(
                                                      multiReceiptStateProvider,
                                                    )
                                                    .length >
                                                1) {
                                              // Если чеков больше одного, удаляем без диалога
                                              ref
                                                  .read(
                                                    multiReceiptStateProvider
                                                        .notifier,
                                                  )
                                                  .removeReceipt(
                                                    activeReceipt.id,
                                                  );
                                              // Если удалили текущий чек, переключаемся на первый доступный
                                              final currentReceipt = ref
                                                  .read(
                                                    multiReceiptStateProvider
                                                        .notifier,
                                                  )
                                                  .currentReceipt;
                                              if (currentReceipt != null) {
                                                final receipt = ref.read(
                                                  receiptStateProvider,
                                                );
                                                if (receipt.clientId != null) {
                                                  final clientRepo = ref.read(
                                                    clientRepositoryProvider,
                                                  );
                                                  clientRepo
                                                      .getClientById(
                                                        receipt.clientId!,
                                                      )
                                                      .then((client) {
                                                        if (mounted &&
                                                            client != null) {
                                                          setState(() {
                                                            _clientName =
                                                                client.name;
                                                          });
                                                        }
                                                      })
                                                      .catchError((_) {
                                                        if (mounted) {
                                                          setState(() {
                                                            _clientName = null;
                                                          });
                                                        }
                                                      });
                                                } else {
                                                  setState(() {
                                                    _clientName = currentReceipt
                                                        .clientName;
                                                  });
                                                }
                                              } else {
                                                setState(() {
                                                  _clientName = null;
                                                });
                                              }
                                            } else {
                                              // Если это последний чек, показываем диалог
                                              showDialog(
                                                context: context,
                                                builder: (context) {
                                                  final loc = ref.watch(
                                                    appLocalizationsProvider,
                                                  );
                                                  return AlertDialog(
                                                    title: Text(
                                                      '${loc.delete} ${loc.receipt.toLowerCase()}?',
                                                    ),
                                                    content: Text(
                                                      '${loc.confirm} ${loc.delete.toLowerCase()} ${loc.receipt.toLowerCase()} "${activeReceipt.displayName(loc.newReceipt, loc.receipt)}"?',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              context,
                                                            ),
                                                        child: Text(loc.cancel),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          ref
                                                              .read(
                                                                multiReceiptStateProvider
                                                                    .notifier,
                                                              )
                                                              .removeReceipt(
                                                                activeReceipt
                                                                    .id,
                                                              );
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                          setState(() {
                                                            _clientName = null;
                                                          });
                                                        },
                                                        child: Text(
                                                          loc.delete,
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Icon(
                                              Icons.close,
                                              size: 16,
                                              color: isActive
                                                  ? Colors.blue[900]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Основной контент
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Левая колонка (65%)
                Expanded(
                  flex: 65,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ReceiptTable(
                            receipt: ref.watch(receiptStateProvider),
                            selectedIndex: _selectedItemIndex,
                            onItemSelected: _handleItemSelected,
                            onItemDelete: _handleItemDelete,
                            onIncreaseQuantity: _handleIncreaseQuantity,
                            onDecreaseQuantity: _handleDecreaseQuantity,
                            onUnitsInPackageChanged:
                                _handleUnitsInPackageChanged,
                            onActiveFieldChanged: _onActiveFieldChanged,
                            onNotifyOutOfStock: () async {
                              if (_selectedItemIndex == null) return;
                              final receipt = ref.read(receiptStateProvider);
                              if (_selectedItemIndex! >= receipt.items.length)
                                return;
                              final product =
                                  receipt.items[_selectedItemIndex!].product;
                              await _showOutOfStockDialog(product);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.center,
                          child: ElevatedButton.icon(
                            onPressed: _handleClearReceipt,
                            icon: const Icon(Icons.delete_outline),
                            label: Text(
                              ref.watch(appLocalizationsProvider).clearReceipt,
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Правая колонка (35%)
                Expanded(
                  flex: 35,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Панель расчётов - верхняя часть
                        Expanded(
                          flex: 3,
                          child: CalculationPanel(
                            receipt: ref.watch(receiptStateProvider),
                            clientName: _clientName,
                            onCheckout: _handleCheckout,
                            onApplyDiscount: _handleApplyDiscount,
                            onSelectClient: _handleSelectClient,
                            onReceivedChanged: (value) {
                              ref
                                  .read(receiptStateProvider.notifier)
                                  .setReceived(value);
                            },
                            onActiveFieldChanged: _onActiveFieldChanged,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Цифровая клавиатура - нижняя часть правой колонки
                        Expanded(
                          flex: 2,
                          child: NumericKeypad(
                            onKeyPressed: _handleKeypadKey,
                            onBackspace: _handleKeypadBackspace,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
