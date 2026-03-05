import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/client.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/receipt_notifier.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/errors/app_exception.dart';
import '../../../utils/formatters.dart';
import '../../cashier/models/product.dart';
import 'numeric_keypad.dart';
import 'add_client_dialog.dart';

class DiscountDialog extends ConsumerStatefulWidget {
  const DiscountDialog({super.key});

  @override
  ConsumerState<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends ConsumerState<DiscountDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneOrQrController = TextEditingController();
  final TextEditingController _bonusesController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final FocusNode _bonusesFocus = FocusNode();
  bool _isLoading = false;
  Client? _foundClient;
  double _bonusesToUse = 0.0;
  bool _isBonusesActive = false;
  
  // Для обработки сканирования товаров
  Timer? _barcodeTimer;

  @override
  void initState() {
    super.initState();
    // Запрашиваем фокус после построения виджета
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeTimer?.cancel();
    _nameController.dispose();
    _phoneOrQrController.dispose();
    _bonusesController.dispose();
    _inputFocus.dispose();
    _bonusesFocus.dispose();
    super.dispose();
  }

  void _setActiveField({required bool bonuses}) {
    _isBonusesActive = bonuses;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (bonuses) {
        _bonusesFocus.requestFocus();
      } else {
        _inputFocus.requestFocus();
      }
    });
  }

  void _handleKeypadKey(String key) {
    // Определяем активное поле
    final activeController = _isBonusesActive
        ? _bonusesController
        : _phoneOrQrController;
    final activeFocus = _isBonusesActive
        ? _bonusesFocus
        : _inputFocus;

    final currentValue = activeController.value;
    final currentText = currentValue.text;
    final selection = currentValue.selection;

    final cursorPosition = selection.isValid ? selection.start : currentText.length;
    final selectionStart = selection.isValid ? selection.start : cursorPosition;
    final selectionEnd = selection.isValid ? selection.end : cursorPosition;

    if (key == '.') {
      // Для поля бонусов добавляем запятую/точку
      if (_bonusesFocus.hasFocus) {
        if (!currentText.contains('.') && !currentText.contains(',')) {
          final newText = currentText.isEmpty ? '0,' : currentText + ',';
          activeController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
          _updateBonusesValue(newText);
        }
      } else {
        // Для QR-кода можно использовать точку, но обычно не нужна
        // Пропускаем точку для телефонов
        return;
      }
    } else {
      // Добавляем символ в позицию курсора
      final newText = currentText.isEmpty
          ? key
          : currentText.substring(0, selectionStart) +
                key +
                currentText.substring(selectionEnd);

      final newCursorPosition = selectionStart + 1;

      activeController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );

      // Обновляем значение бонусов, если это поле бонусов
      if (_bonusesFocus.hasFocus) {
        _updateBonusesValue(newText);
      } else {
        // Если это поле телефона/QR-кода, обрабатываем как возможный штрих-код товара
        _handleInputChanged(newText);
      }

      // Возвращаем фокус на поле
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FocusScope.of(context).requestFocus(activeFocus);
          final textLength = activeController.text.length;
          activeController.selection = TextSelection.collapsed(
            offset: textLength,
          );
        }
      });
    }
  }

  void _updateBonusesValue(String value) {
    final parsed = Formatters.parseNumber(value);
    if (parsed != null) {
      setState(() {
        _bonusesToUse = parsed > (_foundClient?.bonuses ?? 0)
            ? (_foundClient?.bonuses ?? 0)
            : parsed;
        if (_bonusesToUse != parsed && _foundClient != null) {
          _bonusesController.text = _bonusesToUse
              .toStringAsFixed(2)
              .replaceAll('.', ',');
        }
      });
    } else if (value.isEmpty) {
      setState(() {
        _bonusesToUse = 0.0;
      });
    }
  }

  void _handleKeypadBackspace() {
    // Определяем активное поле
    final activeController = _isBonusesActive
        ? _bonusesController
        : _phoneOrQrController;
    final activeFocus = _isBonusesActive
        ? _bonusesFocus
        : _inputFocus;

    final currentValue = activeController.value;
    final currentText = currentValue.text;
    final selection = currentValue.selection;

    final cursorPosition = selection.isValid ? selection.start : currentText.length;
    final selectionStart = selection.isValid ? selection.start : cursorPosition;
    final selectionEnd = selection.isValid ? selection.end : cursorPosition;

    if (currentText.isNotEmpty && selectionStart > 0) {
      final newText =
          currentText.substring(0, selectionStart - 1) +
          currentText.substring(selectionEnd);
      final newCursorPosition = selectionStart - 1;

      activeController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );

      // Обновляем значение бонусов, если это поле бонусов
      if (_bonusesFocus.hasFocus) {
        _updateBonusesValue(newText);
      }
    } else if (currentText.isNotEmpty &&
        selectionStart == 0 &&
        selectionEnd > 0) {
      final newText = currentText.substring(selectionEnd);
      activeController.value = TextEditingValue(
        text: newText,
        selection: const TextSelection.collapsed(offset: 0),
      );

      // Обновляем значение бонусов, если это поле бонусов
      if (_bonusesFocus.hasFocus) {
        _updateBonusesValue(newText);
      }
    }

    // Возвращаем фокус на поле
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(activeFocus);
        final textLength = activeController.text.length;
        activeController.selection = TextSelection.collapsed(
          offset: textLength,
        );
      }
    });
  }

  /// Обрабатывает изменение текста в поле ввода для сканирования товаров
  void _handleInputChanged(String value) {
    // Отменяем предыдущий таймер
    _barcodeTimer?.cancel();
    
    // Если поле бонусов активно, не обрабатываем сканирование товаров
    if (_isBonusesActive) {
      return;
    }
    
    // Если текст достаточно длинный (>= 8 символов), возможно это штрих-код товара
    if (value.length >= 8) {
      // Устанавливаем таймер на 150ms после последнего изменения
      // Сканеры обычно вводят очень быстро (все символы за 50-200ms)
      _barcodeTimer = Timer(const Duration(milliseconds: 150), () {
        _tryProcessProductBarcode(value);
      });
    }
  }
  
  /// Пытается обработать введенный текст как штрих-код товара
  Future<void> _tryProcessProductBarcode(String code) async {
    final trimmedCode = code.trim();
    
    // Если текст не изменился и достаточно длинный, пробуем найти товар
    if (trimmedCode.length < 8 || !mounted) {
      return;
    }
    
    try {
      final productRepo = ref.read(productRepositoryProvider);
      
      // Пробуем найти товар по штрих-коду
      Product? product = await productRepo.getProductByBarcode(trimmedCode);
      
      // Если не найден по штрих-коду, пробуем по QR-коду
      if (product == null) {
        product = await productRepo.getProductByQrCode(trimmedCode);
      }
      
      // Если товар найден, добавляем его в чек
      if (product != null && mounted) {
        // Добавляем товар в чек
        try {
          ref.read(receiptStateProvider.notifier).addProduct(product);
        } on ValidationException catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              duration: const Duration(milliseconds: 2000),
              backgroundColor: Colors.orange,
            ),
          );
          _phoneOrQrController.clear();
          return;
        }
        
        // Очищаем поле ввода
        _phoneOrQrController.clear();
        
        // Окно клиента обновится автоматически через ref.listen в CashierScreen
        // Но для надежности можно добавить небольшую задержку
        
        // Показываем уведомление
        final loc = ref.watch(appLocalizationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.productAdded}: "${product.name}"'),
            duration: const Duration(milliseconds: 1000),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }
      
      // Если товар не найден, пробуем найти клиента (как обычно)
      // Но только если поле все еще содержит тот же текст
      if (mounted && _phoneOrQrController.text.trim() == trimmedCode) {
        await _searchClientInternal(trimmedCode);
      }
    } catch (e) {
      // Игнорируем ошибки при поиске товара
      // Пробуем найти клиента
      if (mounted && _phoneOrQrController.text.trim() == trimmedCode) {
        await _searchClientInternal(trimmedCode);
      }
    }
  }
  
  Future<void> _searchClient() async {
    final query = _phoneOrQrController.text.trim();
    if (query.isEmpty) {
      final loc = ref.watch(appLocalizationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.enterPhoneNumber),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _searchClientInternal(query);
  }
  
  Future<void> _searchClientInternal(String query) async {
    setState(() {
      _isLoading = true;
      _foundClient = null;
    });

    try {
      // Используем ClientRepository вместо ApiService
      final clientRepository = ref.read(clientRepositoryProvider);
      final client = await clientRepository.findClientByPhoneOrQr(query);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _foundClient = client;
        });

        if (client != null) {
        _nameController.text = client.name;
          // Клиент найден - кнопка должна активироваться
          if (kDebugMode) {
            print('Клиент найден: ${client.name}');
          }
          // Инициализируем поле бонусов
          _bonusesToUse = 0.0;
          _bonusesController.clear();
        } else {
          final loc = ref.watch(appLocalizationsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc.clientNotFound}. ${loc.createNewClient}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } on DatabaseException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _foundClient = null;
        });
        final loc = ref.watch(appLocalizationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.clientSearchError}: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _foundClient = null;
        });
        final loc = ref.watch(appLocalizationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.clientSearchError}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createNewClient() async {
    final result = await showDialog<Client>(
      context: context,
      builder: (context) => AddClientDialog(
        initialName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
      ),
    );

    if (result != null && mounted) {
      // Клиент создан, устанавливаем его как найденного
      setState(() {
        _foundClient = result;
        _bonusesToUse = 0.0;
        _bonusesController.clear();
        // Заполняем поле телефона/QR код для отображения
        _phoneOrQrController.text = result.phone ?? result.qrCode ?? '';
        _nameController.text = result.name;
      });

      final loc = ref.watch(appLocalizationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.clientCreated}: ${result.name}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _applyDiscount() {
    if (_foundClient != null) {
      // Возвращаем клиента и сумму списываемых бонусов
      Navigator.pop(context, {
        'client': _foundClient,
        'bonusesToUse': _bonusesToUse,
      });
    }
  }

  void _cancel() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(24.0),
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.discount,
                    color: const Color(0xFF1976D2),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    ref.watch(appLocalizationsProvider).applyDiscount,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phoneOrQrController,
                      focusNode: _inputFocus,
                      decoration: InputDecoration(
                        labelText: ref.watch(appLocalizationsProvider).phoneOrBarcodeLabel,
                        hintText: ref.watch(appLocalizationsProvider).phoneOrBarcodeHint,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: _searchClient,
                                tooltip: ref.watch(appLocalizationsProvider).findClient,
                              ),
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _searchClient(),
                      onChanged: _handleInputChanged,
                      enableInteractiveSelection: false,
                      onTap: () {
                        _setActiveField(bonuses: false);
                        final text = _phoneOrQrController.text;
                        _phoneOrQrController.selection = TextSelection.collapsed(
                          offset: text.length,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _createNewClient,
                    icon: const Icon(Icons.person_add, size: 20),
                    label: Text(ref.watch(appLocalizationsProvider).createNewClient.replaceAll(' ', '\n')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                enabled: _foundClient == null,
                decoration: const InputDecoration(
                  labelText: 'Имя клиента',
                  hintText: 'Введите имя (необязательно)',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Цифровая клавиатура
              SizedBox(
                height: 280,
                child: NumericKeypad(
                  onKeyPressed: _handleKeypadKey,
                  onBackspace: _handleKeypadBackspace,
                ),
              ),
              const SizedBox(height: 16),
              if (_foundClient != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.green[700], size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _foundClient!.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_foundClient!.phone != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${ref.watch(appLocalizationsProvider).phone}: ${_foundClient!.phone}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ref.watch(appLocalizationsProvider).bonuses,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            Text(
                              '${_foundClient!.bonuses.toStringAsFixed(0)} с',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_foundClient!.bonuses > 0) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _bonusesController,
                          focusNode: _bonusesFocus,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d*')),
                          ],
                          style: const TextStyle(fontSize: 18),
                          enableInteractiveSelection: false,
                          decoration: InputDecoration(
                            labelText: ref.watch(appLocalizationsProvider).bonuses,
                            hintText: '0,00',
                            suffixText: 'с',
                            suffixStyle: const TextStyle(fontSize: 18),
                            border: const OutlineInputBorder(),
                            helperText: '${ref.watch(appLocalizationsProvider).bonuses}: ${_foundClient!.bonuses.toStringAsFixed(0)} с',
                            helperStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            errorText: _bonusesToUse > _foundClient!.bonuses
                                ? ref.watch(appLocalizationsProvider).insufficientFunds
                                : null,
                          ),
                          onTap: () {
                            _setActiveField(bonuses: true);
                            final text = _bonusesController.text;
                            _bonusesController.selection = TextSelection.collapsed(
                              offset: text.length,
                            );
                          },
                          onChanged: (value) {
                            final parsed = Formatters.parseNumber(value);
                            if (parsed != null) {
                              setState(() {
                                _bonusesToUse = parsed > _foundClient!.bonuses
                                    ? _foundClient!.bonuses
                                    : parsed;
                                if (_bonusesToUse != parsed) {
                                  _bonusesController.text = _bonusesToUse
                                      .toStringAsFixed(2)
                                      .replaceAll('.', ',');
                                }
                              });
                            } else if (value.isEmpty) {
                              setState(() {
                                _bonusesToUse = 0.0;
                              });
                            }

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_bonusesFocus.hasFocus && mounted) {
                                final textLength = _bonusesController.text.length;
                                _bonusesController.selection = TextSelection.collapsed(
                                  offset: textLength,
                                );
                              }
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cancel,
                    child: Text(ref.watch(appLocalizationsProvider).cancel),
                  ),
                  const SizedBox(width: 8),
                  Builder(
                    builder: (context) {
                      final loc = ref.watch(appLocalizationsProvider);
                      final isEnabled = _foundClient != null;
                      return ElevatedButton(
                        onPressed: isEnabled ? _applyDiscount : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(loc.applyDiscount),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

