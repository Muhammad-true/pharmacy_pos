import 'package:drift/drift.dart' show Value;
import '../../features/cashier/models/product.dart';
import '../database/database_provider.dart';
import '../database/database.dart' as db;
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import 'i_product_repository.dart';
import 'mappers/database_mappers.dart';

/// Реализация репозитория для работы с товарами
class ProductRepository implements IProductRepository {
  final ErrorHandler _errorHandler = ErrorHandler.instance;

  /// Получить БД
  Future<db.AppDatabase> get _database async => await DatabaseProvider.getDatabase();

  @override
  Future<List<Product>> getAllProducts() async {
    try {
      final database = await _database;
      final dbProducts = await database.productsDao.getAllProducts();
      return dbProducts.map(DatabaseMappers.toAppProduct).toList();
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения товаров: ${e.toString()}');
    }
  }

  @override
  Future<Product?> getProductById(int id) async {
    try {
      final database = await _database;
      final dbProduct = await database.productsDao.getProductById(id);
      if (dbProduct == null) return null;
      return DatabaseMappers.toAppProduct(dbProduct);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения товара: ${e.toString()}');
    }
  }

  @override
  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      final database = await _database;
      final dbProduct = await database.productsDao.getProductByBarcode(barcode);
      if (dbProduct == null) return null;
      return DatabaseMappers.toAppProduct(dbProduct);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка поиска товара по штрихкоду: ${e.toString()}');
    }
  }

  /// Получить товар по QR-коду
  Future<Product?> getProductByQrCode(String qrCode) async {
    try {
      final database = await _database;
      final dbProduct = await database.productsDao.getProductByQrCode(qrCode);
      if (dbProduct == null) return null;
      return DatabaseMappers.toAppProduct(dbProduct);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка поиска товара по QR-коду: ${e.toString()}');
    }
  }

  @override
  Future<List<Product>> searchProducts(String query) async {
    try {
      if (query.isEmpty) return [];
      
      final database = await _database;
      final dbProducts = await database.productsDao.searchProductsByNameOrBarcode(query);
      return dbProducts.map(DatabaseMappers.toAppProduct).toList();
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка поиска товаров: ${e.toString()}');
    }
  }

  @override
  Future<Product> createProduct(Product product, {int? userId}) async {
    try {
      final database = await _database;
      
      // Обрезание баркода и QR-кода выполняется в маппере
      final dbProduct = DatabaseMappers.toDbProduct(product);
      final id = await database.productsDao.insertProduct(dbProduct);
      
      // Создаем запись в истории движения, если товар создается с остатком
      if (product.stock > 0) {
        try {
          await database.stockMovementsDao.insertMovement(
            db.StockMovementsCompanion.insert(
              productId: id,
              movementType: 'in',
              quantity: product.stock,
              stockBefore: 0,
              stockAfter: product.stock,
              notes: Value('Первоначальное поступление товара'),
              userId: userId != null ? Value(userId) : const Value.absent(),
            ),
          );
        } catch (e) {
          // Логируем ошибку, но не прерываем операцию
          _errorHandler.warning('Ошибка записи в историю движения при создании товара: $e');
        }
      }
      
      // Создаем новый продукт с полученным ID и всеми полями
      return Product(
        id: id,
        name: product.name,
        barcode: product.barcode,
        qrCode: product.qrCode,
        price: product.price,
        stock: product.stock,
        unit: product.unit,
        unitsPerPackage: product.unitsPerPackage,
        unitName: product.unitName,
        manufacturerId: product.manufacturerId,
        composition: product.composition,
        indications: product.indications,
        preparationMethod: product.preparationMethod,
        requiresPrescription: product.requiresPrescription,
        inventoryCode: product.inventoryCode,
        organization: product.organization,
        shelfLocation: product.shelfLocation,
      );
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка создания товара: ${e.toString()}');
    }
  }

  @override
  Future<Product> updateProduct(Product product) async {
    try {
      final database = await _database;
      // Проверяем, существует ли товар
      final existing = await database.productsDao.getProductById(product.id);
      if (existing == null) {
        throw DatabaseException('Товар не найден');
      }
      
      // Создаем обновленную версию с текущим временем
      final updatedDbProduct = db.Product(
        id: product.id,
        name: product.name,
        barcode: product.barcode,
        qrCode: product.qrCode,
        price: product.price,
        stock: product.stock,
        unit: product.unit,
        unitsPerPackage: product.unitsPerPackage,
        unitName: product.unitName,
        manufacturerId: product.manufacturerId,
        composition: product.composition,
        indications: product.indications,
        preparationMethod: product.preparationMethod,
        requiresPrescription: product.requiresPrescription,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        inventoryCode: product.inventoryCode,
        organization: product.organization,
        shelfLocation: product.shelfLocation,
      );
      
      final updated = await database.productsDao.updateProduct(updatedDbProduct);
      if (!updated) {
        throw DatabaseException('Не удалось обновить товар');
      }
      return product;
    } catch (e) {
      _errorHandler.handleError(e);
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Ошибка обновления товара: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteProduct(int id) async {
    try {
      final database = await _database;
      await database.productsDao.deleteProduct(id);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка удаления товара: ${e.toString()}');
    }
  }

  @override
  Future<void> updateStock(int id, int newStock, {String? movementType, String? notes, int? userId, int? receiptId}) async {
    try {
      final database = await _database;
      
      // Получаем текущий остаток товара
      final currentProduct = await database.productsDao.getProductById(id);
      if (currentProduct == null) {
        throw DatabaseException('Товар не найден');
      }
      
      final stockBefore = currentProduct.stock;
      final stockAfter = newStock;
      final quantity = (stockAfter - stockBefore).abs();
      
      // Обновляем остаток
      final updated = await database.productsDao.updateProductStock(id, newStock);
      if (!updated) {
        throw DatabaseException('Не удалось обновить остаток товара');
      }
      
      // Создаем запись в истории движения, если остаток изменился
      if (stockBefore != stockAfter && movementType != null) {
        try {
          await database.stockMovementsDao.insertMovement(
            db.StockMovementsCompanion.insert(
              productId: id,
              movementType: movementType,
              quantity: quantity,
              stockBefore: stockBefore,
              stockAfter: stockAfter,
              notes: notes != null ? Value(notes) : const Value.absent(),
              userId: userId != null ? Value(userId) : const Value.absent(),
              receiptId: receiptId != null ? Value(receiptId) : const Value.absent(),
            ),
          );
        } catch (e) {
          // Логируем ошибку, но не прерываем операцию
          _errorHandler.warning('Ошибка записи в историю движения: $e');
        }
      }
    } catch (e) {
      _errorHandler.handleError(e);
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Ошибка обновления остатка: ${e.toString()}');
    }
  }

  @override
  Future<bool> decreaseStock(int id, int quantity) async {
    try {
      final database = await _database;
      return await database.productsDao.decreaseProductStock(id, quantity);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка уменьшения остатка: ${e.toString()}');
    }
  }

  @override
  Future<void> increaseStock(int id, int quantity) async {
    try {
      final database = await _database;
      final updated = await database.productsDao.increaseProductStock(id, quantity);
      if (!updated) {
        throw DatabaseException('Не удалось увеличить остаток товара');
      }
    } catch (e) {
      _errorHandler.handleError(e);
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Ошибка увеличения остатка: ${e.toString()}');
    }
  }

  @override
  Future<List<Product>> getProductsWithLowStock(int threshold) async {
    try {
      final database = await _database;
      final dbProducts = await database.productsDao.getProductsWithLowStock(threshold);
      return dbProducts.map(DatabaseMappers.toAppProduct).toList();
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения товаров с низким остатком: ${e.toString()}');
    }
  }

  @override
  Future<List<Product>> getOutOfStockProducts() async {
    try {
      final database = await _database;
      final dbProducts = await database.productsDao.getOutOfStockProducts();
      return dbProducts.map(DatabaseMappers.toAppProduct).toList();
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения товаров без остатка: ${e.toString()}');
    }
  }
}


