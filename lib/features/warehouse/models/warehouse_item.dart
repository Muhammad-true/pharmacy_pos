import '../../cashier/models/product.dart';

/// Модель товара на складе с информацией об остатках
class WarehouseItem {
  final Product product;
  final String manufacturer;
  final String organization;
  final String inventoryCode;
  final String shelfLocation;
  final int quantity; // Количество в упаковках
  final int totalUnits; // Общее количество единиц (таблеток)
  final double costPrice; // Себестоимость
  final double sellingPrice; // Цена продажи
  final DateTime? lastReceived; // Дата последнего поступления
  final DateTime? lastSold; // Дата последней продажи
  final DateTime? expiryDate; // Срок годности

  WarehouseItem({
    required this.product,
    required this.manufacturer,
    required this.organization,
    required this.inventoryCode,
    required this.shelfLocation,
    required this.quantity,
    required this.totalUnits,
    required this.costPrice,
    required this.sellingPrice,
    this.lastReceived,
    this.lastSold,
    this.expiryDate,
  });

  /// Проверка на низкий остаток (менее 10 упаковок)
  bool get isLowStock => quantity < 10;

  /// Проверка на отсутствие товара
  bool get isOutOfStock => quantity == 0;

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  bool get isExpiringSoon => expiryDate != null && !isExpired &&
      expiryDate!.isBefore(DateTime.now().add(const Duration(days: 30)));

  factory WarehouseItem.fromJson(Map<String, dynamic> json) {
    return WarehouseItem(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      manufacturer: json['manufacturer'] as String? ?? 'Неизвестно',
      organization: json['organization'] as String? ?? 'Основной склад',
      inventoryCode: json['inventoryCode'] as String? ?? 'INV-00000',
      shelfLocation: json['shelfLocation'] as String? ?? 'A-01',
      quantity: json['quantity'] as int? ?? 0,
      totalUnits: json['totalUnits'] as int? ?? 0,
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      lastReceived: json['lastReceived'] != null
          ? DateTime.parse(json['lastReceived'] as String)
          : null,
      lastSold: json['lastSold'] != null
          ? DateTime.parse(json['lastSold'] as String)
          : null,
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'manufacturer': manufacturer,
      'organization': organization,
      'inventoryCode': inventoryCode,
      'shelfLocation': shelfLocation,
      'quantity': quantity,
      'totalUnits': totalUnits,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'lastReceived': lastReceived?.toIso8601String(),
      'lastSold': lastSold?.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
    };
  }
}

