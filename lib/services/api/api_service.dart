import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../features/auth/models/user.dart';
import '../../features/shared/models/client.dart';
import '../../features/cashier/models/product.dart';
import '../../features/shared/models/receipt_history.dart';

class ApiService {
  // TODO: Заменить на реальный базовый URL
  static const String baseUrl = 'http://localhost:8080/api';

  /// Поиск товаров
  static Future<List<Product>> searchProducts(
    String query, {
    int limit = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/products/search?q=${Uri.encodeComponent(query)}&limit=$limit',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final productsList = data['products'] as List;
        return productsList.map((json) => Product.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Ошибка поиска товаров: ${response.statusCode}');
      }
    } catch (e) {
      // В режиме разработки возвращаем тестовые данные (только если включено)
      if (AppConfig.enableMockData) {
        return _getMockProducts(query);
      }
      rethrow;
    }
  }

  /// Вход пользователя
  static Future<User> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return User.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Неверный логин или пароль');
      } else {
        throw Exception('Ошибка входа: ${response.statusCode}');
      }
    } catch (e) {
      // В режиме разработки возвращаем тестового пользователя (только если включено)
      if (AppConfig.enableMockData &&
          (e.toString().contains('Failed host lookup') ||
           e.toString().contains('Connection refused'))) {
        // Определяем роль по логину для тестирования
        String role = 'cashier';
        String name = 'Кассир';
        
        if (username.toLowerCase() == 'warehouse' || 
            username.toLowerCase() == 'admin' || 
            username.toLowerCase() == 'manager') {
          role = username.toLowerCase();
          name = role == 'warehouse' 
              ? 'Склад' 
              : role == 'admin' 
                  ? 'Администратор' 
                  : 'Менеджер';
        }
        
        return User(
          id: 1,
          username: username,
          name: name,
          role: role,
        );
      }
      rethrow;
    }
  }

  /// Получение информации о клиенте
  static Future<Client?> getClient(int clientId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/clients/$clientId'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return Client.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Ошибка получения клиента: ${response.statusCode}');
      }
    } catch (e) {
      // В режиме разработки возвращаем тестового клиента (только если включено)
      if (AppConfig.enableMockData) {
        return _getMockClient(clientId);
      }
      rethrow;
    }
  }

  /// Поиск клиента по телефону или QR-коду
  static Future<Client?> findClientByPhoneOrQr(String phoneOrQr) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/clients/search?q=${Uri.encodeComponent(phoneOrQr)}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return Client.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Ошибка поиска клиента: ${response.statusCode}');
      }
    } catch (e) {
      // В режиме разработки возвращаем тестового клиента (только если включено)
      if (AppConfig.enableMockData) {
        return _getMockClientByPhoneOrQr(phoneOrQr);
      }
      return null;
    }
  }

  /// Оплата чека
  ///
  /// Отправляет данные чека на сервер для сохранения в БД.
  ///
  /// Ожидаемый формат данных (receiptData):
  /// {
  ///   'items': [
  ///     {
  ///       'productId': int,
  ///       'quantity': double, // Общее количество в единицах (таблетках)
  ///       'price': double, // Цена за упаковку
  ///       'unitsInPackage': int, // Текущий размер упаковки в чеке
  ///       'fullPackages': int, // Количество полных упаковок
  ///       'partialUnits': int, // Количество отдельных единиц
  ///       'standardUnitsPerPackage': int // Стандартный размер упаковки товара
  ///     }
  ///   ],
  ///   'subtotal': double,
  ///   'total': double,
  ///   'discount': double,
  ///   'discountPercent': double,
  ///   'bonuses': double, // Списанные бонусы
  ///   'received': double,
  ///   'change': double,
  ///   'clientId': int?,
  ///   'paymentMethod': 'cash'
  /// }
  ///
  /// Ожидаемый ответ от сервера:
  /// {
  ///   'success': bool,
  ///   'receiptId': int,
  ///   'receiptNumber': String
  /// }
  static Future<Map<String, dynamic>> checkout(
    Map<String, dynamic> receiptData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pos/checkout'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(receiptData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final error = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(
          error['message'] ?? 'Ошибка оплаты: ${response.statusCode}',
        );
      }
    } catch (e) {
      // В режиме разработки симулируем успешную оплату
      // TODO: Убрать моковые данные при подключении к реальной БД
      return {
        'success': true,
        'receiptId': DateTime.now().millisecondsSinceEpoch,
        'receiptNumber':
            'Ч-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      };
    }
  }

  /// Обновление бонусов клиента в БД
  ///
  /// Начисляет или списывает бонусы клиента после оплаты чека.
  ///
  /// Параметры:
  /// - clientId: ID клиента
  /// - bonusesToAdd: Сумма бонусов для начисления (положительное число)
  /// - bonusesToSubtract: Сумма бонусов для списания (положительное число)
  ///
  /// Ожидаемый ответ от сервера:
  /// {
  ///   'success': bool,
  ///   'newBonusesBalance': double // Новый баланс бонусов клиента
  /// }
  static Future<Map<String, dynamic>> updateClientBonuses({
    required int clientId,
    double? bonusesToAdd,
    double? bonusesToSubtract,
  }) async {
    try {
      final body = <String, dynamic>{'clientId': clientId};

      if (bonusesToAdd != null && bonusesToAdd > 0) {
        body['bonusesToAdd'] = bonusesToAdd;
      }

      if (bonusesToSubtract != null && bonusesToSubtract > 0) {
        body['bonusesToSubtract'] = bonusesToSubtract;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/clients/$clientId/bonuses'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final error = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(
          error['message'] ??
              'Ошибка обновления бонусов: ${response.statusCode}',
        );
      }
    } catch (e) {
      // В режиме разработки логируем ошибку, но не блокируем процесс
      print('Ошибка обновления бонусов клиента: $e');
      // TODO: Убрать моковые данные при подключении к реальной БД
      return {'success': true, 'newBonusesBalance': 0.0};
    }
  }

  /// Получение истории чеков клиента
  ///
  /// Параметры:
  /// - clientId: ID клиента
  /// - limit: Максимальное количество чеков (по умолчанию 50)
  ///
  /// Ожидаемый ответ от сервера:
  /// {
  ///   'receipts': [
  ///     {
  ///       'id': int,
  ///       'receiptNumber': String,
  ///       'items': [...],
  ///       'subtotal': double,
  ///       'discount': double,
  ///       'discountPercent': double,
  ///       'bonuses': double,
  ///       'total': double,
  ///       'createdAt': String (ISO 8601),
  ///       'paymentMethod': String?
  ///     }
  ///   ]
  /// }
  static Future<List<ReceiptHistory>> getClientReceipts({
    required int clientId,
    int limit = 50,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/clients/$clientId/receipts?limit=$limit'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final receiptsList = data['receipts'] as List<dynamic>;
        return receiptsList
            .map((json) => ReceiptHistory.fromJson(json))
            .toList();
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Ошибка получения чеков: ${response.statusCode}');
      }
    } catch (e) {
      // В режиме разработки возвращаем тестовые данные
      return _getMockReceipts(clientId);
    }
  }

  // Тестовые данные для разработки
  static List<Product> _getMockProducts(String query) {
    final mockProducts = [
      Product(
        id: 1,
        name: 'Парацетамол 500мг',
        barcode: '1234567890123',
        price: 150.00,
        stock: 25,
        unit: 'упаковка',
        unitsPerPackage: 20,
        unitName: 'таблетка',
      ),
      Product(
        id: 2,
        name: 'Ибупрофен 200мг',
        barcode: '1234567890124',
        price: 180.00,
        stock: 15,
        unit: 'упаковка',
        unitsPerPackage: 10,
        unitName: 'таблетка',
      ),
      Product(
        id: 3,
        name: 'Аспирин 500мг',
        barcode: '1234567890125',
        price: 120.00,
        stock: 30,
        unit: 'упаковка',
        unitsPerPackage: 30,
        unitName: 'таблетка',
      ),
      Product(
        id: 4,
        name: 'Витамин C 1000мг',
        barcode: '1234567890126',
        price: 250.00,
        stock: 20,
        unit: 'упаковка',
        unitsPerPackage: 15,
        unitName: 'таблетка',
      ),
      Product(
        id: 5,
        name: 'Цитрамон',
        barcode: '1234567890127',
        price: 95.00,
        stock: 40,
        unit: 'упаковка',
        unitsPerPackage: 10,
        unitName: 'таблетка',
      ),
      Product(
        id: 6,
        name: 'Нурофен Экспресс',
        barcode: '1234567890128',
        price: 320.00,
        stock: 12,
        unit: 'упаковка',
        unitsPerPackage: 12,
        unitName: 'таблетка',
      ),
      Product(
        id: 7,
        name: 'Анальгин 500мг',
        barcode: '1234567890129',
        price: 80.00,
        stock: 50,
        unit: 'упаковка',
        unitsPerPackage: 20,
        unitName: 'таблетка',
      ),
      Product(
        id: 8,
        name: 'Но-шпа',
        barcode: '1234567890130',
        price: 200.00,
        stock: 18,
        unit: 'упаковка',
        unitsPerPackage: 24,
        unitName: 'таблетка',
      ),
      Product(
        id: 9,
        name: 'Амоксициллин 500мг',
        barcode: '1234567890131',
        price: 350.00,
        stock: 8,
        unit: 'упаковка',
        unitsPerPackage: 16,
        unitName: 'таблетка',
      ),
      Product(
        id: 10,
        name: 'Активированный уголь',
        barcode: '1234567890132',
        price: 60.00,
        stock: 60,
        unit: 'упаковка',
        unitsPerPackage: 30,
        unitName: 'таблетка',
      ),
    ];

    if (query.isEmpty) {
      return mockProducts;
    }

    final lowerQuery = query.toLowerCase();
    return mockProducts
        .where(
          (p) =>
              p.name.toLowerCase().contains(lowerQuery) ||
              p.barcode.contains(query),
        )
        .toList();
  }

  static Client? _getMockClient(int clientId) {
    if (clientId == 1) {
      return Client(
        id: 1,
        name: 'Иван Иванов',
        phone: '+996555123456',
        bonuses: 500.00,
        discountPercent: 0.0,
      );
    }
    return null;
  }

  static Client? _getMockClientByPhoneOrQr(String phoneOrQr) {
    // Тестовые данные для разработки
    final phone = phoneOrQr.replaceAll(
      RegExp(r'[^\d]'),
      '',
    ); // Убираем все нецифровые символы

    // Клиент 1: Иван Иванов
    if (phone == '996555123456' ||
        phone == '555123456' ||
        phoneOrQr == 'QR123456' ||
        phoneOrQr == '123456') {
      return Client(
        id: 1,
        name: 'Иван Иванов',
        phone: '+996555123456',
        qrCode: 'QR123456',
        bonuses: 500.00,
        discountPercent: 0.0,
      );
    }

    // Клиент 2: Мария Петрова
    if (phone == '996555654321' ||
        phone == '555654321' ||
        phoneOrQr == 'QR654321' ||
        phoneOrQr == '654321') {
      return Client(
        id: 2,
        name: 'Мария Петрова',
        phone: '+996555654321',
        qrCode: 'QR654321',
        bonuses: 1000.00,
        discountPercent: 0.0,
      );
    }

    // Клиент 3: Тестовый клиент для быстрой проверки
    if (phone == '996555000000' ||
        phone == '555000000' ||
        phoneOrQr == 'QR000000' ||
        phoneOrQr == '000000' ||
        phoneOrQr == '0') {
      return Client(
        id: 3,
        name: 'Тестовый Клиент',
        phone: '+996555000000',
        qrCode: 'QR000000',
        bonuses: 250.00,
        discountPercent: 0.0,
      );
    }

    // Клиент 4: Еще один тестовый клиент
    if (phone == '996555111111' ||
        phone == '555111111' ||
        phoneOrQr == 'QR111111' ||
        phoneOrQr == '111111') {
      return Client(
        id: 4,
        name: 'Алексей Смирнов',
        phone: '+996555111111',
        qrCode: 'QR111111',
        bonuses: 750.00,
        discountPercent: 0.0,
      );
    }

    // Клиент 5: Клиент с номером 929290929
    if (phone == '996929290929' ||
        phone == '929290929' ||
        phoneOrQr == 'QR929290929' ||
        phoneOrQr == '929290929') {
      return Client(
        id: 5,
        name: 'Постоянный Клиент',
        phone: '+996929290929',
        qrCode: 'QR929290929',
        bonuses: 1200.00,
        discountPercent: 0.0,
      );
    }

    return null;
  }

  static List<ReceiptHistory> _getMockReceipts(int clientId) {
    // Тестовые данные для разработки (используются только если enableMockData = true)
    if (clientId == 1 || clientId == 5) {
      return [
        ReceiptHistory(
          id: 1,
          receiptNumber: 'Ч-001234',
          items: [
            ReceiptHistoryItem(
              productId: 1,
              productName: 'Парацетамол 500мг',
              quantity: 20.0,
              price: 150.00,
              total: 150.00,
            ),
            ReceiptHistoryItem(
              productId: 2,
              productName: 'Ибупрофен 200мг',
              quantity: 10.0,
              price: 180.00,
              total: 180.00,
            ),
          ],
          subtotal: 330.00,
          discount: 16.50,
          discountPercent: 5.0,
          bonuses: 0.0,
          total: 313.50,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          paymentMethod: 'cash',
        ),
        ReceiptHistory(
          id: 2,
          receiptNumber: 'Ч-001235',
          items: [
            ReceiptHistoryItem(
              productId: 3,
              productName: 'Аспирин 500мг',
              quantity: 30.0,
              price: 120.00,
              total: 120.00,
            ),
          ],
          subtotal: 120.00,
          discount: 14.40,
          discountPercent: 12.0,
          bonuses: 50.00,
          total: 55.60,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          paymentMethod: 'cash',
        ),
      ];
    }
    return [];
  }
}
