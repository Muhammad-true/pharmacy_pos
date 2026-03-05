class PurchaseRequest {
  final int id;
  final int productId;
  final String productName;
  final int? requestedByUserId;
  final String? requestedByUserName;
  final String status; // open/resolved
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PurchaseRequest({
    required this.id,
    required this.productId,
    required this.productName,
    this.requestedByUserId,
    this.requestedByUserName,
    this.status = 'open',
    this.createdAt,
    this.updatedAt,
  });
}

