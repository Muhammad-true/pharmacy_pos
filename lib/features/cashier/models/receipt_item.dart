import 'product.dart';

class ReceiptItem {
  final int id;
  final Product product;
  double quantity; // Количество в единицах (таблетках)
  double price; // Цена за упаковку
  int
  unitsInPackage; // Количество таблеток в упаковке (может отличаться от product.unitsPerPackage)
  int index;

  ReceiptItem({
    required this.id,
    required this.product,
    required this.quantity,
    required this.price,
    required this.index,
    int? unitsInPackage,
  }) : unitsInPackage = unitsInPackage ?? product.unitsPerPackage;

  // Количество упаковок
  double get packages => quantity / unitsInPackage;

  // Количество отдельных единиц (остаток после целых упаковок)
  int get units => (quantity % unitsInPackage).toInt();

  // Цена за единицу (таблетку)
  double get pricePerUnit => price / unitsInPackage;

  // Итоговая сумма
  double get total => quantity * pricePerUnit;

  ReceiptItem copyWith({
    int? id,
    Product? product,
    double? quantity,
    double? price,
    int? index,
    int? unitsInPackage,
  }) {
    return ReceiptItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      index: index ?? this.index,
      unitsInPackage: unitsInPackage ?? this.unitsInPackage,
    );
  }

  Map<String, dynamic> toJson() {
    // Вычисляем количество полных упаковок и отдельных единиц на основе стандартного размера упаковки
    final standardUnitsPerPackage = product.unitsPerPackage;
    final fullPackages = (quantity / standardUnitsPerPackage).floor();
    final partialUnits = (quantity % standardUnitsPerPackage).toInt();

    return {
      'productId': product.id,
      'quantity': quantity, // Общее количество в единицах (таблетках)
      'price': price, // Цена за упаковку (может быть изменена)
      'unitsInPackage': unitsInPackage, // Текущий размер упаковки в чеке
      // Для правильного учета остатков в БД:
      'fullPackages':
          fullPackages, // Количество полных упаковок (по стандартному размеру)
      'partialUnits':
          partialUnits, // Количество отдельных единиц из неполной упаковки
      'standardUnitsPerPackage':
          standardUnitsPerPackage, // Стандартный размер упаковки товара
    };
  }
}
