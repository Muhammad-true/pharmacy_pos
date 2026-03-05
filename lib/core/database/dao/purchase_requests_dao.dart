import 'package:drift/drift.dart';

import '../database.dart';

part 'purchase_requests_dao.g.dart';

@DriftAccessor(tables: [PurchaseRequests])
class PurchaseRequestsDao extends DatabaseAccessor<AppDatabase>
    with _$PurchaseRequestsDaoMixin {
  PurchaseRequestsDao(super.db);

  Future<List<PurchaseRequest>> getAllRequests() async {
    return await (select(purchaseRequests)
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .get();
  }

  Future<List<PurchaseRequest>> getOpenRequests() async {
    return await (select(purchaseRequests)
          ..where((r) => r.status.equals('open'))
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .get();
  }

  Future<int> insertRequest(PurchaseRequestsCompanion request) async {
    return await into(purchaseRequests).insert(request);
  }

  Future<bool> markResolved(int id) async {
    final updated = await (update(purchaseRequests)
          ..where((r) => r.id.equals(id)))
        .write(
      PurchaseRequestsCompanion(
        status: const Value('resolved'),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return updated > 0;
  }
}

