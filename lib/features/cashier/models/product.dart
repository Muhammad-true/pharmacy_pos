class Product {
  final int id;
  final String name;
  final String barcode;
  final String? qrCode; // QR-код товара
  final double price;
  final int stock;
  final String unit;
  final int unitsPerPackage; // Количество единиц в упаковке (например, 20 таблеток)
  final String unitName; // Название единицы (например, "таблетка")
  final int? manufacturerId; // ID производителя
  final String? composition; // Состав лекарства
  final String? indications; // Показания к применению
  final String? preparationMethod; // Способ приготовления/применения
  final bool requiresPrescription; // Требуется ли рецепт врача
  final String? inventoryCode; // Инвентарный код / код товара
  final String? organization; // Склад / организация хранения
  final String? shelfLocation; // Полка / расположение

  Product({
    required this.id,
    required this.name,
    required this.barcode,
    this.qrCode,
    required this.price,
    required this.stock,
    required this.unit,
    this.unitsPerPackage = 1, // По умолчанию 1 единица = 1 упаковка
    this.unitName = 'шт', // По умолчанию "шт"
    this.manufacturerId,
    this.composition,
    this.indications,
    this.preparationMethod,
    this.requiresPrescription = false, // По умолчанию рецепт не требуется
    this.inventoryCode,
    this.organization,
    this.shelfLocation,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      barcode: json['barcode'] as String,
      qrCode: json['qrCode'] as String?,
      price: (json['price'] as num).toDouble(),
      stock: json['stock'] as int,
      unit: json['unit'] as String,
      unitsPerPackage: json['unitsPerPackage'] as int? ?? 1,
      unitName: json['unitName'] as String? ?? 'шт',
      manufacturerId: json['manufacturerId'] as int?,
      composition: json['composition'] as String?,
      indications: json['indications'] as String?,
      preparationMethod: json['preparationMethod'] as String?,
      requiresPrescription: json['requiresPrescription'] as bool? ?? false,
      inventoryCode: json['inventoryCode'] as String?,
      organization: json['organization'] as String?,
      shelfLocation: json['shelfLocation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'qrCode': qrCode,
      'price': price,
      'stock': stock,
      'unit': unit,
      'unitsPerPackage': unitsPerPackage,
      'unitName': unitName,
      'manufacturerId': manufacturerId,
      'composition': composition,
      'indications': indications,
      'preparationMethod': preparationMethod,
      'requiresPrescription': requiresPrescription,
      'inventoryCode': inventoryCode,
      'organization': organization,
      'shelfLocation': shelfLocation,
    };
  }

  // Цена за одну единицу (таблетку)
  double get pricePerUnit => price / unitsPerPackage;
}
