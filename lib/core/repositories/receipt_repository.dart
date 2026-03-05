import 'package:drift/drift.dart' show Value;
import '../../features/cashier/models/receipt.dart';
import '../../features/shared/models/receipt_history.dart';
import '../database/database_provider.dart';
import '../database/database.dart' as db;
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import 'i_receipt_repository.dart';
import 'mappers/database_mappers.dart';

/// Реализация репозитория для работы с чеками
class ReceiptRepository implements IReceiptRepository {
  final ErrorHandler _errorHandler = ErrorHandler.instance;

  /// Получить БД
  Future<db.AppDatabase> get _database async => await DatabaseProvider.getDatabase();

  @override
  Future<List<ReceiptHistory>> getAllReceipts() async {
    try {
      final database = await _database;
      final dbReceipts = await database.receiptsDao.getAllReceipts();
      
      final result = <ReceiptHistory>[];
      for (final dbReceipt in dbReceipts) {
        final itemsWithProducts = await database.receiptsDao.getReceiptItemsWithProducts(dbReceipt.id);
        
        // Загружаем имя кассира, если userId указан
        String? userName;
        print('🔵 [ReceiptRepository] getAllReceipts: dbReceipt.id = ${dbReceipt.id}, receiptNumber = ${dbReceipt.receiptNumber}, userId = ${dbReceipt.userId}');
        print('🟣 [ReceiptRepository] getAllReceipts: createdAt raw = ${dbReceipt.createdAt} | ms = ${dbReceipt.createdAt.millisecondsSinceEpoch}');
        if (dbReceipt.userId != null) {
          try {
            final user = await database.usersDao.getUserById(dbReceipt.userId!);
            userName = user?.name;
            print('🔵 [ReceiptRepository] getAllReceipts: Загружен пользователь: id = ${user?.id}, name = ${user?.name}');
          } catch (e) {
            print('❌ [ReceiptRepository] getAllReceipts: Ошибка загрузки пользователя ${dbReceipt.userId}: $e');
            // Игнорируем ошибку получения пользователя
          }
        } else {
          print('⚠️ [ReceiptRepository] getAllReceipts: userId равен null для чека ${dbReceipt.id} (${dbReceipt.receiptNumber})');
        }
        
        result.add(DatabaseMappers.toReceiptHistory(
          dbReceipt, 
          itemsWithProducts,
          userName: userName,
        ));
      }
      
      return result;
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения чеков: ${e.toString()}');
    }
  }

  @override
  Future<ReceiptHistory?> getReceiptById(int id) async {
    try {
      final database = await _database;
      final dbReceipt = await database.receiptsDao.getReceiptById(id);
      if (dbReceipt == null) return null;
      
      final itemsWithProducts = await database.receiptsDao.getReceiptItemsWithProducts(id);
      
      // Загружаем имя кассира, если userId указан
      String? userName;
      if (dbReceipt.userId != null) {
        try {
          final user = await database.usersDao.getUserById(dbReceipt.userId!);
          userName = user?.name;
        } catch (e) {
          // Игнорируем ошибку получения пользователя
        }
      }
      
      return DatabaseMappers.toReceiptHistory(
        dbReceipt, 
        itemsWithProducts,
        userName: userName,
      );
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения чека: ${e.toString()}');
    }
  }

  @override
  Future<ReceiptHistory?> getReceiptByNumber(String receiptNumber) async {
    try {
      final database = await _database;
      final dbReceipt = await database.receiptsDao.getReceiptByNumber(receiptNumber);
      if (dbReceipt == null) return null;
      
      final itemsWithProducts = await database.receiptsDao.getReceiptItemsWithProducts(dbReceipt.id);
      
      // Загружаем имя кассира, если userId указан
      String? userName;
      if (dbReceipt.userId != null) {
        try {
          final user = await database.usersDao.getUserById(dbReceipt.userId!);
          userName = user?.name;
        } catch (e) {
          // Игнорируем ошибку получения пользователя
        }
      }
      
      return DatabaseMappers.toReceiptHistory(
        dbReceipt, 
        itemsWithProducts,
        userName: userName,
      );
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения чека по номеру: ${e.toString()}');
    }
  }

  @override
  Future<List<ReceiptHistory>> getClientReceipts(int clientId, {int limit = 50}) async {
    try {
      final database = await _database;
      final dbReceipts = await database.receiptsDao.getClientReceipts(clientId, limit: limit);
      
      final result = <ReceiptHistory>[];
      for (final dbReceipt in dbReceipts) {
        final itemsWithProducts = await database.receiptsDao.getReceiptItemsWithProducts(dbReceipt.id);
        
        // Загружаем имя кассира, если userId указан
        String? userName;
        if (dbReceipt.userId != null) {
          try {
            final user = await database.usersDao.getUserById(dbReceipt.userId!);
            userName = user?.name;
          } catch (e) {
            // Игнорируем ошибку получения пользователя
          }
        }
        
        result.add(DatabaseMappers.toReceiptHistory(
          dbReceipt, 
          itemsWithProducts,
          userName: userName,
        ));
      }
      
      return result;
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения чеков клиента: ${e.toString()}');
    }
  }

  @override
  Future<List<ReceiptHistory>> getReceiptsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final database = await _database;
      final dbReceipts = await database.receiptsDao.getReceiptsByDateRange(startDate, endDate);
      
      final result = <ReceiptHistory>[];
      for (final dbReceipt in dbReceipts) {
        final itemsWithProducts = await database.receiptsDao.getReceiptItemsWithProducts(dbReceipt.id);
        
        // Загружаем имя кассира, если userId указан
        String? userName;
        if (dbReceipt.userId != null) {
          try {
            final user = await database.usersDao.getUserById(dbReceipt.userId!);
            userName = user?.name;
          } catch (e) {
            // Игнорируем ошибку получения пользователя
          }
        }
        
        result.add(DatabaseMappers.toReceiptHistory(
          dbReceipt, 
          itemsWithProducts,
          userName: userName,
        ));
      }
      
      return result;
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения чеков за период: ${e.toString()}');
    }
  }

  @override
  Future<String> saveReceipt(
    Receipt receipt, {
    int? userId,
    double? bonusPercent,
  }) async {
    try {
      if (receipt.isEmpty) {
        throw ValidationException('Нельзя сохранить пустой чек');
      }

      if (!receipt.canCheckout) {
        throw ValidationException('Чек не готов к оплате');
      }

      final database = await _database;
      final receiptsDao = database.receiptsDao;

      // Логируем userId для отладки
      print('🔵 [ReceiptRepository] saveReceipt: userId = $userId');
      
      // ВСЕ операции выполняем в одной транзакции для атомарности
      // Это гарантирует, что либо все операции выполнятся, либо ничего
      return await database.transaction(() async {
        // Генерируем номер чека
        final receiptNumber = receiptsDao.generateReceiptNumber();

        // Преобразуем чек в модель БД
        print('🔵 [ReceiptRepository] Создание dbReceipt с userId: $userId');
        final dbReceipt = DatabaseMappers.toDbReceipt(receipt, receiptNumber, userId: userId);
        print('🔵 [ReceiptRepository] dbReceipt.userId.value = ${dbReceipt.userId.value}');

        // Преобразуем позиции чека
        final dbItems = receipt.items.map((item) {
          return DatabaseMappers.toDbReceiptItem(item, 0); // receiptId будет установлен в транзакции
        }).toList();

        // Сохраняем чек с позициями и получаем ID чека
        final receiptId = await receiptsDao.createReceiptWithItems(dbReceipt, dbItems);

        // Обновляем остатки товаров (атомарно, защищено от race condition)
        for (final item in receipt.items) {
          // Вычисляем количество упаковок для списания
          final packagesToSubtract = (item.quantity / item.product.unitsPerPackage).ceil();
          
          // Получаем текущий остаток товара перед списанием
          final currentProduct = await database.productsDao.getProductById(item.product.id);
          if (currentProduct == null) {
            throw ValidationException('Товар "${item.product.name}" не найден');
          }
          final stockBefore = currentProduct.stock;
          
          // Атомарное уменьшение остатка с проверкой достаточности
          final stockUpdated = await database.productsDao.decreaseProductStock(
            item.product.id,
            packagesToSubtract,
          );
          
          // Если остатка недостаточно, откатываем транзакцию
          if (!stockUpdated) {
            throw ValidationException(
              'Недостаточно товара "${item.product.name}" на складе. '
              'Требуется: $packagesToSubtract упаковок',
            );
          }
          
          // Получаем новый остаток после списания
          final updatedProduct = await database.productsDao.getProductById(item.product.id);
          if (updatedProduct == null) {
            throw ValidationException('Товар "${item.product.name}" не найден после обновления');
          }
          final stockAfter = updatedProduct.stock;
          
          // Создаем запись в истории движения
          try {
            await database.stockMovementsDao.insertMovement(
              db.StockMovementsCompanion.insert(
                productId: item.product.id,
                movementType: 'out',
                quantity: packagesToSubtract,
                stockBefore: stockBefore,
                stockAfter: stockAfter,
                price: Value(item.price),
                notes: Value('Продажа. Чек №$receiptNumber'),
                receiptId: Value(receiptId),
                userId: userId != null ? Value(userId) : const Value.absent(),
              ),
            );
          } catch (e) {
            // Логируем ошибку, но не прерываем операцию
            ErrorHandler.instance.warning('Ошибка записи в историю движения при продаже: $e');
          }
        }

        double accumulatedBonuses = 0.0;
        final effectiveBonusPercent =
            (bonusPercent ?? 5.0).clamp(0, 100).toDouble();
        
        // Если есть клиент
        if (receipt.clientId != null) {
          if (receipt.bonuses > 0) {
            // Если списаны бонусы, обновляем бонусы клиента
            await database.clientsDao.subtractClientBonuses(receipt.clientId!, receipt.bonuses);
          } else {
            // Если бонусы не списывались, начисляем процент от итоговой суммы
            accumulatedBonuses = receipt.total * (effectiveBonusPercent / 100);
            await database.clientsDao.addClientBonuses(receipt.clientId!, accumulatedBonuses);
          }
        }

        return receiptNumber;
      });
    } catch (e) {
      _errorHandler.handleError(e);
      if (e is DatabaseException || e is ValidationException) rethrow;
      throw DatabaseException('Ошибка сохранения чека: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteReceipt(int id) async {
    try {
      final database = await _database;
      await database.receiptsDao.deleteReceipt(id);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка удаления чека: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> getReceiptsStatistics(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final database = await _database;
      return await database.receiptsDao.getReceiptsStatistics(startDate, endDate);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения статистики: ${e.toString()}');
    }
  }
}

