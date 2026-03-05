import 'package:drift/drift.dart';

import '../database.dart';

part 'stock_movements_dao.g.dart';

/// DAO для работы с историей движения товаров
@DriftAccessor(tables: [StockMovements])
class StockMovementsDao extends DatabaseAccessor<AppDatabase>
    with _$StockMovementsDaoMixin {
  StockMovementsDao(super.db);

  /// Получить всю историю движения товаров
  Future<List<StockMovement>> getAllMovements() async {
    return await (select(
      stockMovements,
    )..orderBy([(m) => OrderingTerm.desc(m.createdAt)])).get();
  }

  /// Получить историю движения для конкретного товара
  Future<List<StockMovement>> getMovementsByProductId(int productId) async {
    return await (select(stockMovements)
          ..where((m) => m.productId.equals(productId))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();
  }

  /// Получить движения по типу
  Future<List<StockMovement>> getMovementsByType(String movementType) async {
    return await (select(stockMovements)
          ..where((m) => m.movementType.equals(movementType))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();
  }

  /// Получить движения за период
  Future<List<StockMovement>> getMovementsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return await (select(stockMovements)
          ..where((m) => m.createdAt.isBetweenValues(start, end))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();
  }

  /// Создать запись о движении товара
  Future<int> insertMovement(StockMovementsCompanion movement) async {
    return await into(stockMovements).insert(movement);
  }

  /// Получить последнее движение для товара
  Future<StockMovement?> getLastMovementByProductId(int productId) async {
    return await (select(stockMovements)
          ..where((m) => m.productId.equals(productId))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }
}
