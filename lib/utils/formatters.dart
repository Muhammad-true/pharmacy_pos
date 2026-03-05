class Formatters {
  /// Форматирование денежной суммы (только целые числа, без копеек)
  static String formatMoney(double amount) {
    // Округляем до целого числа
    final roundedAmount = amount.round();
    final amountStr = roundedAmount.toString();

    // Добавляем пробелы как разделители тысяч
    String formatted = '';
    int count = 0;
    for (int i = amountStr.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        formatted = ' $formatted';
      }
      formatted = amountStr[i] + formatted;
      count++;
    }

    return '$formatted с';
  }

  /// Форматирование накопительных баллов (с десятичными знаками)
  static String formatBonuses(double amount) {
    // Определяем количество десятичных знаков
    // Если число целое, показываем без десятичных знаков
    // Если есть десятичные знаки, показываем до 2 знаков после запятой
    final decimals = amount % 1 == 0 ? 0 : 2;
    final numberStr = amount.toStringAsFixed(decimals);
    final parts = numberStr.split('.');
    final integerPart = parts[0];

    // Добавляем пробелы как разделители тысяч
    String formatted = '';
    int count = 0;
    for (int i = integerPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        formatted = ' $formatted';
      }
      formatted = integerPart[i] + formatted;
      count++;
    }

    // Добавляем десятичную часть, если есть
    if (decimals > 0 && parts.length > 1) {
      formatted = '$formatted,${parts[1]}';
    }

    return '$formatted с';
  }

  /// Форматирование числа с разделителями тысяч
  static String formatNumber(double number, {int decimals = 2}) {
    final numberStr = number.toStringAsFixed(decimals);
    final parts = numberStr.split('.');
    final integerPart = parts[0];

    String formatted = '';
    int count = 0;
    for (int i = integerPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        formatted = ' $formatted';
      }
      formatted = integerPart[i] + formatted;
      count++;
    }

    if (decimals <= 0) {
      return formatted;
    }

    final decimalPart = parts.length > 1
        ? parts[1]
        : ''.padRight(decimals, '0');
    return '$formatted,$decimalPart';
  }

  /// Форматирование даты в формате ДД.ММ.ГГГГ
  static String formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d.$m.$y';
  }

  /// Форматирование даты и времени в формате ДД.ММ.ГГГГ ЧЧ:ММ
  static String formatDateTime(DateTime dateTime) {
    final d = dateTime.day.toString().padLeft(2, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    final y = dateTime.year.toString();
    final h = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $h:$min';
  }

  /// Парсинг денежной строки в число
  static double? parseMoney(String value) {
    if (value.isEmpty) return null;
    final cleaned = value.replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  /// Парсинг числа из строки
  static double? parseNumber(String value) {
    if (value.isEmpty) return null;
    final cleaned = value.replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }
}
