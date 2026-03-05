import 'receipt.dart';

/// Модель активного чека с информацией о клиенте
class ActiveReceipt {
  final String id;
  final Receipt receipt;
  final String? clientName;
  final DateTime createdAt;

  ActiveReceipt({
    required this.id,
    required this.receipt,
    this.clientName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String displayName(String newReceiptLabel, String receiptLabel) {
    if (clientName != null) {
      return clientName!;
    }
    if (receipt.items.isEmpty) {
      return newReceiptLabel;
    }
    return '$receiptLabel #${id.substring(0, 8)}';
  }

  double get total => receipt.total;
}

