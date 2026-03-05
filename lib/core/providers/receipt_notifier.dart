import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/cashier/models/receipt.dart';
import '../../features/cashier/models/receipt_item.dart';
import '../../features/cashier/models/product.dart';
import '../../features/shared/models/client.dart';
import '../errors/app_exception.dart';
import '../localization/app_localizations.dart';
import '../models/app_settings.dart';
import 'multi_receipt_notifier.dart';
import 'repository_providers.dart';
import 'settings_notifier.dart';

part 'receipt_notifier.g.dart';

/// Состояние чека (работает с текущим активным чеком из multiReceiptStateProvider)
@riverpod
class ReceiptState extends _$ReceiptState {
  bool _creatingInitialReceipt = false;
  final Map<String, bool> _manualDiscountOverride = {};
  static const double _stockEpsilon = 0.0001;

  @override
  Receipt build() {
    // Отслеживаем изменения multiReceiptStateProvider
    // Когда multiReceiptStateProvider обновляется, этот build() будет вызван снова
    ref.watch(multiReceiptStateProvider);
    final currentReceipt = ref.read(multiReceiptStateProvider.notifier).currentReceipt;
    
    if (currentReceipt != null) {
      // Возвращаем копию receipt из multiReceiptStateProvider
      final receipt = currentReceipt.receipt;
      return Receipt(
        items: List.from(receipt.items),
        discount: receipt.discount,
        discountPercent: receipt.discountPercent,
        discountIsPercent: receipt.discountIsPercent,
        bonuses: receipt.bonuses,
        received: receipt.received,
        clientId: receipt.clientId,
      );
    }
    // Если нет активного чека, создаем новый
    if (!_creatingInitialReceipt) {
      _creatingInitialReceipt = true;
      Future.microtask(() {
        final multiReceiptNotifier = ref.read(multiReceiptStateProvider.notifier);
        final existingId = multiReceiptNotifier.currentReceiptId;
        final newId = existingId ?? multiReceiptNotifier.createNewReceipt();
        final newReceipt = multiReceiptNotifier.getReceipt(newId);
        if (newReceipt != null) {
          state = Receipt(
            items: List.from(newReceipt.items),
            discount: newReceipt.discount,
            discountPercent: newReceipt.discountPercent,
            discountIsPercent: newReceipt.discountIsPercent,
            bonuses: newReceipt.bonuses,
            received: newReceipt.received,
            clientId: newReceipt.clientId,
          );
        } else {
          state = Receipt();
        }
        _creatingInitialReceipt = false;
      });
    }
    return Receipt();
  }
  
  /// Получить ID текущего активного чека
  String? get _currentReceiptId {
    return ref.read(multiReceiptStateProvider.notifier).currentReceiptId;
  }

  bool get _hasManualDiscountOverride {
    final receiptId = _currentReceiptId;
    if (receiptId == null) return false;
    return _manualDiscountOverride[receiptId] ?? false;
  }

  void _setManualDiscountOverride(bool enabled) {
    final receiptId = _currentReceiptId;
    if (receiptId == null) return;
    if (enabled) {
      _manualDiscountOverride[receiptId] = true;
    } else {
      _manualDiscountOverride.remove(receiptId);
    }
  }

  List<DiscountRule> _getDiscountRules() {
    final settingsAsync = ref.read(appSettingsStateProvider);
    return settingsAsync.maybeWhen(
      data: (settings) => settings.discountRules,
      orElse: () => const [],
    );
  }

  double _getBonusAccrualPercent() {
    final settingsAsync = ref.read(appSettingsStateProvider);
    return settingsAsync.maybeWhen(
      data: (settings) => settings.bonusAccrualPercent,
      orElse: () => 5.0,
    );
  }

  Receipt _cloneReceiptWithDiscount(
    Receipt receipt, {
    double? discount,
    double? discountPercent,
    bool? discountIsPercent,
  }) {
    return Receipt(
      items: List<ReceiptItem>.from(receipt.items),
      discount: discount ?? receipt.discount,
      discountPercent: discountPercent ?? receipt.discountPercent,
      discountIsPercent: discountIsPercent ?? receipt.discountIsPercent,
      bonuses: receipt.bonuses,
      received: receipt.received,
      clientId: receipt.clientId,
    );
  }

  Receipt _applyAutoDiscountIfAllowed(Receipt receipt) {
    if (_hasManualDiscountOverride) {
      return receipt;
    }

    final rules = _getDiscountRules();
    if (rules.isEmpty) {
      if (!receipt.discountIsPercent && receipt.discount == 0) {
        return receipt;
      }
      if (receipt.discountIsPercent && receipt.discountPercent == 0 && receipt.discount == 0) {
        return receipt;
      }
      return _cloneReceiptWithDiscount(
        receipt,
        discount: 0.0,
        discountPercent: 0.0,
        discountIsPercent: false,
      );
    }

    final sortedRules = List<DiscountRule>.from(rules)
      ..sort((a, b) => b.minTotal.compareTo(a.minTotal));

    DiscountRule? matched;
    for (final rule in sortedRules) {
      if (receipt.subtotal >= rule.minTotal) {
        matched = rule;
        break;
      }
    }

    if (matched == null || matched.percent <= 0) {
      if (!receipt.discountIsPercent && receipt.discount == 0) {
        return receipt;
      }
      if (receipt.discountIsPercent && receipt.discountPercent == 0 && receipt.discount == 0) {
        return receipt;
      }
      return _cloneReceiptWithDiscount(
        receipt,
        discount: 0.0,
        discountPercent: 0.0,
        discountIsPercent: false,
      );
    }

    final percent = matched.percent;
    if (receipt.discountIsPercent &&
        receipt.discount == 0.0 &&
        (receipt.discountPercent - percent).abs() < 0.0001) {
      return receipt;
    }

    return _cloneReceiptWithDiscount(
      receipt,
      discount: 0.0,
      discountPercent: percent,
      discountIsPercent: true,
    );
  }
  
  /// Обновить текущий чек в multiReceiptStateProvider
  void _updateCurrentReceipt(Receipt receipt) {
    final processedReceipt = _applyAutoDiscountIfAllowed(receipt);
    final receiptId = _currentReceiptId;
    if (receiptId != null) {
      print('🟢 ReceiptState: Обновление чека $receiptId, товаров: ${processedReceipt.items.length}, received: ${processedReceipt.received}, total: ${processedReceipt.total}, canCheckout: ${processedReceipt.canCheckout}');
      
      // Создаем новый объект Receipt с новым списком items, чтобы гарантировать обновление
      final updatedReceipt = Receipt(
        items: processedReceipt.items.map((item) => ReceiptItem(
          id: item.id,
          product: item.product,
          quantity: item.quantity,
          price: item.price,
          index: item.index,
          unitsInPackage: item.unitsInPackage,
        )).toList(),
        discount: processedReceipt.discount,
        discountPercent: processedReceipt.discountPercent,
        discountIsPercent: processedReceipt.discountIsPercent,
        bonuses: processedReceipt.bonuses,
        received: processedReceipt.received,
        clientId: processedReceipt.clientId,
      );
      
      print('🟢 ReceiptState: Новый receipt создан. received: ${updatedReceipt.received}, total: ${updatedReceipt.total}, change: ${updatedReceipt.change}, canCheckout: ${updatedReceipt.canCheckout}');
      
      // Обновляем multiReceiptStateProvider
      ref.read(multiReceiptStateProvider.notifier).updateReceipt(receiptId, updatedReceipt);
      
      // Обновляем локальное состояние - это обновит все виджеты, которые смотрят на receiptStateProvider
      state = updatedReceipt;
      print('🟢 ReceiptState: Состояние обновлено. state.received: ${state.received}, state.total: ${state.total}, state.canCheckout: ${state.canCheckout}');
    } else {
      print('❌ ReceiptState: receiptId равен null, не могу обновить чек');
      // Если receiptId равен null, создаем новый чек
      final newId = ref.read(multiReceiptStateProvider.notifier).createNewReceipt();
      final newReceipt = ref.read(multiReceiptStateProvider.notifier).getReceipt(newId);
      if (newReceipt != null) {
        state = newReceipt;
      }
    }
  }

  void _ensureStockAvailable(Product product, double targetUnits) {
    final unitsPerPackage = product.unitsPerPackage <= 0 ? 1 : product.unitsPerPackage;
    final maxUnits = (product.stock * unitsPerPackage).toDouble();

    if (maxUnits <= 0 || targetUnits - maxUnits > _stockEpsilon) {
      _throwOutOfStock(product);
    }
  }

  Never _throwOutOfStock(Product product) {
    final loc = ref.read(appLocalizationsProvider);
    final unitLabel = product.unit.isNotEmpty
        ? product.unit
        : loc.packages.toLowerCase();
    throw ValidationException(
      loc.stockLimitExceeded(product.stock, unitLabel),
      code: 'stock_limit_exceeded',
    );
  }

  /// Добавить товар в чек
  void addProduct(Product product, {double quantity = 1.0}) {
    print('🟢 ReceiptState: addProduct вызван для товара: ${product.name}, текущих товаров: ${state.items.length}');
    final receipt = state;
    final newItems = List<ReceiptItem>.from(receipt.items);
    
    // Проверяем, есть ли уже такой товар в чеке
    final existingIndex = newItems.indexWhere(
      (item) => item.product.id == product.id,
    );
    
    final quantityInUnits = quantity * product.unitsPerPackage;
    
    if (existingIndex >= 0) {
      // Увеличиваем количество существующего товара
      final existingItem = newItems[existingIndex];
      final newQuantity = existingItem.quantity + quantityInUnits;
      _ensureStockAvailable(product, newQuantity);
      newItems[existingIndex] = existingItem.copyWith(quantity: newQuantity);
      print('🟢 ReceiptState: Товар уже в чеке, увеличиваем количество. Новое количество: ${newItems[existingIndex].quantity}');
    } else {
      // Добавляем новый товар
      _ensureStockAvailable(product, quantityInUnits);
      final item = ReceiptItem(
        id: DateTime.now().millisecondsSinceEpoch,
        product: product,
        quantity: quantityInUnits,
        price: product.price,
        index: newItems.length + 1,
      );
      newItems.add(item);
      print('🟢 ReceiptState: Новый товар добавлен. Всего товаров: ${newItems.length}');
    }
    
    // Обновляем индексы
    for (int i = 0; i < newItems.length; i++) {
      newItems[i] = newItems[i].copyWith(index: i + 1);
    }
    
    final updatedReceipt = Receipt(
      items: newItems,
      discount: receipt.discount,
      discountPercent: receipt.discountPercent,
      discountIsPercent: receipt.discountIsPercent,
      bonuses: receipt.bonuses,
      received: receipt.received,
      clientId: receipt.clientId,
    );
    _updateCurrentReceipt(updatedReceipt);
  }

  /// Удалить товар из чека
  void removeItem(int index) {
    final receipt = state;
    if (index < 0 || index >= receipt.items.length) return;
    
    final newItems = List<ReceiptItem>.from(receipt.items);
    newItems.removeAt(index);
    
    // Обновляем индексы
    for (int i = 0; i < newItems.length; i++) {
      newItems[i] = newItems[i].copyWith(index: i + 1);
    }
    
    final updatedReceipt = Receipt(
      items: newItems,
      discount: receipt.discount,
      discountPercent: receipt.discountPercent,
      discountIsPercent: receipt.discountIsPercent,
      bonuses: receipt.bonuses,
      received: receipt.received,
      clientId: receipt.clientId,
    );
    _updateCurrentReceipt(updatedReceipt);
  }

  /// Обновить количество товара
  void updateQuantity(int index, double quantity) {
    final receipt = state;
    if (index < 0 || index >= receipt.items.length) return;
    
    final oldItem = receipt.items[index];
    _ensureStockAvailable(oldItem.product, quantity);
    print('🟢 ReceiptState: updateQuantity вызван. index: $index, oldQuantity: ${oldItem.quantity}, newQuantity: $quantity, oldTotal: ${oldItem.total}, price: ${oldItem.price}, unitsInPackage: ${oldItem.unitsInPackage}');
    
    final newItems = List<ReceiptItem>.from(receipt.items);
    newItems[index] = newItems[index].copyWith(quantity: quantity);
    
    final newItem = newItems[index];
    print('🟢 ReceiptState: updateQuantity новый item. quantity: ${newItem.quantity}, total: ${newItem.total}, price: ${newItem.price}, unitsInPackage: ${newItem.unitsInPackage}');
    
    final updatedReceipt = Receipt(
      items: newItems,
      discount: receipt.discount,
      discountPercent: receipt.discountPercent,
      discountIsPercent: receipt.discountIsPercent,
      bonuses: receipt.bonuses,
      received: receipt.received,
      clientId: receipt.clientId,
    );
    print('🟢 ReceiptState: updateQuantity новый receipt. items.length: ${updatedReceipt.items.length}, subtotal: ${updatedReceipt.subtotal}, total: ${updatedReceipt.total}');
    _updateCurrentReceipt(updatedReceipt);
  }

  /// Обновить цену товара
  void updatePrice(int index, double price) {
    final receipt = state;
    if (index < 0 || index >= receipt.items.length) return;
    
    final newItems = List<ReceiptItem>.from(receipt.items);
    newItems[index] = newItems[index].copyWith(price: price);
    
    final updatedReceipt = Receipt(
      items: newItems,
      discount: receipt.discount,
      discountPercent: receipt.discountPercent,
      discountIsPercent: receipt.discountIsPercent,
      bonuses: receipt.bonuses,
      received: receipt.received,
      clientId: receipt.clientId,
    );
    _updateCurrentReceipt(updatedReceipt);
  }

  /// Обновить количество единиц в упаковке
  void updateUnitsInPackage(int index, int unitsInPackage) {
    final receipt = state;
    if (index < 0 || index >= receipt.items.length) return;
    
    final oldItem = receipt.items[index];
    print('🟢 ReceiptState: updateUnitsInPackage вызван. index: $index, oldUnitsInPackage: ${oldItem.unitsInPackage}, newUnitsInPackage: $unitsInPackage, oldTotal: ${oldItem.total}, quantity: ${oldItem.quantity}, price: ${oldItem.price}');
    
    final newItems = List<ReceiptItem>.from(receipt.items);
    newItems[index] = newItems[index].copyWith(unitsInPackage: unitsInPackage);
    
    final newItem = newItems[index];
    print('🟢 ReceiptState: updateUnitsInPackage новый item. unitsInPackage: ${newItem.unitsInPackage}, total: ${newItem.total}, quantity: ${newItem.quantity}, price: ${newItem.price}, pricePerUnit: ${newItem.pricePerUnit}');
    
    final updatedReceipt = Receipt(
      items: newItems,
      discount: receipt.discount,
      discountPercent: receipt.discountPercent,
      discountIsPercent: receipt.discountIsPercent,
      bonuses: receipt.bonuses,
      received: receipt.received,
      clientId: receipt.clientId,
    );
    print('🟢 ReceiptState: updateUnitsInPackage новый receipt. items.length: ${updatedReceipt.items.length}, subtotal: ${updatedReceipt.subtotal}, total: ${updatedReceipt.total}');
    _updateCurrentReceipt(updatedReceipt);
  }

  /// Увеличить количество на одну упаковку
  void increaseQuantityByUnit(int index) {
    final receipt = state;
    if (index < 0 || index >= receipt.items.length) return;
    
    final item = receipt.items[index];
    updateQuantity(index, item.quantity + item.unitsInPackage);
  }

  /// Уменьшить количество на одну упаковку
  void decreaseQuantityByUnit(int index) {
    final receipt = state;
    if (index < 0 || index >= receipt.items.length) return;
    
    final item = receipt.items[index];
    if (item.quantity > item.unitsInPackage) {
      updateQuantity(index, item.quantity - item.unitsInPackage);
    } else {
      updateQuantity(index, 1);
    }
  }

  /// Применить скидку (процент)
  void applyDiscountPercent(double percent) {
    final receipt = state;
    _setManualDiscountOverride(percent > 0);
    final updatedReceipt = Receipt(
      items: receipt.items,
      discount: 0.0,
      discountPercent: percent,
      discountIsPercent: true,
      bonuses: receipt.bonuses,
      received: receipt.received,
      clientId: receipt.clientId,
    );
    _updateCurrentReceipt(updatedReceipt);
  }

  /// Применить скидку (сумма)
  void applyDiscountAmount(double amount) {
    final receipt = state;
    _setManualDiscountOverride(amount > 0);
    final updatedReceipt = Receipt(
      items: receipt.items,
      discount: amount,
      discountPercent: 0.0,
      discountIsPercent: false,
      bonuses: receipt.bonuses,
      received: receipt.received,
      clientId: receipt.clientId,
    );
    _updateCurrentReceipt(updatedReceipt);
  }

  /// Установить бонусы
  void setBonuses(double bonuses) {
    final receipt = state;
    final updatedReceipt = Receipt(
      items: receipt.items,
      discount: receipt.discount,
      discountPercent: receipt.discountPercent,
      discountIsPercent: receipt.discountIsPercent,
      bonuses: bonuses,
      received: receipt.received,
      clientId: receipt.clientId,
    );
    _updateCurrentReceipt(updatedReceipt);
  }

  /// Установить полученную сумму
  void setReceived(double received) {
    final receipt = state;
    print('🟢 ReceiptState: setReceived вызван. received: $received, total: ${receipt.total}, canCheckout: ${receipt.canCheckout}');
    final updatedReceipt = Receipt(
      items: receipt.items,
      discount: receipt.discount,
      discountPercent: receipt.discountPercent,
      discountIsPercent: receipt.discountIsPercent,
      bonuses: receipt.bonuses,
      received: received,
      clientId: receipt.clientId,
    );
    print('🟢 ReceiptState: Новый receipt. received: ${updatedReceipt.received}, total: ${updatedReceipt.total}, change: ${updatedReceipt.change}, canCheckout: ${updatedReceipt.canCheckout}');
    _updateCurrentReceipt(updatedReceipt);
  }

  /// Установить клиента
  void setClient(Client? client) {
    final receipt = state;
    final receiptId = _currentReceiptId;
    final updatedReceipt = Receipt(
      items: receipt.items,
      discount: receipt.discount,
      discountPercent: receipt.discountPercent,
      discountIsPercent: receipt.discountIsPercent,
      bonuses: receipt.bonuses,
      received: receipt.received,
      clientId: client?.id,
    );
    _updateCurrentReceipt(updatedReceipt);
    // Обновляем имя клиента в multiReceiptStateProvider
    if (receiptId != null) {
      ref.read(multiReceiptStateProvider.notifier).updateClientName(receiptId, client?.name);
    }
  }

  /// Очистить чек (создает новый чек вместо очистки текущего)
  void clearReceipt() {
    // Создаем новый чек вместо очистки текущего
    ref.read(multiReceiptStateProvider.notifier).createNewReceipt();
    // Обновляем состояние на новый чек
    final currentReceipt = ref.read(multiReceiptStateProvider.notifier).currentReceipt;
    if (currentReceipt != null) {
      state = currentReceipt.receipt;
    } else {
    state = Receipt();
    }
  }

  /// Оплатить чек
  Future<String> checkout({int? userId}) async {
    final receipt = state;
    if (!receipt.canCheckout) {
      throw Exception('Чек не готов к оплате');
    }

    final receiptRepo = ref.read(receiptRepositoryProvider);
    final bonusPercent = _getBonusAccrualPercent();
    final receiptNumber = await receiptRepo.saveReceipt(
      receipt,
      userId: userId,
      bonusPercent: bonusPercent,
    );
    
    // Сохраняем ссылку на notifier до изменения состояния
    final multiReceiptNotifier = ref.read(multiReceiptStateProvider.notifier);
    
    // Удаляем чек из активных после успешной оплаты
    final receiptId = _currentReceiptId;
    if (receiptId != null) {
      multiReceiptNotifier.removeReceipt(receiptId);
      _manualDiscountOverride.remove(receiptId);
    }
    
    // Создаем новый чек для следующей продажи
    final newReceiptId = multiReceiptNotifier.createNewReceipt();
    
    // Получаем новый чек напрямую из notifier (без использования ref.read)
    // чтобы избежать ошибки "Cannot use ref functions after the dependency changed"
    final newReceipt = multiReceiptNotifier.getReceipt(newReceiptId);
    if (newReceipt != null) {
      // Обновляем состояние напрямую, без использования ref
      state = Receipt(
        items: List.from(newReceipt.items),
        discount: newReceipt.discount,
        discountPercent: newReceipt.discountPercent,
        discountIsPercent: newReceipt.discountIsPercent,
        bonuses: newReceipt.bonuses,
        received: newReceipt.received,
        clientId: newReceipt.clientId,
      );
    } else {
      state = Receipt();
    }
    
    return receiptNumber;
  }
}

