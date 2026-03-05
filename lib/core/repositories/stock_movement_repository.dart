import 'package:drift/drift.dart';
import '../database/database_provider.dart';
import '../database/database.dart' as db;
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';

/// Модель движения товара на складе
class StockMovement {
  final int id;
  final int productId;
  final String movementType; // 'in', 'out', 'adjustment'
  final int quantity; // Количество в упаковках
  final int stockBefore;
  final int stockAfter;
  final double? price;
  final String? notes;
  final int? userId;
  final int? receiptId;
  final DateTime createdAt;

  StockMovement({
    required this.id,
    required this.productId,
    required this.movementType,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    this.price,
    this.notes,
    this.userId,
    this.receiptId,
    required this.createdAt,
  });

  factory StockMovement.fromDb(db.StockMovement dbMovement) {
    return StockMovement(
      id: dbMovement.id,
      productId: dbMovement.productId,
      movementType: dbMovement.movementType,
      quantity: dbMovement.quantity,
      stockBefore: dbMovement.stockBefore,
      stockAfter: dbMovement.stockAfter,
      price: dbMovement.price,
      notes: dbMovement.notes,
      userId: dbMovement.userId,
      receiptId: dbMovement.receiptId,
      createdAt: dbMovement.createdAt,
    );
  }
}

/// Репозиторий для работы с историей движения товаров
class StockMovementRepository {
  final ErrorHandler _errorHandler = ErrorHandler.instance;

  Future<db.AppDatabase> get _database async {
    return await DatabaseProvider.getDatabase();
  }

  /// Получить всю историю движения
  Future<List<StockMovement>> getAllMovements() async {
    try {
      final database = await _database;
      final dbMovements = await database.stockMovementsDao.getAllMovements();
      return dbMovements.map(StockMovement.fromDb).toList();
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения истории движения: ${e.toString()}');
    }
  }

  /// Получить историю движения для товара
  Future<List<StockMovement>> getMovementsByProductId(int productId) async {
    try {
      final database = await _database;
      final dbMovements = await database.stockMovementsDao.getMovementsByProductId(productId);
      return dbMovements.map(StockMovement.fromDb).toList();
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения истории движения товара: ${e.toString()}');
    }
  }

  /// Создать запись о движении товара
  Future<int> createMovement({
    required int productId,
    required String movementType,
    required int quantity,
    required int stockBefore,
    required int stockAfter,
    double? price,
    String? notes,
    int? userId,
    int? receiptId,
  }) async {
    try {
      final database = await _database;
      final movement = db.StockMovementsCompanion.insert(
        productId: productId,
        movementType: movementType,
        quantity: quantity,
        stockBefore: stockBefore,
        stockAfter: stockAfter,
        price: Value(price),
        notes: Value(notes),
        userId: Value(userId),
        receiptId: Value(receiptId),
      );
      return await database.stockMovementsDao.insertMovement(movement);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка создания записи движения: ${e.toString()}');
    }
  }
}

