import '../../features/cashier/models/receipt.dart';
import '../../features/shared/models/receipt_history.dart';

/// Интерфейс репозитория для работы с чеками
abstract class IReceiptRepository {
  /// Получить все чеки
  Future<List<ReceiptHistory>> getAllReceipts();

  /// Получить чек по ID
  Future<ReceiptHistory?> getReceiptById(int id);

  /// Получить чек по номеру
  Future<ReceiptHistory?> getReceiptByNumber(String receiptNumber);

  /// Получить чеки клиента
  Future<List<ReceiptHistory>> getClientReceipts(int clientId, {int limit = 50});

  /// Получить чеки за период
  Future<List<ReceiptHistory>> getReceiptsByDateRange(
    DateTime startDate,
    DateTime endDate,
  );

  /// Сохранить чек
  /// 
  /// Принимает объект Receipt и сохраняет его в БД
  /// Возвращает номер сохраненного чека
  Future<String> saveReceipt(
    Receipt receipt, {
    int? userId,
    double? bonusPercent,
  });

  /// Удалить чек
  Future<void> deleteReceipt(int id);

  /// Получить статистику по чекам за период
  Future<Map<String, dynamic>> getReceiptsStatistics(
    DateTime startDate,
    DateTime endDate,
  );
}

