import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/auth_notifier.dart';
import '../../../utils/formatters.dart';
import '../../cashier/models/product.dart';

/// Диалог для пополнения склада
class RestockDialog extends ConsumerStatefulWidget {
  final Product product;

  const RestockDialog({
    super.key,
    required this.product,
  });

  @override
  ConsumerState<RestockDialog> createState() => _RestockDialogState();
}

class _RestockDialogState extends ConsumerState<RestockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  final _priceController = TextEditingController();
  final _expiryDateController = TextEditingController();
  DateTime? _expiryDate;
  bool _changePrice = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _priceController.text = widget.product.price.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    _priceController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _restock() async {
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите срок годности'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final productRepo = ref.read(productRepositoryProvider);
      final quantity = int.parse(_quantityController.text.trim());
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
      final expiryText =
          'Срок годности: ${Formatters.formatDate(_expiryDate!)}';
      final combinedNotes = [
        if (notes != null) notes,
        expiryText,
      ].join(' | ');

      // Получаем текущий пользователь для записи в историю
      final currentUser = ref.read(authStateProvider);
      final userId = currentUser?.id;

      // Получаем текущий остаток
      final currentProduct = await productRepo.getProductById(widget.product.id);
      if (currentProduct == null) {
        throw Exception('Товар не найден');
      }

      if (_changePrice) {
        final parsedPrice = Formatters.parseMoney(_priceController.text.trim());
        if (parsedPrice == null || parsedPrice <= 0) {
          throw Exception('Некорректная цена');
        }
        final updatedProduct = Product(
          id: currentProduct.id,
          name: currentProduct.name,
          barcode: currentProduct.barcode,
          qrCode: currentProduct.qrCode,
          price: parsedPrice,
          stock: currentProduct.stock,
          unit: currentProduct.unit,
          unitsPerPackage: currentProduct.unitsPerPackage,
          unitName: currentProduct.unitName,
          manufacturerId: currentProduct.manufacturerId,
          composition: currentProduct.composition,
          indications: currentProduct.indications,
          preparationMethod: currentProduct.preparationMethod,
          requiresPrescription: currentProduct.requiresPrescription,
          inventoryCode: currentProduct.inventoryCode,
          organization: currentProduct.organization,
          shelfLocation: currentProduct.shelfLocation,
        );
        await productRepo.updateProduct(updatedProduct);
      }

      final stockBefore = currentProduct.stock;
      final stockAfter = stockBefore + quantity;

      // Увеличиваем остаток (запись в историю движения создается автоматически)
      await productRepo.updateStock(
        widget.product.id,
        stockAfter,
        movementType: 'in',
        notes: combinedNotes.isNotEmpty ? combinedNotes : 'Пополнение товара',
        userId: userId,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Склад пополнен на $quantity упаковок'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка пополнения склада: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Пополнить склад'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Текущий остаток: ${widget.product.stock} ${widget.product.unit}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Количество упаковок',
                  prefixIcon: Icon(Icons.add_circle_outline),
                  helperText: 'Сколько упаковок добавить на склад',
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
                validator: (value) {
                  final intValue = int.tryParse(value ?? '');
                  if (intValue == null || intValue <= 0) {
                    return 'Введите количество';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _expiryDateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Срок годности (дата окончания)',
                  prefixIcon: Icon(Icons.event),
                  helperText: 'Выберите дату окончания',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Укажите срок годности';
                  }
                  return null;
                },
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setState(() {
                      _expiryDate = picked;
                      _expiryDateController.text =
                          Formatters.formatDate(picked);
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _changePrice,
                onChanged: (value) {
                  setState(() {
                    _changePrice = value;
                  });
                },
                title: const Text('Изменить цену'),
                contentPadding: EdgeInsets.zero,
              ),
              if (_changePrice) ...[
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Новая цена',
                    prefixIcon: Icon(Icons.price_change),
                    helperText: 'Укажите новую цену продажи',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (!_changePrice) return null;
                    final parsed = Formatters.parseMoney(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Введите корректную цену';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Примечания',
                  prefixIcon: Icon(Icons.note_outlined),
                  hintText: 'Опционально',
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _restock,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Пополнить'),
        ),
      ],
    );
  }
}

