import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/cashier/models/product.dart';
import 'repository_providers.dart';

part 'product_search_notifier.g.dart';

/// Состояние поиска товаров
@riverpod
class ProductSearchState extends _$ProductSearchState {
  @override
  Future<List<Product>> build() async {
    // При инициализации загружаем все товары
    final productRepo = ref.read(productRepositoryProvider);
    return await productRepo.getAllProducts();
  }

  /// Поиск товаров
  Future<void> search(String query) async {
    state = const AsyncValue.loading();
    
    try {
      final productRepo = ref.read(productRepositoryProvider);
      
      if (query.isEmpty) {
        // Если запрос пустой, загружаем все товары
        final products = await productRepo.getAllProducts();
        state = AsyncValue.data(products);
      } else {
        // Ищем товары
        final products = await productRepo.searchProducts(query);
        state = AsyncValue.data(products);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Обновить список товаров
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    
    try {
      final productRepo = ref.read(productRepositoryProvider);
      final products = await productRepo.getAllProducts();
      state = AsyncValue.data(products);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

