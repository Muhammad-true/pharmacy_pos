/// Модель настроек приложения
import 'dart:convert';

class DiscountRule {
  final double minTotal;
  final double percent;

  const DiscountRule({
    required this.minTotal,
    required this.percent,
  });

  factory DiscountRule.fromJson(Map<String, dynamic> json) {
    return DiscountRule(
      minTotal: (json['minTotal'] as num).toDouble(),
      percent: (json['percent'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'minTotal': minTotal,
      'percent': percent,
    };
  }
}

class AppSettings {
  final String pharmacyName;
  final String language; // 'ru', 'uz', 'en'
  final String themeMode; // 'light', 'dark', 'system'
  final String primaryColor; // Hex цвет, например '#1976D2'
  final List<DiscountRule> discountRules;
  final double bonusAccrualPercent;
  final String? bankName; // Название банка
  final String? bankLogoPath; // Путь к логотипу банка
  final String? bankQrCodePath; // Путь к изображению QR кода банка
  final String? bankPhoneNumber; // Номер телефона для перевода
  final String? telegramBotToken;
  final String? telegramChatId;
  final bool telegramAutoExportEnabled;

  AppSettings({
    required this.pharmacyName,
    required this.language,
    required this.themeMode,
    required this.primaryColor,
    required this.discountRules,
    required this.bonusAccrualPercent,
    this.bankName,
    this.bankLogoPath,
    this.bankQrCodePath,
    this.bankPhoneNumber,
    this.telegramBotToken,
    this.telegramChatId,
    this.telegramAutoExportEnabled = false,
  });

  /// Значения по умолчанию
  factory AppSettings.defaults() {
    return AppSettings(
      pharmacyName: 'Аптека Хушдил',
      language: 'ru',
      themeMode: 'light',
      primaryColor: '#1976D2',
      discountRules: const [],
      bonusAccrualPercent: 5.0,
      bankName: 'Душанбе Сити Банк',
      bankLogoPath: null,
      bankQrCodePath: null,
      bankPhoneNumber: null,
      telegramBotToken: null,
      telegramChatId: null,
      telegramAutoExportEnabled: false,
    );
  }

  /// Создать из Map
  factory AppSettings.fromMap(Map<String, String> map) {
    final rawDiscounts = map['discount_rules'];
    final parsedRules = <DiscountRule>[];
    if (rawDiscounts != null && rawDiscounts.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawDiscounts);
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            parsedRules.add(DiscountRule.fromJson(item));
          } else if (item is Map) {
            parsedRules
                .add(DiscountRule.fromJson(item.map((key, value) => MapEntry(key.toString(), value))));
          }
        }
      } catch (_) {
        // Игнорируем ошибки парсинга и используем пустой список
      }
    }
    final bonusPercentString = map['bonus_accrual_percent'];
    final bonusPercent = bonusPercentString != null
        ? double.tryParse(bonusPercentString) ?? 5.0
        : 5.0;

    return AppSettings(
      pharmacyName: map['pharmacy_name'] ?? 'Аптека Хушдил',
      language: map['language'] ?? 'ru',
      themeMode: map['theme_mode'] ?? 'light',
      primaryColor: map['primary_color'] ?? '#1976D2',
      discountRules: parsedRules,
      bonusAccrualPercent: bonusPercent,
      bankName: map['bank_name'],
      bankLogoPath: map['bank_logo_path'],
      bankQrCodePath: map['bank_qr_code_path'],
      bankPhoneNumber: map['bank_phone_number'],
      telegramBotToken: map['telegram_bot_token'],
      telegramChatId: map['telegram_chat_id'],
      telegramAutoExportEnabled:
          (map['telegram_auto_export_enabled'] ?? 'false').toLowerCase() ==
              'true',
    );
  }

  /// Преобразовать в Map
  Map<String, String> toMap() {
    final map = <String, String>{
      'pharmacy_name': pharmacyName,
      'language': language,
      'theme_mode': themeMode,
      'primary_color': primaryColor,
      'discount_rules': jsonEncode(
        discountRules.map((rule) => rule.toJson()).toList(),
      ),
      'bonus_accrual_percent': bonusAccrualPercent.toString(),
    };
    if (bankName != null && bankName!.isNotEmpty) {
      map['bank_name'] = bankName!;
    }
    if (bankLogoPath != null && bankLogoPath!.isNotEmpty) {
      map['bank_logo_path'] = bankLogoPath!;
    }
    if (bankQrCodePath != null && bankQrCodePath!.isNotEmpty) {
      map['bank_qr_code_path'] = bankQrCodePath!;
    }
    if (bankPhoneNumber != null && bankPhoneNumber!.isNotEmpty) {
      map['bank_phone_number'] = bankPhoneNumber!;
    }
    if (telegramBotToken != null && telegramBotToken!.isNotEmpty) {
      map['telegram_bot_token'] = telegramBotToken!;
    }
    if (telegramChatId != null && telegramChatId!.isNotEmpty) {
      map['telegram_chat_id'] = telegramChatId!;
    }
    map['telegram_auto_export_enabled'] =
        telegramAutoExportEnabled ? 'true' : 'false';
    return map;
  }

  /// Копировать с изменениями
  AppSettings copyWith({
    String? pharmacyName,
    String? language,
    String? themeMode,
    String? primaryColor,
    List<DiscountRule>? discountRules,
    double? bonusAccrualPercent,
    String? bankName,
    String? bankLogoPath,
    String? bankQrCodePath,
    String? bankPhoneNumber,
    String? telegramBotToken,
    String? telegramChatId,
    bool? telegramAutoExportEnabled,
  }) {
    return AppSettings(
      pharmacyName: pharmacyName ?? this.pharmacyName,
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      primaryColor: primaryColor ?? this.primaryColor,
      discountRules: discountRules ?? this.discountRules,
      bonusAccrualPercent: bonusAccrualPercent ?? this.bonusAccrualPercent,
      bankName: bankName ?? this.bankName,
      bankLogoPath: bankLogoPath ?? this.bankLogoPath,
      bankQrCodePath: bankQrCodePath ?? this.bankQrCodePath,
      bankPhoneNumber: bankPhoneNumber ?? this.bankPhoneNumber,
      telegramBotToken: telegramBotToken ?? this.telegramBotToken,
      telegramChatId: telegramChatId ?? this.telegramChatId,
      telegramAutoExportEnabled:
          telegramAutoExportEnabled ?? this.telegramAutoExportEnabled,
    );
  }
}

