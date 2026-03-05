import 'dart:math';

/// Утилита для генерации QR кодов
class QrCodeGenerator {
  /// Генерирует уникальный QR код для клиента
  /// Формат: CLIENT-{timestamp}-{random}
  static String generateClientQrCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999).toString().padLeft(4, '0');
    return 'CLIENT-$timestamp-$random';
  }

  /// Генерирует QR код на основе данных клиента
  /// Если передать имя и телефон, создаст более читаемый код
  static String generateClientQrCodeFromData({
    String? name,
    String? phone,
  }) {
    if (name != null && phone != null) {
      // Создаем код на основе имени и телефона (первые буквы имени + телефон)
      final namePrefix = name
          .split(' ')
          .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
          .join('')
          .substring(0, name.split(' ').length > 1 ? 2 : 1);
      final phoneDigits = phone.replaceAll(RegExp(r'[^\d]'), '').substring(
          phone.replaceAll(RegExp(r'[^\d]'), '').length > 6
              ? phone.replaceAll(RegExp(r'[^\d]'), '').length - 6
              : 0);
      return 'CLIENT-$namePrefix$phoneDigits';
    }
    // Если данных нет, генерируем случайный код
    return generateClientQrCode();
  }
}

