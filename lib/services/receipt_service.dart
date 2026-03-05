import '../features/cashier/models/receipt.dart';
import '../features/cashier/models/receipt_item.dart';
import '../features/cashier/models/product.dart';
import '../features/cashier/models/active_receipt.dart';
import 'api/api_service.dart';

class ReceiptService {
  final Map<String, ActiveReceipt> _activeReceipts = {};
  String? _currentReceiptId;
  
  /// Получить текущий активный чек
  ActiveReceipt? get currentReceipt {
    if (_currentReceiptId == null) return null;
    return _activeReceipts[_currentReceiptId];
  }
  
  /// Получить текущий чек (для обратной совместимости)
  Receipt get receipt {
    final active = currentReceipt;
    if (active == null) {
      // Создаем новый чек, если нет активного
      final newId = _generateReceiptId();
      final newReceipt = Receipt();
      _activeReceipts[newId] = ActiveReceipt(
        id: newId,
        receipt: newReceipt,
      );
      _currentReceiptId = newId;
      return newReceipt;
    }
    return active.receipt;
  }
  
  /// Получить список всех активных чеков
  List<ActiveReceipt> get activeReceipts => _activeReceipts.values.toList();
  
  /// Создать новый чек
  String createNewReceipt() {
    final newId = _generateReceiptId();
    final newReceipt = Receipt();
    _activeReceipts[newId] = ActiveReceipt(
      id: newId,
      receipt: newReceipt,
    );
    _currentReceiptId = newId;
    return newId;
  }
  
  /// Переключиться на другой чек
  void switchToReceipt(String receiptId) {
    if (_activeReceipts.containsKey(receiptId)) {
      _currentReceiptId = receiptId;
    }
  }
  
  /// Удалить чек
  void removeReceipt(String receiptId) {
    _activeReceipts.remove(receiptId);
    if (_currentReceiptId == receiptId) {
      // Если удалили текущий чек, переключаемся на первый доступный
      if (_activeReceipts.isEmpty) {
        _currentReceiptId = null;
      } else {
        _currentReceiptId = _activeReceipts.keys.first;
      }
    }
  }
  
  /// Обновить имя клиента для текущего чека
  void updateClientName(String? clientName) {
    final active = currentReceipt;
    if (active != null) {
      _activeReceipts[active.id] = ActiveReceipt(
        id: active.id,
        receipt: active.receipt,
        clientName: clientName,
        createdAt: active.createdAt,
      );
    }
  }
  
  String _generateReceiptId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  
  Receipt _getCurrentReceipt() {
    final active = currentReceipt;
    if (active == null) {
      // Создаем новый чек, если нет активного
      createNewReceipt();
      return _activeReceipts[_currentReceiptId!]!.receipt;
    }
    return active.receipt;
  }

  /// Добавить товар в чек
  void addItem(Product product, {double quantity = 1.0, double? price}) {
    final receipt = _getCurrentReceipt();
    // quantity - количество упаковок, переводим в единицы
    final quantityInUnits = quantity * product.unitsPerPackage;
    
    final item = ReceiptItem(
      id: DateTime.now().millisecondsSinceEpoch,
      product: product,
      quantity: quantityInUnits,
      price: price ?? product.price,
      index: receipt.items.length + 1,
    );
    receipt.addItem(item);
  }

  /// Удалить позицию из чека
  void removeItem(int index) {
    final receipt = _getCurrentReceipt();
    receipt.removeItem(index);
  }

  /// Обновить количество товара (в единицах)
  void updateQuantity(int index, double quantity) {
    final receipt = _getCurrentReceipt();
    if (index >= 0 && index < receipt.items.length) {
      receipt.items[index].quantity = quantity;
    }
  }

  /// Увеличить количество на одну упаковку
  void increaseQuantityByUnit(int index) {
    final receipt = _getCurrentReceipt();
    if (index >= 0 && index < receipt.items.length) {
      final item = receipt.items[index];
      // Используем текущее количество единиц в упаковке (может быть изменено пользователем)
      // Это гарантирует, что мы добавляем одну упаковку с текущим размером
      item.quantity += item.unitsInPackage;
      // Принудительно обновляем индекс для отслеживания изменений
      receipt.updateIndices();
    }
  }

  /// Уменьшить количество на одну упаковку
  void decreaseQuantityByUnit(int index) {
    final receipt = _getCurrentReceipt();
    if (index >= 0 && index < receipt.items.length) {
      final item = receipt.items[index];
      // Используем текущее количество единиц в упаковке (может быть изменено пользователем)
      // Это гарантирует, что мы удаляем одну упаковку с текущим размером
      if (item.quantity > item.unitsInPackage) {
        item.quantity -= item.unitsInPackage;
      } else {
        // Если осталось меньше одной упаковки, оставляем 1 единицу
        item.quantity = 1;
      }
      // Принудительно обновляем индекс для отслеживания изменений
      receipt.updateIndices();
    }
  }

  /// Обновить цену товара
  void updatePrice(int index, double price) {
    final receipt = _getCurrentReceipt();
    if (index >= 0 && index < receipt.items.length) {
      receipt.items[index].price = price;
    }
  }

  /// Обновить количество таблеток в упаковке
  void updateUnitsInPackage(int index, int unitsInPackage) {
    final receipt = _getCurrentReceipt();
    if (index >= 0 && index < receipt.items.length) {
      receipt.items[index].unitsInPackage = unitsInPackage;
    }
  }

  /// Применить скидку
  void applyDiscount({double? percent, double? amount}) {
    final receipt = _getCurrentReceipt();
    if (percent != null) {
      receipt.discountIsPercent = true;
      receipt.discountPercent = percent;
      receipt.discount = 0.0;
    } else if (amount != null) {
      receipt.discountIsPercent = false;
      receipt.discount = amount;
      receipt.discountPercent = 0.0;
    }
  }

  /// Установить бонусы
  void setBonuses(double bonuses) {
    final receipt = _getCurrentReceipt();
    receipt.bonuses = bonuses;
  }

  /// Установить полученную сумму
  void setReceived(double received) {
    final receipt = _getCurrentReceipt();
    receipt.received = received;
  }

  /// Установить клиента
  void setClient(int? clientId) {
    final receipt = _getCurrentReceipt();
    receipt.clientId = clientId;
  }

  /// Очистить текущий чек
  void clearReceipt() {
    final receipt = _getCurrentReceipt();
    receipt.clear();
  }

  /// Оплатить текущий чек
  Future<Map<String, dynamic>> checkout() async {
    final receipt = _getCurrentReceipt();
    if (!receipt.canCheckout) {
      throw Exception('Невозможно выполнить оплату. Проверьте данные чека.');
    }

    final receiptData = receipt.toJson();
    
    // Начисляем баллы постоянным клиентам (5% от итоговой суммы после всех скидок и бонусов)
    // НО: если клиент списал бонусы (bonuses > 0), то новые бонусы не начисляем
    double? accumulatedBonuses;
    if (receipt.clientId != null && receipt.bonuses == 0) {
      try {
        final client = await ApiService.getClient(receipt.clientId!);
        if (client != null) {
          // Начисляем баллы: 5% от итоговой суммы покупки (после применения скидки и бонусов)
          accumulatedBonuses = receipt.total * 0.05;
          
          // Обновляем бонусы клиента в БД
          await ApiService.updateClientBonuses(
            clientId: receipt.clientId!,
            bonusesToAdd: accumulatedBonuses,
          );
          
          print('Начислено баллов клиенту ${client.name}: ${accumulatedBonuses.toStringAsFixed(2)} с (5% от итога ${receipt.total.toStringAsFixed(2)} с)');
        }
      } catch (e) {
        // Игнорируем ошибки при начислении баллов, чтобы не блокировать оплату
        print('Ошибка при начислении баллов: $e');
      }
    }
    
    // Если клиент списал бонусы, обновляем баланс в БД
    if (receipt.clientId != null && receipt.bonuses > 0) {
      try {
        await ApiService.updateClientBonuses(
          clientId: receipt.clientId!,
          bonusesToSubtract: receipt.bonuses,
        );
        print('Списано бонусов у клиента: ${receipt.bonuses.toStringAsFixed(2)} с');
      } catch (e) {
        // Игнорируем ошибки при списании бонусов, чтобы не блокировать оплату
        print('Ошибка при списании бонусов: $e');
      }
    }

    final result = await ApiService.checkout(receiptData);

    // Добавляем информацию о начисленных бонусах в результат
    if (accumulatedBonuses != null) {
      result['accumulatedBonuses'] = accumulatedBonuses;
    }

    // После успешной оплаты удаляем чек из активных
    if (result['success'] == true && _currentReceiptId != null) {
      removeReceipt(_currentReceiptId!);
      // Создаем новый чек для следующей продажи
      if (_activeReceipts.isEmpty) {
        createNewReceipt();
      }
    }

    return result;
  }
}

