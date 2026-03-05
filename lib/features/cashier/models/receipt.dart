import 'receipt_item.dart';

class Receipt {
  final List<ReceiptItem> items;
  double discount;
  double discountPercent;
  bool discountIsPercent;
  double bonuses;
  double received;
  int? clientId;

  Receipt({
    List<ReceiptItem>? items,
    this.discount = 0.0,
    this.discountPercent = 0.0,
    this.discountIsPercent = false,
    this.bonuses = 0.0,
    this.received = 0.0,
    this.clientId,
  }) : items = items ?? [];

  double get subtotal {
    return items.fold(0.0, (sum, item) => sum + item.total);
  }

  double get totalDiscount {
    if (discountIsPercent) {
      return subtotal * (discountPercent / 100);
    }
    return discount;
  }

  double get total {
    // Итоговая сумма = подытог - скидка - бонусы
    // Но итог не может быть отрицательным - минимум 0
    final calculatedTotal = subtotal - totalDiscount - bonuses;
    return calculatedTotal < 0 ? 0.0 : calculatedTotal;
  }

  double get change {
    // Сдача = получено - итоговая сумма
    // Если получено больше чем нужно, сдача положительная
    // Если получено меньше чем нужно, сдача отрицательная (но это не сдача, а недоплата)
    return received - total;
  }

  bool get isEmpty => items.isEmpty;

  bool get canCheckout {
    // Чек готов к оплате если:
    // 1. Есть товары в чеке
    // 2. Полученная сумма >= итоговой сумме (с учетом погрешности чисел с плавающей запятой)
    
    if (isEmpty) return false;
    
    // Итоговая сумма всегда >= 0 (ограничено в геттере total)
    // Если итоговая сумма равна 0, то достаточно, чтобы received >= 0
    if (total <= 0) {
      return received >= 0;
    }
    
    // Обычный случай: received >= total и total > 0
    // Используем сравнение с небольшой погрешностью для чисел с плавающей запятой
    const epsilon = 0.01; // Погрешность 1 копейка
    return received >= (total - epsilon);
  }

  void addItem(ReceiptItem item) {
    items.add(item);
    _updateIndices();
  }

  void removeItem(int index) {
    if (index >= 0 && index < items.length) {
      items.removeAt(index);
      _updateIndices();
    }
  }

  void clear() {
    items.clear();
    discount = 0.0;
    discountPercent = 0.0;
    discountIsPercent = false;
    bonuses = 0.0;
    received = 0.0;
    clientId = null;
  }

  void updateIndices() {
    for (int i = 0; i < items.length; i++) {
      items[i].index = i + 1;
    }
  }

  void _updateIndices() {
    updateIndices();
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'total': total,
      'discount': totalDiscount,
      'discountPercent': discountIsPercent ? discountPercent : 0.0,
      'bonuses': bonuses,
      'received': received,
      'change': change,
      'clientId': clientId,
      'paymentMethod': 'cash',
    };
  }
}

