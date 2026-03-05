import 'package:drift/drift.dart';

import '../database.dart';

part 'receipts_dao.g.dart';

/// DAO для работы с чеками
@DriftAccessor(tables: [Receipts, ReceiptItems, Products, Clients])
class ReceiptsDao extends DatabaseAccessor<AppDatabase>
    with _$ReceiptsDaoMixin {
  ReceiptsDao(super.db);

  /// Получить все чеки
  Future<List<Receipt>> getAllReceipts() async {
    return await (select(
      receipts,
    )..orderBy([(r) => OrderingTerm.desc(r.createdAt)])).get();
  }

  /// Получить чек по ID
  Future<Receipt?> getReceiptById(int id) async {
    return await (select(
      receipts,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  /// Получить чек по номеру
  Future<Receipt?> getReceiptByNumber(String receiptNumber) async {
    return await (select(
      receipts,
    )..where((r) => r.receiptNumber.equals(receiptNumber))).getSingleOrNull();
  }

  /// Получить чеки клиента
  Future<List<Receipt>> getClientReceipts(
    int clientId, {
    int limit = 50,
  }) async {
    return await (select(receipts)
          ..where((r) => r.clientId.equals(clientId))
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Получить чеки за период
  Future<List<Receipt>> getReceiptsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await (select(receipts)
          ..where((r) => r.createdAt.isBetweenValues(startDate, endDate))
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .get();
  }

  /// Создать чек
  Future<int> insertReceipt(ReceiptsCompanion receipt) async {
    return await into(receipts).insert(receipt);
  }

  /// Обновить чек
  Future<bool> updateReceipt(Receipt receipt) async {
    return await update(receipts).replace(receipt);
  }

  /// Удалить чек
  Future<int> deleteReceipt(int id) async {
    // ReceiptItems удалятся автоматически из-за cascade
    return await (delete(receipts)..where((r) => r.id.equals(id))).go();
  }

  /// Получить позиции чека
  Future<List<ReceiptItem>> getReceiptItems(int receiptId) async {
    return await (select(receiptItems)
          ..where((ri) => ri.receiptId.equals(receiptId))
          ..orderBy([(ri) => OrderingTerm.asc(ri.index)]))
        .get();
  }

  /// Получить позиции чека с информацией о товарах
  Future<List<(ReceiptItem, Product)>> getReceiptItemsWithProducts(
    int receiptId,
  ) async {
    final query =
        select(receiptItems).join([
            innerJoin(products, products.id.equalsExp(receiptItems.productId)),
          ])
          ..where(receiptItems.receiptId.equals(receiptId))
          ..orderBy([OrderingTerm.asc(receiptItems.index)]);

    final results = await query.get();
    return results
        .map((row) => (row.readTable(receiptItems), row.readTable(products)))
        .toList();
  }

  /// Добавить позицию в чек
  Future<int> insertReceiptItem(ReceiptItemsCompanion item) async {
    return await into(receiptItems).insert(item);
  }

  /// Обновить позицию в чеке
  Future<bool> updateReceiptItem(ReceiptItem item) async {
    return await update(receiptItems).replace(item);
  }

  /// Удалить позицию из чека
  Future<int> deleteReceiptItem(int id) async {
    return await (delete(receiptItems)..where((ri) => ri.id.equals(id))).go();
  }

  /// Удалить все позиции чека
  Future<int> deleteReceiptItems(int receiptId) async {
    return await (delete(
      receiptItems,
    )..where((ri) => ri.receiptId.equals(receiptId))).go();
  }

  /// Создать чек с позициями (транзакция)
  Future<int> createReceiptWithItems(
    ReceiptsCompanion receipt,
    List<ReceiptItemsCompanion> items,
  ) async {
    return await transaction(() async {
      // Создаем чек
      final receiptId = await into(receipts).insert(receipt);

      // Добавляем позиции
      for (final item in items) {
        await into(
          receiptItems,
        ).insert(item.copyWith(receiptId: Value(receiptId)));
      }

      return receiptId;
    });
  }

  /// Получить статистику по чекам за период
  Future<Map<String, dynamic>> getReceiptsStatistics(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final receiptsList = await getReceiptsByDateRange(startDate, endDate);

    double totalAmount = 0.0;
    double totalDiscount = 0.0;
    double totalBonuses = 0.0;
    int receiptsCount = receiptsList.length;

    for (final receipt in receiptsList) {
      totalAmount += receipt.total;
      totalDiscount += receipt.discount;
      totalBonuses += receipt.bonuses;
    }

    return {
      'receiptsCount': receiptsCount,
      'totalAmount': totalAmount,
      'totalDiscount': totalDiscount,
      'totalBonuses': totalBonuses,
      'averageAmount': receiptsCount > 0 ? totalAmount / receiptsCount : 0.0,
    };
  }

  /// Генерация номера чека
  String generateReceiptNumber() {
    final now = DateTime.now();
    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final timestamp = now.millisecondsSinceEpoch.toString().substring(7);
    return 'Ч-$year$month$day-$timestamp';
  }
}
