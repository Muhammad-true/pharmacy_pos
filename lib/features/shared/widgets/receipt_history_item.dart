import 'package:flutter/material.dart';
import '../models/receipt_history.dart';
import '../../../utils/formatters.dart';

class ReceiptHistoryItemWidget extends StatelessWidget {
  final ReceiptHistory receipt;
  final VoidCallback onTap;

  const ReceiptHistoryItemWidget({
    super.key,
    required this.receipt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receipt.receiptNumber,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                        if (receipt.userName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Кассир: ${receipt.userName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDateTime(receipt.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (receipt.items.isNotEmpty)
                Text(
                  '${receipt.items.length} ${_getItemsText(receipt.items.length)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (receipt.discount > 0 || receipt.bonuses > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (receipt.discount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.red[200]!,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Скидка ${receipt.discountPercent > 0 ? '${receipt.discountPercent.toStringAsFixed(0)}%' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (receipt.discount > 0 && receipt.bonuses > 0)
                          const SizedBox(width: 6),
                        if (receipt.bonuses > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.green[200]!,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Бонусы',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    const SizedBox.shrink(),
                  Text(
                    Formatters.formatMoney(receipt.total),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getItemsText(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'товар';
    } else if (count % 10 >= 2 &&
        count % 10 <= 4 &&
        (count % 100 < 10 || count % 100 >= 20)) {
      return 'товара';
    } else {
      return 'товаров';
    }
  }

  String _formatDateTime(DateTime date) {
    // Форматируем дату и время: ДД.ММ.ГГГГ ЧЧ:ММ
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

