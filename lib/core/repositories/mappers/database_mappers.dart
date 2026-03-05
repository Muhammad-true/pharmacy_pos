import 'package:drift/drift.dart' show Value;
import '../../../features/cashier/models/product.dart' as app;
import '../../../features/shared/models/client.dart' as app;
import '../../../features/shared/models/manufacturer.dart' as app;
import '../../../features/shared/models/advertisement.dart' as app;
import '../../../features/auth/models/user.dart' as app;
import '../../../features/cashier/models/receipt.dart' as app;
import '../../../features/cashier/models/receipt_item.dart' as app;
import '../../../features/shared/models/receipt_history.dart';
import '../../database/database.dart' as db;

/// Мапперы для преобразования моделей БД в модели приложения

class DatabaseMappers {
  /// Преобразовать Product (БД) в Product (приложение)
  static app.Product toAppProduct(db.Product dbProduct) {
    return app.Product(
      id: dbProduct.id,
      name: dbProduct.name,
      barcode: dbProduct.barcode,
      qrCode: dbProduct.qrCode,
      price: dbProduct.price,
      stock: dbProduct.stock,
      unit: dbProduct.unit,
      unitsPerPackage: dbProduct.unitsPerPackage,
      unitName: dbProduct.unitName,
      manufacturerId: dbProduct.manufacturerId,
      composition: dbProduct.composition,
      indications: dbProduct.indications,
      preparationMethod: dbProduct.preparationMethod,
      requiresPrescription: dbProduct.requiresPrescription,
      inventoryCode: dbProduct.inventoryCode,
      organization: dbProduct.organization,
      shelfLocation: dbProduct.shelfLocation,
    );
  }

  /// Преобразовать Product (приложение) в ProductsCompanion (БД)
  static db.ProductsCompanion toDbProduct(app.Product product, {bool isUpdate = false}) {
    // Обрезаем баркод до 255 символов, если он длиннее
    final barcode = product.barcode.length > 255 
        ? product.barcode.substring(0, 255) 
        : product.barcode;
    
    // Обрезаем QR-код до 255 символов, если он длиннее
    final qrCode = product.qrCode != null && product.qrCode!.length > 255
        ? product.qrCode!.substring(0, 255)
        : product.qrCode;
    
    if (isUpdate) {
      return db.ProductsCompanion(
        id: Value(product.id),
        name: Value(product.name),
        barcode: Value(barcode),
        qrCode: Value(qrCode),
        price: Value(product.price),
        stock: Value(product.stock),
        unit: Value(product.unit),
        unitsPerPackage: Value(product.unitsPerPackage),
        unitName: Value(product.unitName),
        manufacturerId: Value(product.manufacturerId),
        composition: Value(product.composition),
        indications: Value(product.indications),
        preparationMethod: Value(product.preparationMethod),
        requiresPrescription: Value(product.requiresPrescription),
        inventoryCode: Value(product.inventoryCode),
        organization: Value(product.organization),
        shelfLocation: Value(product.shelfLocation),
      );
    }
    // Для создания используем обычный конструктор с Value
    return db.ProductsCompanion(
      name: Value(product.name),
      barcode: Value(barcode),
      qrCode: Value(qrCode),
      price: Value(product.price),
      stock: Value(product.stock),
      unit: Value(product.unit),
      unitsPerPackage: Value(product.unitsPerPackage),
      unitName: Value(product.unitName),
      manufacturerId: Value(product.manufacturerId),
      composition: Value(product.composition),
      indications: Value(product.indications),
      preparationMethod: Value(product.preparationMethod),
      requiresPrescription: Value(product.requiresPrescription),
      inventoryCode: Value(product.inventoryCode),
      organization: Value(product.organization),
      shelfLocation: Value(product.shelfLocation),
    );
  }

  /// Преобразовать Client (БД) в Client (приложение)
  static app.Client toAppClient(db.Client dbClient, {String? createdByUserName}) {
    return app.Client(
      id: dbClient.id,
      name: dbClient.name,
      phone: dbClient.phone,
      qrCode: dbClient.qrCode,
      bonuses: dbClient.bonuses,
      discountPercent: 0.0,
      createdByUserId: dbClient.createdByUserId,
      createdByUserName: createdByUserName,
      createdAt: dbClient.createdAt,
      updatedAt: dbClient.updatedAt,
    );
  }

  /// Преобразовать Client (приложение) в ClientsCompanion (БД)
  static db.ClientsCompanion toDbClient(app.Client client, {bool isUpdate = false}) {
    if (isUpdate) {
      return db.ClientsCompanion(
        id: Value(client.id),
        name: Value(client.name),
        phone: Value(client.phone),
        qrCode: Value(client.qrCode),
        bonuses: Value(client.bonuses),
        discountPercent: const Value(0.0),
        createdByUserId: Value(client.createdByUserId),
      );
    }
    return db.ClientsCompanion.insert(
      name: client.name,
      phone: Value(client.phone),
      qrCode: Value(client.qrCode),
      bonuses: Value(client.bonuses),
      discountPercent: const Value(0.0),
      createdByUserId: Value(client.createdByUserId),
    );
  }

  /// Преобразовать Manufacturer (БД) в Manufacturer (приложение)
  static app.Manufacturer toAppManufacturer(db.Manufacturer dbManufacturer) {
    return app.Manufacturer(
      id: dbManufacturer.id,
      name: dbManufacturer.name,
      country: dbManufacturer.country,
      address: dbManufacturer.address,
      phone: dbManufacturer.phone,
      email: dbManufacturer.email,
    );
  }

  /// Преобразовать Manufacturer (приложение) в ManufacturersCompanion (БД)
  static db.ManufacturersCompanion toDbManufacturer(app.Manufacturer manufacturer, {bool isUpdate = false}) {
    if (isUpdate) {
      return db.ManufacturersCompanion(
        id: Value(manufacturer.id),
        name: Value(manufacturer.name),
        country: Value(manufacturer.country),
        address: Value(manufacturer.address),
        phone: Value(manufacturer.phone),
        email: Value(manufacturer.email),
      );
    }
    return db.ManufacturersCompanion.insert(
      name: manufacturer.name,
      country: Value(manufacturer.country),
      address: Value(manufacturer.address),
      phone: Value(manufacturer.phone),
      email: Value(manufacturer.email),
    );
  }

  /// Преобразовать User (БД) в User (приложение)
  static app.User toAppUser(db.User dbUser) {
    return app.User(
      id: dbUser.id,
      username: dbUser.username,
      name: dbUser.name,
      role: dbUser.role,
      token: null, // Токен не хранится в БД
    );
  }

  /// Преобразовать User (приложение) в UsersCompanion (БД)
  static db.UsersCompanion toDbUser(
    app.User user, {
    bool isUpdate = false,
    String? passwordHash,
  }) {
    if (isUpdate) {
      return db.UsersCompanion(
        id: Value(user.id),
        username: Value(user.username),
        name: Value(user.name),
        role: Value(user.role),
        passwordHash: passwordHash != null ? Value(passwordHash) : const Value.absent(),
      );
    }
    return db.UsersCompanion.insert(
      username: user.username,
      name: user.name,
      role: user.role,
      passwordHash: passwordHash != null ? Value(passwordHash) : const Value.absent(),
    );
  }

  /// Преобразовать Receipt (приложение) в ReceiptsCompanion (БД)
  static db.ReceiptsCompanion toDbReceipt(
    app.Receipt receipt,
    String receiptNumber, {
    int? userId,
  }) {
    // Используем обычный конструктор с Value для всех полей
    // Важно: createdAt НЕ указываем явно - будет использоваться текущая дата и время из БД (default)
    // Это гарантирует, что дата будет правильной (локальное время сервера БД)
    return db.ReceiptsCompanion(
      receiptNumber: Value(receiptNumber),
      clientId: Value(receipt.clientId),
      subtotal: Value(receipt.subtotal),
      discount: Value(receipt.totalDiscount),
      discountPercent: Value(receipt.discountIsPercent ? receipt.discountPercent : 0.0),
      discountIsPercent: Value(receipt.discountIsPercent),
      bonuses: Value(receipt.bonuses),
      total: Value(receipt.total),
      received: Value(receipt.received),
      change: Value(receipt.change),
      paymentMethod: Value('cash'),
      userId: Value(userId),
      // createdAt не указываем - будет использоваться DEFAULT CURRENT_TIMESTAMP из БД
      // Это гарантирует правильную дату создания чека
    );
  }

  /// Преобразовать ReceiptItem (приложение) в ReceiptItemsCompanion (БД)
  static db.ReceiptItemsCompanion toDbReceiptItem(
    app.ReceiptItem item,
    int receiptId,
  ) {
    return db.ReceiptItemsCompanion.insert(
      receiptId: receiptId,
      productId: item.product.id,
      quantity: item.quantity,
      price: item.price,
      unitsInPackage: item.unitsInPackage,
      index: item.index,
    );
  }

  /// Преобразовать Receipt (БД) в ReceiptHistory (приложение)
  /// Требует загрузки позиций чека и товаров отдельно
  /// userName - имя кассира (опционально, если userId указан)
  static ReceiptHistory toReceiptHistory(
    db.Receipt dbReceipt,
    List<(db.ReceiptItem, db.Product)> itemsWithProducts, {
    String? userName,
  }) {
    final items = itemsWithProducts.map((pair) {
      final dbItem = pair.$1;
      final dbProduct = pair.$2;
      
      // Вычисляем total для позиции
      final pricePerUnit = dbItem.price / dbItem.unitsInPackage;
      final total = dbItem.quantity * pricePerUnit;
      
      return ReceiptHistoryItem(
        productId: dbProduct.id,
        productName: dbProduct.name,
        quantity: dbItem.quantity,
        price: dbItem.price,
        total: total,
      );
    }).toList();

    // Drift хранит DateTime в UTC, но флаг isUtc может быть потерян
    // Поэтому принудительно воспринимаем значение как UTC и конвертируем в локальное время
    return ReceiptHistory(
      id: dbReceipt.id,
      receiptNumber: dbReceipt.receiptNumber,
      items: items,
      subtotal: dbReceipt.subtotal,
      discount: dbReceipt.discount,
      discountPercent: dbReceipt.discountPercent,
      bonuses: dbReceipt.bonuses,
      total: dbReceipt.total,
      createdAt: dbReceipt.createdAt,
      paymentMethod: dbReceipt.paymentMethod,
      userId: dbReceipt.userId,
      userName: userName,
    );
  }

  /// Преобразовать Advertisement (БД) в Advertisement (приложение)
  static app.Advertisement toAppAdvertisement(db.Advertisement dbAdvertisement) {
    return app.Advertisement(
      id: dbAdvertisement.id,
      title: dbAdvertisement.title,
      description: dbAdvertisement.description,
      mediaUrl: dbAdvertisement.mediaUrl,
      mediaType: dbAdvertisement.mediaType,
      discountText: dbAdvertisement.discountText,
      qrCode: dbAdvertisement.qrCode,
      qrCodeText: dbAdvertisement.qrCodeText,
      isActive: dbAdvertisement.isActive,
      displayOrder: dbAdvertisement.displayOrder,
      createdByUserId: dbAdvertisement.createdByUserId,
      targetUserId: dbAdvertisement.targetUserId,
      createdAt: dbAdvertisement.createdAt,
      updatedAt: dbAdvertisement.updatedAt,
    );
  }

  /// Преобразовать Advertisement (приложение) в AdvertisementsCompanion (БД)
  static db.AdvertisementsCompanion toDbAdvertisement(
    app.Advertisement advertisement, {
    bool isUpdate = false,
  }) {
    if (isUpdate) {
      return db.AdvertisementsCompanion(
        id: Value(advertisement.id),
        title: Value(advertisement.title),
        description: Value(advertisement.description),
        mediaUrl: Value(advertisement.mediaUrl),
        mediaType: Value(advertisement.mediaType),
        discountText: Value(advertisement.discountText),
        qrCode: Value(advertisement.qrCode),
        qrCodeText: Value(advertisement.qrCodeText),
        isActive: Value(advertisement.isActive),
        displayOrder: Value(advertisement.displayOrder),
        createdByUserId: Value(advertisement.createdByUserId),
        targetUserId: Value(advertisement.targetUserId),
        updatedAt: Value(DateTime.now()),
      );
    }
    return db.AdvertisementsCompanion.insert(
      title: advertisement.title,
      description: Value(advertisement.description),
      mediaUrl: Value(advertisement.mediaUrl),
      mediaType: Value(advertisement.mediaType),
      discountText: Value(advertisement.discountText),
      qrCode: Value(advertisement.qrCode),
      qrCodeText: Value(advertisement.qrCodeText),
      isActive: Value(advertisement.isActive),
      displayOrder: Value(advertisement.displayOrder),
      createdByUserId: Value(advertisement.createdByUserId),
      targetUserId: Value(advertisement.targetUserId),
    );
  }
}

