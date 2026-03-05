import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/receipt.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/settings_notifier.dart';
import '../../../utils/formatters.dart';

class CalculationPanel extends ConsumerStatefulWidget {
  final Receipt receipt;
  final VoidCallback onCheckout;
  final VoidCallback onApplyDiscount;
  final VoidCallback onSelectClient;
  final String? clientName;
  final Function(double) onReceivedChanged;
  final Function(FocusNode?, TextEditingController?, bool)? onActiveFieldChanged;

  const CalculationPanel({
    super.key,
    required this.receipt,
    required this.onCheckout,
    required this.onApplyDiscount,
    required this.onSelectClient,
    this.clientName,
    required this.onReceivedChanged,
    this.onActiveFieldChanged,
  });

  @override
  ConsumerState<CalculationPanel> createState() => _CalculationPanelState();
}

class _CalculationPanelState extends ConsumerState<CalculationPanel> {
  final TextEditingController _receivedController = TextEditingController();
  final FocusNode _receivedFocus = FocusNode();
  bool _shouldClearOnNextInput = false; // Флаг для очистки при первом вводе
  String _valueWhenFocused = ''; // Значение поля при получении фокуса

  @override
  void initState() {
    super.initState();
    _updateControllers();
    _receivedFocus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (_receivedFocus.hasFocus) {
      widget.onActiveFieldChanged?.call(
        _receivedFocus,
        _receivedController,
        true,
      );
      // Устанавливаем флаг для очистки при первом вводе
      _shouldClearOnNextInput = true;
      _valueWhenFocused = _receivedController.text;
      // Устанавливаем курсор в конец без выделения при получении фокуса
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_receivedFocus.hasFocus && mounted) {
          final textLength = _receivedController.text.length;
          _receivedController.selection = TextSelection.collapsed(
            offset: textLength,
          );
        }
      });
    } else {
      widget.onActiveFieldChanged?.call(null, null, false);
      _shouldClearOnNextInput = false;
    }
  }

  void _updateControllers() {
    // Обновляем контроллер только если поле не в фокусе
    if (!_receivedFocus.hasFocus) {
      final receivedValue = widget.receipt.received;
      if (receivedValue > 0) {
        // Округляем до целого числа и показываем без копеек
        _receivedController.text = receivedValue.round().toString();
      } else {
        // Если значение равно 0, очищаем поле чтобы показать hintText
        _receivedController.clear();
      }
    }
  }

  @override
  void didUpdateWidget(CalculationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем контроллер если значение изменилось извне
    if (oldWidget.receipt.total != widget.receipt.total ||
        oldWidget.receipt.received != widget.receipt.received ||
        oldWidget.receipt.discount != widget.receipt.discount ||
        oldWidget.receipt.bonuses != widget.receipt.bonuses) {
      if (kDebugMode) {
        print('🔵 CalculationPanel: Обновление виджета. received: ${widget.receipt.received}, total: ${widget.receipt.total}, change: ${widget.receipt.change}, canCheckout: ${widget.receipt.canCheckout}');
      }
      _updateControllers();
    }
  }

  @override
  void dispose() {
    _receivedController.dispose();
    _receivedFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 800;

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Итого к оплате
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      ref.watch(appLocalizationsProvider).totalToPayLabel,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 4 : 6),
                    Text(
                      Formatters.formatMoney(widget.receipt.total),
                      style: TextStyle(
                        fontSize: isSmallScreen ? 24 : 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1976D2),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 3 : 4),

              // Скидка (процент и сумма рядом)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 10.0 : 12.0,
                  vertical: isSmallScreen ? 8.0 : 10.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ref.watch(appLocalizationsProvider).discountLabel,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.receipt.discountIsPercent &&
                            widget.receipt.discountPercent > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              '${widget.receipt.discountPercent.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        Text(
                          widget.receipt.totalDiscount > 0
                              ? Formatters.formatMoney(
                                  widget.receipt.totalDiscount,
                                )
                              : '0 с',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 3 : 4),

              // Бонусы (процент накопления и сумма рядом)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 10.0 : 12.0,
                  vertical: isSmallScreen ? 8.0 : 10.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ref.watch(appLocalizationsProvider).bonusesLabel,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final settings = ref.watch(appSettingsStateProvider);
                        final bonusPercent = settings.maybeWhen(
                          data: (s) => s.bonusAccrualPercent,
                          orElse: () => 5.0,
                        );
                        final bonusPercentText = bonusPercent.toStringAsFixed(bonusPercent % 1 == 0 ? 0 : 2);
                        final accumulatedBonuses = widget.receipt.clientId != null
                            ? widget.receipt.total * (bonusPercent / 100)
                            : 0.0;
                        
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.receipt.clientId != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  '$bonusPercentText%',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            Text(
                              widget.receipt.bonuses > 0
                                  ? Formatters.formatBonuses(widget.receipt.bonuses)
                                  : (widget.receipt.clientId != null
                                        ? Formatters.formatBonuses(accumulatedBonuses)
                                        : ref.watch(appLocalizationsProvider).notAccrued),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 20,
                                fontWeight: FontWeight.bold,
                                color: widget.receipt.bonuses > 0
                                    ? Colors.green
                                    : (widget.receipt.clientId != null
                                          ? Colors.blue
                                          : Colors.grey[600]),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 6 : 8),

              // Получено от клиента - красивое поле с улучшенным дизайном
              Container(
                decoration: BoxDecoration(
                  color: _receivedFocus.hasFocus
                      ? Colors.blue[50]?.withOpacity(0.3)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _receivedFocus.hasFocus
                        ? const Color(0xFF1976D2)
                        : Colors.grey[300]!,
                    width: _receivedFocus.hasFocus ? 2 : 1,
                  ),
                  boxShadow: _receivedFocus.hasFocus
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1976D2).withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: TextField(
                  controller: _receivedController,
                  focusNode: _receivedFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+')),
                  ],
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1976D2),
                  ),
                  textAlign: TextAlign.center,
                  enableInteractiveSelection: false,
                  decoration: InputDecoration(
                    labelText: ref.watch(appLocalizationsProvider).receivedFromClient,
                    labelStyle: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: _receivedFocus.hasFocus
                          ? const Color(0xFF1976D2)
                          : Colors.grey[600],
                    ),
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: isSmallScreen ? 20 : 26,
                      color: Colors.grey[400],
                    ),
                    suffixText: 'с',
                    suffixStyle: TextStyle(
                      fontSize: isSmallScreen ? 20 : 26,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1976D2),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isSmallScreen ? 16 : 20,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16, top: 12),
                      child: Icon(
                        Icons.payments,
                        color: _receivedFocus.hasFocus
                            ? const Color(0xFF1976D2)
                            : Colors.grey[600],
                        size: isSmallScreen ? 24 : 28,
                      ),
                    ),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1976D2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: const Color(0xFF1976D2),
                            size: isSmallScreen ? 20 : 24,
                          ),
                        ),
                        tooltip: ref.watch(appLocalizationsProvider).enterFullAmount,
                        onPressed: () {
                          // Округляем до целого числа
                          final totalRounded = widget.receipt.total.round();
                          _receivedController.text = totalRounded.toString();
                          widget.onReceivedChanged(totalRounded.toDouble());
                          // Устанавливаем фокус обратно на поле
                          _receivedFocus.requestFocus();
                        },
                      ),
                    ),
                  ),
                  onTap: () {
                    // Уведомляем о том, что поле стало активным
                    widget.onActiveFieldChanged?.call(
                      _receivedFocus,
                      _receivedController,
                      true,
                    );
                    // Устанавливаем флаг для очистки при первом вводе
                    _shouldClearOnNextInput = true;
                    _valueWhenFocused = _receivedController.text;
                    // Устанавливаем курсор в конец текста без выделения
                    final text = _receivedController.text;
                    _receivedController.selection = TextSelection.collapsed(
                      offset: text.length,
                    );
                  },
                  onChanged: (value) {
                    // Убираем все нецифровые символы (на случай, если пользователь ввел что-то лишнее)
                    final cleanedValue = value.replaceAll(RegExp(r'[^\d]'), '');
                    
                    // Если значение изменилось после очистки, обновляем контроллер
                    if (cleanedValue != value) {
                      _receivedController.value = TextEditingValue(
                        text: cleanedValue,
                        selection: TextSelection.collapsed(offset: cleanedValue.length),
                      );
                      value = cleanedValue;
                    }
                    
                    // Если это первый ввод после получения фокуса, очищаем поле
                    if (_shouldClearOnNextInput && value.isNotEmpty) {
                      // Проверяем, что новое значение начинается со старого и добавляется один символ
                      if (value.startsWith(_valueWhenFocused) &&
                          value.length == _valueWhenFocused.length + 1) {
                        // Берем последний символ (новый введенный)
                        String lastChar = value[value.length - 1];
                        // Если это цифра, заменяем все поле на эту цифру
                        if (RegExp(r'^\d$').hasMatch(lastChar)) {
                          _receivedController.value = TextEditingValue(
                            text: lastChar,
                            selection: TextSelection.collapsed(offset: 1),
                          );
                          _shouldClearOnNextInput = false;
                          // Обрабатываем первый символ - парсим как целое число
                          final parsed = int.tryParse(lastChar);
                          if (parsed != null) {
                            if (kDebugMode) {
                              print('🔵 CalculationPanel: onChanged первый ввод. received: $parsed, total: ${widget.receipt.total}');
                            }
                            widget.onReceivedChanged(parsed.toDouble());
                          }
                          return;
                        }
                      }
                    }

                    // Парсим как целое число
                    if (value.isEmpty) {
                      if (kDebugMode) {
                        print('🔵 CalculationPanel: onChanged пустое значение. received: 0, total: ${widget.receipt.total}');
                      }
                      widget.onReceivedChanged(0);
                      _shouldClearOnNextInput = false;
                    } else {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed >= 0) {
                        if (kDebugMode) {
                          print('🔵 CalculationPanel: onChanged. received: $parsed, total: ${widget.receipt.total}, change: ${parsed - widget.receipt.total}');
                        }
                        widget.onReceivedChanged(parsed.toDouble());
                        _shouldClearOnNextInput = false;
                      }
                    }
                    
                    // Устанавливаем курсор в конец после изменения
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_receivedFocus.hasFocus && mounted) {
                        final textLength = _receivedController.text.length;
                        _receivedController.selection = TextSelection.collapsed(
                          offset: textLength,
                        );
                      }
                    });
                  },
                ),
              ),
              SizedBox(height: isSmallScreen ? 6 : 8),

              // Сдача
              Builder(
                builder: (context) {
                  final change = widget.receipt.change;
                  final received = widget.receipt.received;
                  final total = widget.receipt.total;
                  final canCheckout = widget.receipt.canCheckout;
                  
                  // Отладочная информация (убрать после исправления проблемы)
                  if (received > 0 && change <= 0 && !canCheckout) {
                    if (kDebugMode) {
                      print('⚠️ CalculationPanel: ПРОБЛЕМА! received: $received, total: $total, change: $change, canCheckout: $canCheckout');
                    }
                  }
                  
                  return Container(
                    padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                    decoration: BoxDecoration(
                      color: change > 0
                          ? Colors.green.withOpacity(0.1)
                          : (change < 0
                              ? Colors.red.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          change < 0
                              ? 'Недоплата:'
                              : ref.watch(appLocalizationsProvider).changeLabel,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          Formatters.formatMoney(change.abs()),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 20 : 28,
                            fontWeight: FontWeight.bold,
                            color: change > 0
                                ? Colors.green
                                : (change < 0
                                    ? Colors.red
                                    : Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(height: isSmallScreen ? 6 : 8),

              // Кнопки действий
              Builder(
                builder: (context) {
                  final canCheckout = widget.receipt.canCheckout;
                  final received = widget.receipt.received;
                  final total = widget.receipt.total;
                  
                  // Отладочная информация (убрать после исправления проблемы)
                  if (received > 0 && received >= total && !canCheckout) {
                    if (kDebugMode) {
                      print('⚠️ CalculationPanel: КНОПКА НЕАКТИВНА! received: $received, total: $total, canCheckout: $canCheckout, isEmpty: ${widget.receipt.isEmpty}');
                    }
                  }
                  
                  return ElevatedButton.icon(
                    onPressed: canCheckout
                        ? widget.onCheckout
                        : null,
                    icon: Icon(Icons.payment, size: isSmallScreen ? 20 : 24),
                    label: Text(
                      ref.watch(appLocalizationsProvider).pay,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                      minimumSize: Size(double.infinity, isSmallScreen ? 48 : 56),
                    ),
                  );
                },
              ),
              SizedBox(height: isSmallScreen ? 3 : 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.onApplyDiscount,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 12 : 16,
                    ),
                    minimumSize: Size(double.infinity, isSmallScreen ? 48 : 56),
                  ),
                  child: Icon(
                    Icons.discount,
                    size: isSmallScreen ? 24 : 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
