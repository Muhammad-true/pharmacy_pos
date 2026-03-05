import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../models/receipt.dart';
import 'receipt_item_row.dart';

class ReceiptTable extends ConsumerWidget {
  final Receipt receipt;
  final int? selectedIndex;
  final Function(int) onItemSelected;
  final Function(int) onItemDelete;
  final Function(int) onIncreaseQuantity;
  final Function(int) onDecreaseQuantity;
  final Function(int, int) onUnitsInPackageChanged;
  final Function(FocusNode?, TextEditingController?, bool)? onActiveFieldChanged;
  final VoidCallback? onNotifyOutOfStock;

  const ReceiptTable({
    super.key,
    required this.receipt,
    this.selectedIndex,
    required this.onItemSelected,
    required this.onItemDelete,
    required this.onIncreaseQuantity,
    required this.onDecreaseQuantity,
    required this.onUnitsInPackageChanged,
    this.onActiveFieldChanged,
    this.onNotifyOutOfStock,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(appLocalizationsProvider);
    
    if (receipt.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            Text(
              loc.receiptEmptyMessage,
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Заголовок таблицы
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2).withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  '№',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(
                  loc.productName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              SizedBox(
                width: 140,
                child: Text(
                  loc.quantityShort,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  loc.priceLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  loc.tablets,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 130,
                child: Text(
                  loc.sum,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  loc.actions,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        // Список товаров
        Expanded(
          child: ListView.separated(
            itemCount: receipt.items.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, thickness: 1, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final item = receipt.items[index];
              return ReceiptItemRow(
                key: ValueKey('receipt_item_${item.id}'),
                item: item,
                index: index,
                isSelected: selectedIndex == index,
                onTap: () => onItemSelected(index),
                onDelete: () => onItemDelete(index),
                onIncreaseQuantity: () => onIncreaseQuantity(index),
                onDecreaseQuantity: () => onDecreaseQuantity(index),
                onUnitsInPackageChanged: (newUnits) =>
                    onUnitsInPackageChanged(index, newUnits),
                onActiveFieldChanged: onActiveFieldChanged,
                onNotifyOutOfStock: onNotifyOutOfStock,
              );
            },
          ),
        ),
      ],
    );
  }
}
