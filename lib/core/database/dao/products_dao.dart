import 'package:drift/drift.dart';

import '../database.dart';

part 'products_dao.g.dart';

/// DAO для работы с товарами
@DriftAccessor(tables: [Products])
class ProductsDao extends DatabaseAccessor<AppDatabase>
    with _$ProductsDaoMixin {
  ProductsDao(super.db);

  /// Получить все товары
  Future<List<Product>> getAllProducts() async {
    return await (select(
      products,
    )..orderBy([(p) => OrderingTerm.asc(p.name)])).get();
  }

  /// Получить товар по ID
  Future<Product?> getProductById(int id) async {
    return await (select(
      products,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  /// Получить товар по штрихкоду
  Future<Product?> getProductByBarcode(String barcode) async {
    return await (select(
      products,
    )..where((p) => p.barcode.equals(barcode))).getSingleOrNull();
  }

  /// Поиск товаров по имени
  Future<List<Product>> searchProducts(String query) async {
    final lowerQuery = query.toLowerCase();
    return await (select(products)
          ..where((p) => p.name.lower().contains(lowerQuery))
          ..orderBy([(p) => OrderingTerm.asc(p.name)])
          ..limit(50))
        .get();
  }

  /// Получить товар по QR-коду
  Future<Product?> getProductByQrCode(String qrCode) async {
    return await (select(
      products,
    )..where((p) => p.qrCode.equals(qrCode))).getSingleOrNull();
  }

  /// Поиск товаров по имени, штрихкоду, QR-коду или ID
  Future<List<Product>> searchProductsByNameOrBarcode(String query) async {
    final lowerQuery = query.toLowerCase();
    // Используем несколько отдельных запросов и объединяем результаты
    final byName = await (select(
      products,
    )..where((p) => p.name.lower().contains(lowerQuery))).get();
    final byBarcode = await (select(
      products,
    )..where((p) => p.barcode.contains(query))).get();
    final byQrCode = await (select(
      products,
    )..where((p) => p.qrCode.isNotNull() & p.qrCode.contains(query))).get();

    // Поиск по ID товара (если запрос - число)
    final byId = <Product>[];
    final idValue = int.tryParse(query);
    if (idValue != null) {
      final product = await getProductById(idValue);
      if (product != null) {
        byId.add(product);
      }
    }

    // Объединяем и убираем дубликаты
    final allProducts = <int, Product>{};
    for (final product in byName) {
      allProducts[product.id] = product;
    }
    for (final product in byBarcode) {
      allProducts[product.id] = product;
    }
    for (final product in byQrCode) {
      allProducts[product.id] = product;
    }
    for (final product in byId) {
      allProducts[product.id] = product;
    }

    final result = allProducts.values.toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    return result.take(50).toList();
  }

  /// Создать товар
  Future<int> insertProduct(ProductsCompanion product) async {
    return await into(products).insert(product);
  }

  /// Обновить товар
  Future<bool> updateProduct(Product product) async {
    return await update(products).replace(product);
  }

  /// Удалить товар
  Future<int> deleteProduct(int id) async {
    return await (delete(products)..where((p) => p.id.equals(id))).go();
  }

  /// Обновить остаток товара
  Future<bool> updateProductStock(int id, int newStock) async {
    final result = await (update(products)..where((p) => p.id.equals(id)))
        .write(ProductsCompanion(stock: Value(newStock)));
    return result > 0;
  }

  /// Уменьшить остаток товара (атомарно, защищено от race condition)
  /// 
  /// Использует атомарное SQL обновление для предотвращения проблем
  /// при параллельных продажах с нескольких касс
  Future<bool> decreaseProductStock(int id, int quantity) async {
    // Атомарное обновление через SQL: уменьшаем stock только если его достаточно
    // Это предотвращает race condition при параллельных продажах
    // SQL: UPDATE products SET stock = stock - ? WHERE id = ? AND stock >= ?
    final result = await customUpdate(
      'UPDATE products SET stock = stock - ? WHERE id = ? AND stock >= ?',
      variables: [Variable.withInt(quantity), Variable.withInt(id), Variable.withInt(quantity)],
      updates: {products},
    );
    
    return result > 0;
  }

  /// Увеличить остаток товара
  Future<bool> increaseProductStock(int id, int quantity) async {
    final product = await getProductById(id);
    if (product == null) return false;

    final newStock = product.stock + quantity;
    return await updateProductStock(id, newStock);
  }

  /// Получить товары с низким остатком (меньше указанного количества)
  Future<List<Product>> getProductsWithLowStock(int threshold) async {
    return await (select(products)
          ..where((p) => p.stock.isSmallerThanValue(threshold))
          ..orderBy([(p) => OrderingTerm.asc(p.stock)]))
        .get();
  }

  /// Получить товары, которых нет в наличии
  Future<List<Product>> getOutOfStockProducts() async {
    return await (select(products)
          ..where((p) => p.stock.equals(0))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
  }
}
