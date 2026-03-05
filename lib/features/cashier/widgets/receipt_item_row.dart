import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/formatters.dart';
import '../models/receipt_item.dart';

class ReceiptItemRow extends StatefulWidget {
  final ReceiptItem item;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onIncreaseQuantity;
  final VoidCallback onDecreaseQuantity;
  final Function(int) onUnitsInPackageChanged;
  final Function(FocusNode?, TextEditingController?, bool)?
  onActiveFieldChanged;
  final VoidCallback? onNotifyOutOfStock;
  final bool isSelected;

  const ReceiptItemRow({
    super.key,
    required this.item,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.onIncreaseQuantity,
    required this.onDecreaseQuantity,
    required this.onUnitsInPackageChanged,
    this.onActiveFieldChanged,
    this.onNotifyOutOfStock,
    this.isSelected = false,
  });

  @override
  State<ReceiptItemRow> createState() => _ReceiptItemRowState();
}

class _ReceiptItemRowState extends State<ReceiptItemRow> {
  final TextEditingController _unitsInPackageController =
      TextEditingController();
  final FocusNode _unitsInPackageFocus = FocusNode();
  bool _shouldClearOnNextInput = false; // Флаг для очистки при первом вводе
  String _valueWhenFocused = ''; // Значение поля при получении фокуса

  @override
  void initState() {
    super.initState();
    // Изначально поле пустое, если значение равно стандартному, чтобы показать hintText
    // hintText теперь показывает текущее общее количество таблеток (quantity)
    final standardUnits = widget.item.product.unitsPerPackage;
    final currentQuantity = widget.item.quantity.toInt();
    if (currentQuantity != standardUnits) {
      _unitsInPackageController.text = currentQuantity.toString();
    }
    _valueWhenFocused = _unitsInPackageController.text;
    _unitsInPackageFocus.addListener(() {
      if (_unitsInPackageFocus.hasFocus) {
        // Уведомляем, что поле таблеток стало активным
        widget.onActiveFieldChanged?.call(
          _unitsInPackageFocus,
          _unitsInPackageController,
          false,
        );
        // Устанавливаем флаг для очистки при первом вводе
        _shouldClearOnNextInput = true;
        _valueWhenFocused = _unitsInPackageController.text;
        // Устанавливаем курсор в конец без выделения при получении фокуса
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_unitsInPackageFocus.hasFocus && mounted) {
            final textLength = _unitsInPackageController.text.length;
            _unitsInPackageController.selection = TextSelection.collapsed(
              offset: textLength,
            );
          }
        });
      } else {
        // Сохраняем значение при потере фокуса
        final text = _unitsInPackageController.text.trim();
        if (text.isEmpty) {
          // Если поле пустое, используем стандартное количество таблеток в одной упаковке
          final standardUnits = widget.item.product.unitsPerPackage;
          // Обновляем quantity на основе стандартного размера упаковки
          widget.onUnitsInPackageChanged(standardUnits);
        } else {
          final totalUnits = int.tryParse(text);
          if (totalUnits != null && totalUnits > 0) {
            // Обновляем общее количество таблеток
            widget.onUnitsInPackageChanged(totalUnits);
            // Если значение равно стандартному, очищаем поле для показа hintText
            final standardUnits = widget.item.product.unitsPerPackage;
            if (totalUnits == standardUnits) {
              _unitsInPackageController.clear();
            }
          } else {
            // Если значение невалидное, используем стандартное значение
            final standardUnits = widget.item.product.unitsPerPackage;
            _unitsInPackageController.clear();
            widget.onUnitsInPackageChanged(standardUnits);
          }
        }
        _shouldClearOnNextInput = false;
        // Уведомляем, что поле потеряло фокус, чтобы активным стало новое поле
        widget.onActiveFieldChanged?.call(null, null, false);
      }
    });
  }

  void _updateController() {
    // Обновляем контроллер только если поле не в фокусе
    if (!_unitsInPackageFocus.hasFocus) {
      // Показываем общее количество таблеток (quantity), а не unitsInPackage
      // Если значение равно стандартному количеству таблеток в одной упаковке, очищаем поле для показа hintText
      final standardUnits = widget.item.product.unitsPerPackage;
      final currentQuantity = widget.item.quantity.toInt();
      if (currentQuantity == standardUnits) {
        _unitsInPackageController.clear();
      } else {
        _unitsInPackageController.text = currentQuantity.toString();
      }
    }
  }

  @override
  void didUpdateWidget(ReceiptItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем текст контроллера если quantity изменилось извне, но только если поле не в фокусе
    if (oldWidget.item.quantity != widget.item.quantity &&
        !_unitsInPackageFocus.hasFocus) {
      _updateController();
    }
    // Если поле в фокусе, НЕ обновляем контроллер - это сохранит фокус и текущий ввод
    // Восстанавливаем фокус после обновления виджета
    if (_unitsInPackageFocus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Устанавливаем курсор в конец
          if (_unitsInPackageFocus.hasFocus) {
            final textLength = _unitsInPackageController.text.length;
            _unitsInPackageController.selection = TextSelection.collapsed(
              offset: textLength,
            );
          }
        }
      });
    }
  }

  Future<void> _showOutOfStockDialog(BuildContext context) async {
    final notified = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Нет в наличии'),
        content: Text(widget.item.product.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Уведомить'),
          ),
        ],
      ),
    );

    if (notified == true && mounted) {
      widget.onNotifyOutOfStock?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Отмечено: ${widget.item.product.name} закончился'),
          duration: const Duration(milliseconds: 1500),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  String _formatQuantity(ReceiptItem item) {
    final unitName = item.product.unitName;
    final standardUnitsPerPackage = item.product.unitsPerPackage;

    // Всегда вычисляем количество полных упаковок по стандартному размеру
    // Это гарантирует, что при вводе количества больше стандартной упаковки
    // правильно показывается, из скольких упаковок берется товар
    final fullPackages = (item.quantity / standardUnitsPerPackage).floor();
    final remainingUnits = (item.quantity % standardUnitsPerPackage).toInt();

    // Если unitsInPackage отличается от стандартного, показываем это явно
    final isCustomPackage = item.unitsInPackage != item.product.unitsPerPackage;

    // Если есть полные упаковки и остаток, показываем оба
    // Например: 35 таблеток при стандартной упаковке 20 = "1 упаковка + 15 таблеток"
    if (fullPackages > 0 && remainingUnits > 0) {
      // Есть и полные упаковки по стандарту, и остаток (таблетки из второй/третьей упаковки)
      if (isCustomPackage) {
        // Показываем, что используется нестандартный размер упаковки
        return '$fullPackages ${item.product.unit} (${standardUnitsPerPackage} $unitName) + $remainingUnits $unitName';
      }
      return '$fullPackages ${item.product.unit} + $remainingUnits $unitName';
    } else if (fullPackages > 0) {
      // Только полные упаковки по стандарту
      if (isCustomPackage) {
        // Показываем, что используется нестандартный размер упаковки
        return '$fullPackages ${item.product.unit} (${standardUnitsPerPackage} $unitName)';
      }
      return '$fullPackages ${item.product.unit}';
    } else {
      // Только отдельные единицы (меньше одной упаковки)
      return '$remainingUnits $unitName';
    }
  }

  // Вычисляет hintText для поля unitsInPackage
  // Показывает общее количество таблеток в текущих упаковках
  String _getHintText() {
    final item = widget.item;
    // Показываем текущее общее количество таблеток (quantity)
    return item.quantity.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = widget.item.product.stock <= 0;
    return Container(
      color: widget.isSelected
          ? const Color(0xFF1976D2).withOpacity(0.1)
          : Colors.transparent,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 12.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Номер
                Container(
                  width: 50,
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? const Color(0xFF1976D2)
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.item.index}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.isSelected
                            ? Colors.white
                            : Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Название
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.item.product.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: widget.isSelected
                              ? const Color(0xFF1976D2)
                              : Colors.grey[900],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isOutOfStock) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: const Text(
                            'Закончилось',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                      if (widget.item.product.barcode.isNotEmpty)
                        const SizedBox(height: 2),
                      if (widget.item.product.barcode.isNotEmpty)
                        Text(
                          'Штрихкод: ${widget.item.product.barcode}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                ),
                // Количество с кнопками + и -
                SizedBox(
                  width: 170,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onDecreaseQuantity,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red[200]!,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.remove,
                              size: 18,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue[200]!,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _formatQuantity(widget.item),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[900],
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isOutOfStock
                              ? () => _showOutOfStockDialog(context)
                              : widget.onIncreaseQuantity,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green[200]!,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.add,
                              size: 18,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Цена за упаковку
                SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Formatters.formatMoney(widget.item.price),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      Text(
                        'за ${widget.item.product.unit}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Таблетки в упаковке
                SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _unitsInPackageController,
                          focusNode: _unitsInPackageFocus,
                          enabled: !isOutOfStock,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          enableInteractiveSelection: false,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: _getHintText(),
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            suffixText: widget.item.product.unitName,
                            suffixStyle: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[600],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Colors.blue[200]!,
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Colors.blue[200]!,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Colors.blue[700]!,
                                width: 2,
                              ),
                            ),
                          ),
                          onTap: () {
                            if (isOutOfStock) {
                              _showOutOfStockDialog(context);
                              return;
                            }
                            widget.onActiveFieldChanged?.call(
                              _unitsInPackageFocus,
                              _unitsInPackageController,
                              false,
                            );
                            _shouldClearOnNextInput = true;
                            _valueWhenFocused = _unitsInPackageController.text;
                            final text = _unitsInPackageController.text;
                            _unitsInPackageController.selection =
                                TextSelection.collapsed(offset: text.length);
                          },
                          onChanged: (value) {
                            // Если это первый ввод после получения фокуса, очищаем поле
                            if (_shouldClearOnNextInput && value.isNotEmpty) {
                              if (value.startsWith(_valueWhenFocused) &&
                                  value.length ==
                                      _valueWhenFocused.length + 1) {
                                String lastChar = value[value.length - 1];
                                if (RegExp(r'^\d$').hasMatch(lastChar)) {
                                  _unitsInPackageController.value =
                                      TextEditingValue(
                                        text: lastChar,
                                        selection: TextSelection.collapsed(
                                          offset: 1,
                                        ),
                                      );
                                  _shouldClearOnNextInput = false;
                                  final newUnitsInPackage = int.tryParse(
                                    lastChar,
                                  );
                                  if (newUnitsInPackage != null &&
                                      newUnitsInPackage > 0) {
                                    // Откладываем обновление данных, чтобы не терять фокус
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          widget.onUnitsInPackageChanged(
                                            newUnitsInPackage,
                                          );
                                        });
                                  }
                                  // Устанавливаем курсор в конец после первого ввода
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (_unitsInPackageFocus.hasFocus &&
                                        mounted) {
                                      final textLength =
                                          _unitsInPackageController.text.length;
                                      _unitsInPackageController.selection =
                                          TextSelection.collapsed(
                                            offset: textLength,
                                          );
                                    }
                                  });
                                  return;
                                }
                              }
                            }

                            // Обновляем значение при вводе с цифровой клавиатуры
                            final newUnitsInPackage = int.tryParse(value);
                            if (newUnitsInPackage != null &&
                                newUnitsInPackage > 0) {
                              // Откладываем обновление данных, чтобы не терять фокус
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                widget.onUnitsInPackageChanged(
                                  newUnitsInPackage,
                                );
                              });
                              _shouldClearOnNextInput = false;
                            }
                            // Устанавливаем курсор в конец после изменения (как в поле "Получено")
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_unitsInPackageFocus.hasFocus && mounted) {
                                final textLength =
                                    _unitsInPackageController.text.length;
                                _unitsInPackageController.selection =
                                    TextSelection.collapsed(offset: textLength);
                              }
                            });
                          },
                        ),
                      ),
                      if (widget.item.unitsInPackage !=
                          widget.item.product.unitsPerPackage)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'стандарт: ${widget.item.product.unitsPerPackage}',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Сумма
                SizedBox(
                  width: 130,
                  child: Text(
                    Formatters.formatMoney(widget.item.total),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1976D2),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                // Действия
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onDelete,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
