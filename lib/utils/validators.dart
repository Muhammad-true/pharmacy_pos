import 'formatters.dart';

class Validators {
  /// Валидация поля поиска
  static String? validateSearch(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Пустое поле допустимо
    }
    if (value.length < 1) {
      return 'Минимум 1 символ для поиска';
    }
    return null;
  }

  /// Валидация количества товара
  static String? validateQuantity(String? value, {int? maxStock}) {
    if (value == null || value.isEmpty) {
      return 'Введите количество';
    }
    final quantity = double.tryParse(value.replaceAll(',', '.'));
    if (quantity == null) {
      return 'Неверное число';
    }
    if (quantity <= 0) {
      return 'Количество должно быть больше 0';
    }
    if (quantity > 9999) {
      return 'Максимум 9999 единиц';
    }
    if (maxStock != null && quantity > maxStock) {
      return 'Недостаточно товара на складе (доступно: $maxStock)';
    }
    return null;
  }

  /// Валидация цены
  static String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите цену';
    }
    final price = double.tryParse(value.replaceAll(',', '.'));
    if (price == null) {
      return 'Неверное число';
    }
    if (price < 0) {
      return 'Цена не может быть отрицательной';
    }
    if (price > 999999.99) {
      return 'Максимальная цена: 999 999,99 с';
    }
    return null;
  }

  /// Валидация скидки (процент)
  static String? validateDiscountPercent(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Пустое поле допустимо (скидка = 0)
    }
    final percent = double.tryParse(value.replaceAll(',', '.'));
    if (percent == null) {
      return 'Неверное число';
    }
    if (percent < 0 || percent > 100) {
      return 'Скидка должна быть от 0 до 100%';
    }
    return null;
  }

  /// Валидация скидки (сумма)
  static String? validateDiscountAmount(String? value, double maxAmount) {
    if (value == null || value.isEmpty) {
      return null; // Пустое поле допустимо (скидка = 0)
    }
    final amount = double.tryParse(value.replaceAll(',', '.'));
    if (amount == null) {
      return 'Неверное число';
    }
    if (amount < 0) {
      return 'Скидка не может быть отрицательной';
    }
    if (amount > maxAmount) {
      return 'Скидка не может быть больше суммы чека';
    }
    return null;
  }

  /// Валидация бонусов
  static String? validateBonuses(String? value, {double? maxBonuses}) {
    if (value == null || value.isEmpty) {
      return null; // Пустое поле допустимо (бонусы = 0)
    }
    final bonuses = double.tryParse(value.replaceAll(',', '.'));
    if (bonuses == null) {
      return 'Неверное число';
    }
    if (bonuses < 0) {
      return 'Бонусы не могут быть отрицательными';
    }
    if (maxBonuses != null && bonuses > maxBonuses) {
      return 'Недостаточно бонусов (доступно: ${Formatters.formatMoney(maxBonuses)})';
    }
    return null;
  }

  /// Валидация полученной суммы
  static String? validateReceived(String? value, {double? minAmount}) {
    if (value == null || value.isEmpty) {
      return null; // Пустое поле допустимо
    }
    final received = double.tryParse(value.replaceAll(',', '.'));
    if (received == null) {
      return 'Неверное число';
    }
    if (received < 0) {
      return 'Сумма не может быть отрицательной';
    }
    if (received > 999999.99) {
      return 'Максимальная сумма: 999 999,99 с';
    }
    if (minAmount != null && received < minAmount) {
      return 'Недостаточно средств. Требуется: ${Formatters.formatMoney(minAmount)}';
    }
    return null;
  }
}

