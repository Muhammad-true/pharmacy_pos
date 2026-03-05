import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/providers/auth_notifier.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../utils/formatters.dart';
import '../../admin/screens/users_management_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../cashier/models/product.dart';
import '../models/warehouse_item.dart';
import '../widgets/add_product_sheet.dart';
import '../widgets/edit_product_sheet.dart';
import '../widgets/product_details_sheet.dart';
import '../widgets/restock_dialog.dart';
import '../widgets/stock_movements_screen.dart';

class WarehouseScreen extends ConsumerStatefulWidget {
  const WarehouseScreen({super.key});

  @override
  ConsumerState<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends ConsumerState<WarehouseScreen> {
  /// Добавить товар (публичный метод для вызова извне)
  void addProduct() {
    _handleAddProduct();
  }

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  List<WarehouseItem> _allItems = [];
  List<WarehouseItem> _filteredItems = [];
  final List<String> _manufacturers = [];
  final List<String> _organizations = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _selectedManufacturer = 'all';
  String _selectedOrganization = 'all';

  Map<String, String> _getStatusFilters(WidgetRef ref) {
    final loc = ref.watch(appLocalizationsProvider);
    return {
      'all': loc.all,
      'inStock': loc.inStockLabel,
      'lowStock': loc.lowStockLabel,
      'outOfStock': loc.outOfStock,
      'expired': loc.expiredLabel,
    };
  }

  void _handleLogout() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final loc = ref.watch(appLocalizationsProvider);
        return AlertDialog(
          title: Text('${loc.logout}?'),
          content: Text(loc.sessionWillEnd),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
              child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(authStateProvider.notifier).logout();
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
              child: Text(loc.logout),
          ),
        ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadWarehouseItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouseItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Загружаем товары из БД через репозиторий
      final productRepo = ref.read(productRepositoryProvider);
      final manufacturerRepo = ref.read(manufacturerRepositoryProvider);
      final products = await productRepo.getAllProducts();

      // Загружаем всех производителей для маппинга
      final manufacturers = await manufacturerRepo.getAllManufacturers();
      final manufacturersMap = {for (var m in manufacturers) m.id: m};

      // Преобразуем продукты в WarehouseItem с данными из БД
      const defaultOrganizations = ['Основной склад', 'Филиал №1', 'Филиал №2'];
      const defaultShelves = ['A-01', 'A-02', 'B-10', 'C-07', 'D-03'];

      _allItems = products.map((product) {
        // Используем остаток из БД как quantity
        final quantity = product.stock;

        // Получаем производителя из БД
        final loc = ref.read(appLocalizationsProvider);
        final manufacturer = product.manufacturerId != null
            ? manufacturersMap[product.manufacturerId]?.name ?? loc.unknown
            : loc.unknown;

        final organization = (product.organization != null &&
                product.organization!.trim().isNotEmpty)
            ? product.organization!.trim()
            : defaultOrganizations[product.id % defaultOrganizations.length];
        final shelf = (product.shelfLocation != null &&
                product.shelfLocation!.trim().isNotEmpty)
            ? product.shelfLocation!.trim()
            : defaultShelves[product.id % defaultShelves.length];
        final inventoryCode = (product.inventoryCode != null &&
                product.inventoryCode!.trim().isNotEmpty)
            ? product.inventoryCode!.trim()
            : 'INV-${product.id.toString().padLeft(5, '0')}';

        // Генерируем дату истечения (по умолчанию через год, если нет данных)
        // В будущем можно добавить таблицу для партий товаров с датами истечения
        final expiryDate = DateTime.now().add(const Duration(days: 365));

        return WarehouseItem(
          product: product,
          manufacturer: manufacturer,
          organization: organization,
          inventoryCode: inventoryCode,
          shelfLocation: shelf,
          quantity: quantity,
          totalUnits: quantity * product.unitsPerPackage,
          costPrice:
              product.price *
              0.6, // Себестоимость по умолчанию (60% от цены продажи)
          sellingPrice: product.price,
          lastReceived: DateTime.now().subtract(
            Duration(days: product.id % 30),
          ),
          lastSold: quantity > 0
              ? DateTime.now().subtract(Duration(hours: product.id % 48))
              : null,
          expiryDate: expiryDate,
        );
      }).toList();

      // Обновляем списки производителей и организаций
      _manufacturers
        ..clear()
        ..addAll({for (final item in _allItems) item.manufacturer});
      _manufacturers.sort();

      _organizations
        ..clear()
        ..addAll({for (final item in _allItems) item.organization});
      _organizations.sort();

      _applyFilters();
    } catch (e) {
      ErrorHandler.instance.handleError(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ref.watch(appLocalizationsProvider).loadDataError}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    List<WarehouseItem> filtered = _allItems;

    // Фильтр по статусу
    switch (_selectedStatus) {
      case 'inStock':
        filtered = filtered
            .where((item) => item.quantity > 10 && !item.isExpired)
            .toList();
        break;
      case 'lowStock':
        filtered = filtered
            .where(
              (item) =>
                  item.isLowStock && !item.isOutOfStock && !item.isExpired,
            )
            .toList();
        break;
      case 'outOfStock':
        filtered = filtered.where((item) => item.isOutOfStock).toList();
        break;
      case 'expired':
        filtered = filtered.where((item) => item.isExpired).toList();
        break;
    }

    if (_selectedManufacturer != 'all') {
      filtered = filtered
          .where((item) => item.manufacturer == _selectedManufacturer)
          .toList();
    }

    if (_selectedOrganization != 'all') {
      filtered = filtered
          .where((item) => item.organization == _selectedOrganization)
          .toList();
    }

    // Фильтр по поиску
    final searchQuery = _searchController.text.toLowerCase().trim();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        return item.product.name.toLowerCase().contains(searchQuery) ||
            item.product.barcode.toLowerCase().contains(searchQuery) ||
            item.manufacturer.toLowerCase().contains(searchQuery) ||
            item.organization.toLowerCase().contains(searchQuery) ||
            item.inventoryCode.toLowerCase().contains(searchQuery) ||
            item.shelfLocation.toLowerCase().contains(searchQuery);
      }).toList();
    }

    setState(() {
      _filteredItems = filtered;
    });
  }

  void _showFiltersDialog() {
    final loc = ref.watch(appLocalizationsProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      loc.filters,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Фильтр по производителям
                    if (_manufacturers.isNotEmpty) ...[
                      Text(
                        loc.manufacturers,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: Text(loc.all),
                            selected: _selectedManufacturer == 'all',
                            onSelected: (_) {
                              setState(() {
                                _selectedManufacturer = 'all';
                              });
                              _applyFilters();
                              Navigator.pop(context);
                            },
                          ),
                          ..._manufacturers.map(
                            (manufacturer) => FilterChip(
                              label: Text(manufacturer),
                              selected: _selectedManufacturer == manufacturer,
                              onSelected: (_) {
                                setState(() {
                                  _selectedManufacturer = manufacturer;
                                });
                                _applyFilters();
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Фильтр по организациям
                    if (_organizations.isNotEmpty) ...[
                      Text(
                        loc.organizations,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: Text(loc.all),
                            selected: _selectedOrganization == 'all',
                            onSelected: (_) {
                              setState(() {
                                _selectedOrganization = 'all';
                              });
                              _applyFilters();
                              Navigator.pop(context);
                            },
                          ),
                          ..._organizations.map(
                            (org) => FilterChip(
                              label: Text(org),
                              selected: _selectedOrganization == org,
                              onSelected: (_) {
                                setState(() {
                                  _selectedOrganization = org;
                                });
                                _applyFilters();
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Кнопка сброса фильтров
                    if (_selectedManufacturer != 'all' ||
                        _selectedOrganization != 'all')
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedManufacturer = 'all';
                              _selectedOrganization = 'all';
                            });
                            _applyFilters();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.clear_all),
                          label: Text(loc.resetFilters),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAddProduct() async {
    final result = await showModalBottomSheet<AddProductResult?>(
      context: context,
      isScrollControlled: true,
      isDismissible: false, // Предотвращаем закрытие при свайпе вниз
      enableDrag: false, // Отключаем перетаскивание для закрытия
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AddProductSheet(organizations: _organizations, manufacturers: []),
    );

    if (result == null || result.item == null) {
      return;
    }

    final item = result.item!;
    final product = item.product;

    try {
      // Сохраняем товар в БД через репозиторий
      final productRepo = ref.read(productRepositoryProvider);
      
      // Получаем текущего пользователя
      final currentUser = ref.read(authStateProvider);
      final userId = currentUser?.id;

      // Проверяем, существует ли товар с таким штрихкодом
      final existingProduct = await productRepo.getProductByBarcode(
        product.barcode,
      );

      if (existingProduct != null) {
        // Если товар существует, обновляем остаток
        await productRepo.updateStock(
          existingProduct.id,
          existingProduct.stock + product.stock,
          movementType: 'in',
          notes: 'Добавление товара через форму склада',
          userId: userId,
        );

        if (mounted) {
          final loc = ref.watch(appLocalizationsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                loc.productExistsStockIncreased(product.name),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Создаем новый товар в БД
        final createdProduct = await productRepo.createProduct(product, userId: userId);

        // Обновляем item с созданным продуктом (с правильным ID из БД)
        final updatedItem = WarehouseItem(
          product: createdProduct,
          manufacturer: item.manufacturer,
          organization: item.organization,
          inventoryCode: item.inventoryCode,
          shelfLocation: item.shelfLocation,
          quantity: item.quantity,
          totalUnits: item.totalUnits,
          costPrice: item.costPrice,
          sellingPrice: item.sellingPrice,
          lastReceived: item.lastReceived,
          lastSold: item.lastSold,
          expiryDate: item.expiryDate,
        );

        if (mounted) {
          setState(() {
            if (!_manufacturers.contains(updatedItem.manufacturer)) {
              _manufacturers.add(updatedItem.manufacturer);
              _manufacturers.sort();
            }
            if (!_organizations.contains(updatedItem.organization)) {
              _organizations.add(updatedItem.organization);
              _organizations.sort();
            }
            _allItems.insert(0, updatedItem);
          });
          _applyFilters();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${ref.watch(appLocalizationsProvider).productAdded}: "${createdProduct.name}"'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Перезагружаем список товаров для обновления данных
      await _loadWarehouseItems();
    } catch (e) {
      ErrorHandler.instance.handleError(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ref.watch(appLocalizationsProvider).error}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ref.watch(appLocalizationsProvider).warehouse),
            const SizedBox(height: 4),
            Text(
              ref.watch(appLocalizationsProvider).positions(_allItems.length),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[200]),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          // Кнопка управления пользователями (только для админа)
          Builder(
            builder: (context) {
              final currentUser = ref.watch(authStateProvider);
              if (currentUser?.role.toLowerCase() == 'admin') {
                return IconButton(
                  icon: const Icon(Icons.people),
                  tooltip: ref.watch(appLocalizationsProvider).manageUsers,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const UsersManagementScreen(),
                      ),
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: ref.watch(appLocalizationsProvider).refresh,
            onPressed: _loadWarehouseItems,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.analytics_outlined),
            initialValue: _selectedStatus,
            onSelected: (value) {
              setState(() {
                _selectedStatus = value;
              });
              _applyFilters();
            },
            itemBuilder: (context) {
              final statusFilters = _getStatusFilters(ref);
              return statusFilters.entries
                  .map(
                    (entry) => CheckedPopupMenuItem<String>(
                      value: entry.key,
                      checked: _selectedStatus == entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: ref.watch(appLocalizationsProvider).exit,
            onPressed: _handleLogout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'warehouse_add_product',
        onPressed: _handleAddProduct,
        icon: const Icon(Icons.add),
        label: Text(ref.watch(appLocalizationsProvider).addProduct),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: const Icon(
                          Icons.storage_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Row(
                          children: [
                            _buildSummaryStat(
                              label: ref.watch(appLocalizationsProvider).totalLabel,
                              value: _allItems.length.toString(),
                              icon: Icons.grid_view,
                            ),
                            _buildSummaryStat(
                              label: ref.watch(appLocalizationsProvider).inStockLabel,
                              value: _allItems
                                  .where((i) => i.quantity > 10 && !i.isExpired)
                                  .length
                                  .toString(),
                              icon: Icons.check_circle_outline,
                            ),
                            _buildSummaryStat(
                              label: ref.watch(appLocalizationsProvider).lowStockLabel,
                              value: _allItems
                                  .where((i) => i.isLowStock && !i.isOutOfStock)
                                  .length
                                  .toString(),
                              icon: Icons.warning_amber_outlined,
                            ),
                            _buildSummaryStat(
                              label: ref.watch(appLocalizationsProvider).expiredLabel,
                              value: _allItems
                                  .where((i) => i.isExpired)
                                  .length
                                  .toString(),
                              icon: Icons.history_toggle_off,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(16),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        decoration: InputDecoration(
                          hintText: ref.watch(appLocalizationsProvider).searchPlaceholder,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _applyFilters();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                        onChanged: (_) => _applyFilters(),
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(16),
                    color: (_selectedManufacturer != 'all' ||
                            _selectedOrganization != 'all')
                        ? Colors.blue
                        : Colors.white,
                    child: IconButton(
                      icon: Icon(
                        Icons.tune,
                        color: (_selectedManufacturer != 'all' ||
                                _selectedOrganization != 'all')
                            ? Colors.white
                            : Colors.grey[700],
                      ),
                      onPressed: _showFiltersDialog,
                      tooltip: ref.watch(appLocalizationsProvider).filters,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: Builder(
                builder: (context) {
                  final statusFilters = _getStatusFilters(ref);
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final entry = statusFilters.entries.elementAt(index);
                      final isActive = _selectedStatus == entry.key;
                      return ChoiceChip(
                        label: Text(entry.value),
                        selected: isActive,
                        onSelected: (_) {
                          setState(() {
                            _selectedStatus = entry.key;
                          });
                          _applyFilters();
                        },
                        selectedColor: Colors.blue.shade100,
                        labelStyle: TextStyle(
                          color: isActive ? Colors.blue[900] : Colors.grey[700],
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: statusFilters.length,
                  );
                },
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadWarehouseItems,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredItems.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inventory_outlined,
                                      size: 72,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchController.text.isEmpty
                                          ? ref.watch(appLocalizationsProvider).warehouseEmpty
                                          : ref.watch(appLocalizationsProvider).noResultsFound,
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: _filteredItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            return _WarehouseItemTile(
                              item: item,
                              onTap: () =>
                                  _showProductDetails(context, item.product),
                              onAction: (value) async {
                                switch (value) {
                                  case 'details':
                                    _showProductDetails(context, item.product);
                                    break;
                                  case 'edit':
                                    await _editProduct(context, item.product);
                                    break;
                                  case 'restock':
                                    await _restockProduct(
                                      context,
                                      item.product,
                                    );
                                    break;
                                  case 'history':
                                    _showStockMovements(context, item.product);
                                    break;
                                }
                              },
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Показать детали товара
  void _showProductDetails(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailsSheet(product: product),
    );
  }

  /// Редактировать товар
  Future<void> _editProduct(BuildContext context, Product product) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditProductSheet(product: product),
    );

    if (result == true) {
      // Обновляем список товаров
      await _loadWarehouseItems();
    }
  }

  /// Пополнить склад
  Future<void> _restockProduct(BuildContext context, Product product) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => RestockDialog(product: product),
    );

    if (result == true) {
      // Обновляем список товаров
      await _loadWarehouseItems();
    }
  }

  /// Показать историю движения товаров
  void _showStockMovements(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StockMovementsScreen(product: product),
      ),
    );
  }
}

class _WarehouseItemTile extends ConsumerWidget {
  final WarehouseItem item;
  final VoidCallback onTap;
  final Function(String) onAction;

  const _WarehouseItemTile({
    required this.item,
    required this.onTap,
    required this.onAction,
  });

  Color _statusColor() {
    if (item.isOutOfStock) return Colors.red;
    if (item.isExpired) return Colors.red;
    if (item.isExpiringSoon) return Colors.orange;
    if (item.isLowStock) return Colors.amber;
    return Colors.green;
  }

  Color _tone(Color color) => Color.lerp(color, Colors.black, 0.3)!;

  String _statusLabel(WidgetRef ref) {
    final loc = ref.watch(appLocalizationsProvider);
    if (item.isExpired) return loc.expiredLabel;
    if (item.isExpiringSoon) return loc.expiredSoon;
    if (item.isOutOfStock) return loc.outOfStock;
    if (item.isLowStock) return loc.lowStockLabel;
    return loc.inStockLabel;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor();
    final statusLabel = _statusLabel(ref);
    final statusTextColor = _tone(statusColor);
    final loc = ref.watch(appLocalizationsProvider);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // TODO: Открыть детальную информацию о товаре
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withOpacity(0.2), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Chip(
                              label: Text(item.inventoryCode),
                              backgroundColor: Colors.teal[50],
                              avatar: const Icon(Icons.tag, size: 18),
                              labelStyle: const TextStyle(fontSize: 12),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            Chip(
                              label: Text(item.manufacturer),
                              backgroundColor: Colors.blueGrey[50],
                              avatar: const Icon(Icons.factory, size: 18),
                              labelStyle: const TextStyle(fontSize: 12),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            Chip(
                              label: Text(item.organization),
                              backgroundColor: Colors.indigo[50],
                              avatar: const Icon(
                                Icons.apartment_rounded,
                                size: 18,
                              ),
                              labelStyle: const TextStyle(fontSize: 12),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            Chip(
                              label: Text(item.shelfLocation),
                              backgroundColor: Colors.orange[50],
                              avatar: const Icon(Icons.storage, size: 18),
                              labelStyle: const TextStyle(fontSize: 12),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            Chip(
                              label: Text(statusLabel),
                              backgroundColor: statusColor.withOpacity(0.15),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: statusTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                              avatar: Icon(
                                item.isExpired
                                    ? Icons.warning_amber_rounded
                                    : Icons.event_available,
                                size: 18,
                                color: statusColor,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: onAction,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18),
                            const SizedBox(width: 8),
                            Text(loc.productDetails),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(loc.edit),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'restock',
                        child: Row(
                          children: [
                            const Icon(Icons.add_circle_outline, size: 18),
                            const SizedBox(width: 8),
                            Text(loc.restock),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'history',
                        child: Row(
                          children: [
                            const Icon(Icons.history, size: 18),
                            const SizedBox(width: 8),
                            Text(loc.stockMovements),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoBadge(
                    icon: Icons.inventory_2,
                    label: loc.packages,
                    value: item.quantity.toString(),
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _InfoBadge(
                    icon: Icons.medication_outlined,
                    label: loc.tablets,
                    value: Formatters.formatNumber(
                      item.totalUnits.toDouble(),
                      decimals: 0,
                    ),
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 12),
                  _InfoBadge(
                    icon: Icons.attach_money,
                    label: loc.priceLabel,
                    value: Formatters.formatMoney(item.sellingPrice),
                    color: Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.barcode,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.product.barcode,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.shelf,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.shelfLocation,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.expiryDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.expiryDate != null
                              ? Formatters.formatDate(item.expiryDate!)
                              : loc.notSpecified,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: item.isExpired
                                ? Colors.red
                                : item.isExpiringSoon
                                ? Colors.deepOrange
                                : Colors.grey[800],
                          ),
                        ),
                      ],
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
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = Color.lerp(color, Colors.black, 0.4)!;
    final valueColor = Color.lerp(color, Colors.black, 0.25)!;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: labelColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
