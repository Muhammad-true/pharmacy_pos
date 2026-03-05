/// Модель истории чека (для отображения клиенту)
class ReceiptHistory {
  final int id;
  final String receiptNumber;
  final List<ReceiptHistoryItem> items;
  final double subtotal;
  final double discount;
  final double discountPercent;
  final double bonuses;
  final double total;
  final DateTime createdAt;
  final String? paymentMethod;
  final int? userId; // ID кассира, который оформил чек
  final String? userName; // Имя кассира, который оформил чек

  ReceiptHistory({
    required this.id,
    required this.receiptNumber,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.discountPercent,
    required this.bonuses,
    required this.total,
    required this.createdAt,
    this.paymentMethod,
    this.userId,
    this.userName,
  });

  factory ReceiptHistory.fromJson(Map<String, dynamic> json) {
    return ReceiptHistory(
      id: json['id'] as int,
      receiptNumber: json['receiptNumber'] as String? ?? 'N/A',
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => ReceiptHistoryItem.fromJson(item))
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
      bonuses: (json['bonuses'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      paymentMethod: json['paymentMethod'] as String?,
      userId: json['userId'] as int?,
      userName: json['userName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'receiptNumber': receiptNumber,
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'discountPercent': discountPercent,
      'bonuses': bonuses,
      'total': total,
      'createdAt': createdAt.toIso8601String(),
      'paymentMethod': paymentMethod,
      'userId': userId,
      'userName': userName,
    };
  }
}

/// Модель позиции в истории чека
class ReceiptHistoryItem {
  final int productId;
  final String productName;
  final double quantity;
  final double price;
  final double total;

  ReceiptHistoryItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.total,
  });

  factory ReceiptHistoryItem.fromJson(Map<String, dynamic> json) {
    return ReceiptHistoryItem(
      productId: json['productId'] as int,
      productName: json['productName'] as String? ?? 'Товар',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'total': total,
    };
  }
}

