import '../../features/shared/models/purchase_request.dart';

abstract class IPurchaseRequestRepository {
  Future<List<PurchaseRequest>> getAllRequests();
  Future<List<PurchaseRequest>> getOpenRequests();
  Future<void> createRequest({
    required int productId,
    required String productName,
    int? requestedByUserId,
  });
  Future<void> markResolved(int id);
}

