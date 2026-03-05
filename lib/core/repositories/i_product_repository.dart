import '../../features/cashier/models/product.dart';

/// Интерфейс репозитория для работы с товарами
abstract class IProductRepository {
  /// Получить все товары
  Future<List<Product>> getAllProducts();

  /// Получить товар по ID
  Future<Product?> getProductById(int id);

  /// Получить товар по штрихкоду
  Future<Product?> getProductByBarcode(String barcode);

  /// Получить товар по QR-коду
  Future<Product?> getProductByQrCode(String qrCode);

  /// Поиск товаров по имени или штрихкоду
  Future<List<Product>> searchProducts(String query);

  /// Создать товар
  Future<Product> createProduct(Product product, {int? userId});

  /// Обновить товар
  Future<Product> updateProduct(Product product);

  /// Удалить товар
  Future<void> deleteProduct(int id);

  /// Обновить остаток товара
  Future<void> updateStock(int id, int newStock, {String? movementType, String? notes, int? userId, int? receiptId});

  /// Уменьшить остаток товара
  Future<bool> decreaseStock(int id, int quantity);

  /// Увеличить остаток товара
  Future<void> increaseStock(int id, int quantity);

  /// Получить товары с низким остатком
  Future<List<Product>> getProductsWithLowStock(int threshold);

  /// Получить товары, которых нет в наличии
  Future<List<Product>> getOutOfStockProducts();
}

