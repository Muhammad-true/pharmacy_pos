import 'package:drift/drift.dart';

import '../../features/shared/models/purchase_request.dart';
import '../database/database_provider.dart';
import '../database/database.dart' as db;
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import 'i_purchase_request_repository.dart';

class PurchaseRequestRepository implements IPurchaseRequestRepository {
  final ErrorHandler _errorHandler = ErrorHandler.instance;

  Future<db.AppDatabase> get _database async =>
      await DatabaseProvider.getDatabase();

  @override
  Future<List<PurchaseRequest>> getAllRequests() async {
    try {
      final database = await _database;
      final dbRequests = await database.purchaseRequestsDao.getAllRequests();
      return _mapRequests(database, dbRequests);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения заявок: ${e.toString()}');
    }
  }

  @override
  Future<List<PurchaseRequest>> getOpenRequests() async {
    try {
      final database = await _database;
      final dbRequests = await database.purchaseRequestsDao.getOpenRequests();
      return _mapRequests(database, dbRequests);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения заявок: ${e.toString()}');
    }
  }

  @override
  Future<void> createRequest({
    required int productId,
    required String productName,
    int? requestedByUserId,
  }) async {
    try {
      final database = await _database;
      await database.purchaseRequestsDao.insertRequest(
        db.PurchaseRequestsCompanion.insert(
          productId: productId,
          productName: productName,
          requestedByUserId: requestedByUserId != null
              ? Value(requestedByUserId)
              : const Value.absent(),
        ),
      );
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка создания заявки: ${e.toString()}');
    }
  }

  @override
  Future<void> markResolved(int id) async {
    try {
      final database = await _database;
      await database.purchaseRequestsDao.markResolved(id);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка обновления заявки: ${e.toString()}');
    }
  }

  Future<List<PurchaseRequest>> _mapRequests(
    db.AppDatabase database,
    List<db.PurchaseRequest> requests,
  ) async {
    final result = <PurchaseRequest>[];
    for (final req in requests) {
      String? userName;
      if (req.requestedByUserId != null) {
        try {
          final user =
              await database.usersDao.getUserById(req.requestedByUserId!);
          userName = user?.name;
        } catch (_) {}
      }
      result.add(
        PurchaseRequest(
          id: req.id,
          productId: req.productId,
          productName: req.productName,
          requestedByUserId: req.requestedByUserId,
          requestedByUserName: userName,
          status: req.status,
          createdAt: req.createdAt,
          updatedAt: req.updatedAt,
        ),
      );
    }
    return result;
  }
}

