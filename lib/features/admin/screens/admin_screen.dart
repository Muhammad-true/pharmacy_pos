import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_notifier.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../utils/formatters.dart';
import '../../auth/models/user.dart';
import '../../auth/screens/login_screen.dart';
import '../../warehouse/screens/warehouse_screen.dart';
import '../../warehouse/widgets/add_product_sheet.dart';
import '../widgets/user_form_dialog.dart';
import 'advertisements_management_screen.dart';
import 'clients_screen.dart';
import 'out_of_stock_screen.dart';
import 'online_sales_screen.dart';
import 'purchase_requests_screen.dart';
import 'receipts_history_screen.dart';
import 'settings_screen.dart';
import 'shifts_history_screen.dart';
import 'updates_screen.dart';
import 'users_management_screen.dart';

/// Главный экран администратора
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  int _selectedIndex = 0;
  int _warehouseRefreshKey = 0; // Ключ для пересоздания WarehouseScreen
  int _usersRefreshKey = 0; // Ключ для пересоздания UsersManagementScreen

  List<String> _getTitles(WidgetRef ref) {
    final loc = ref.watch(appLocalizationsProvider);
    return [
      loc.dashboard,
      loc.onlineSales,
      loc.manageUsers,
      loc.clients,
      loc.manageWarehouse,
      loc.outOfStock,
      loc.purchaseRequests,
      loc.shiftsHistory,
      loc.receiptsHistory,
      loc.advertisements,
      loc.updates,
      loc.settings,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider);
    final titles = _getTitles(ref);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titles[_selectedIndex]),
            if (currentUser != null)
              Text(
                '${ref.watch(appLocalizationsProvider).admin}: ${currentUser.name}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: ref.watch(appLocalizationsProvider).refresh,
            onPressed: () {
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: ref.watch(appLocalizationsProvider).exit,
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Row(
        children: [
          // Боковая навигация
          SizedBox(
            width: 240,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  label: ref.watch(appLocalizationsProvider).dashboard,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.cloud_outlined,
                  selectedIcon: Icons.cloud,
                  label: ref.watch(appLocalizationsProvider).onlineSales,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.people_outline,
                  selectedIcon: Icons.people,
                  label: ref.watch(appLocalizationsProvider).users,
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: ref.watch(appLocalizationsProvider).clients,
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.inventory_2_outlined,
                  selectedIcon: Icons.inventory_2,
                  label: ref.watch(appLocalizationsProvider).warehouse,
                ),
                _buildNavItem(
                  index: 5,
                  icon: Icons.error_outline,
                  selectedIcon: Icons.error,
                  label: ref.watch(appLocalizationsProvider).outOfStock,
                ),
                _buildNavItem(
                  index: 6,
                  icon: Icons.assignment_outlined,
                  selectedIcon: Icons.assignment,
                  label: ref.watch(appLocalizationsProvider).purchaseRequests,
                ),
                _buildNavItem(
                  index: 7,
                  icon: Icons.schedule_outlined,
                  selectedIcon: Icons.schedule,
                  label: ref.watch(appLocalizationsProvider).shiftsHistory,
                ),
                _buildNavItem(
                  index: 8,
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long,
                  label: ref.watch(appLocalizationsProvider).receiptsHistory,
                ),
                _buildNavItem(
                  index: 9,
                  icon: Icons.ad_units_outlined,
                  selectedIcon: Icons.ad_units,
                  label: ref.watch(appLocalizationsProvider).advertisements,
                ),
                _buildNavItem(
                  index: 10,
                  icon: Icons.system_update_outlined,
                  selectedIcon: Icons.system_update,
                  label: ref.watch(appLocalizationsProvider).updates,
                ),
                _buildNavItem(
                  index: 11,
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: ref.watch(appLocalizationsProvider).settings,
                ),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Основной контент
          Expanded(child: _buildScreenContent()),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildScreenContent() {
    switch (_selectedIndex) {
      case 0:
        return _AdminDashboard(
          onNavigateToUsers: () => setState(() => _selectedIndex = 2),
          onNavigateToWarehouse: () => setState(() => _selectedIndex = 4),
        );
      case 1:
        return const OnlineSalesScreen();
      case 2:
        return UsersManagementScreen(key: ValueKey('users_$_usersRefreshKey'));
      case 3:
        return const ClientsScreen();
      case 4:
        return WarehouseScreen(
          key: ValueKey('warehouse_$_warehouseRefreshKey'),
        );
      case 5:
        return const OutOfStockScreen();
      case 6:
        return const PurchaseRequestsScreen();
      case 7:
        return const ShiftsHistoryScreen();
      case 8:
        return const ReceiptsHistoryScreen();
      case 9:
        return const AdvertisementsManagementScreen();
      case 10:
        return const UpdatesScreen();
      case 11:
        return const SettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget? _buildFloatingActionButton() {
    if (_selectedIndex == 2) {
      // Кнопки для управления пользователями
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'quick_create_users',
            onPressed: () {
              // Найдем UsersManagementScreen и вызовем метод
              final context = this.context;
              final scaffoldState = Scaffold.maybeOf(context);
              if (scaffoldState != null) {
                // Открываем меню быстрого создания
                _showQuickCreateUsersMenu(context);
              }
            },
            tooltip: ref.watch(appLocalizationsProvider).quickCreate,
            child: const Icon(Icons.add_circle_outline),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'create_user',
            onPressed: () {
              _showCreateUserDialog(context);
            },
            icon: const Icon(Icons.person_add),
            label: Text(ref.watch(appLocalizationsProvider).createUser),
          ),
        ],
      );
    } else if (_selectedIndex == 4) {
      // Кнопка для добавления товара на склад
      return FloatingActionButton.extended(
        heroTag: 'admin_add_product',
        onPressed: () {
          _showAddProductSheet(context);
        },
        icon: const Icon(Icons.add),
        label: Text(ref.watch(appLocalizationsProvider).addProduct),
      );
    }
    return null;
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(isSelected ? selectedIcon : icon),
      title: Text(label),
      selected: isSelected,
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
    );
  }

  void _showQuickCreateUsersMenu(BuildContext context) {
    final loc = ref.watch(appLocalizationsProvider);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                loc.quickCreate,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.point_of_sale, color: Colors.blue),
              title: Text(loc.cashier1),
              subtitle: Text(
                loc.createUserCashier1,
              ),
              onTap: () {
                Navigator.pop(context);
                _quickCreateUser(
                  context,
                  'cashier1',
                  loc.cashier1,
                  'cashier',
                  'cashier1',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.point_of_sale, color: Colors.blue),
              title: Text(loc.cashier2),
              subtitle: Text(
                loc.createUserCashier2,
              ),
              onTap: () {
                Navigator.pop(context);
                _quickCreateUser(
                  context,
                  'cashier2',
                  loc.cashier2,
                  'cashier',
                  'cashier2',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory, color: Colors.orange),
              title: Text(loc.warehouse1),
              subtitle: Text(
                loc.createUserWarehouse1,
              ),
              onTap: () {
                Navigator.pop(context);
                _quickCreateUser(
                  context,
                  'warehouse1',
                  loc.warehouse1,
                  'warehouse',
                  'warehouse1',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory, color: Colors.orange),
              title: Text(loc.warehouse2),
              subtitle: Text(
                loc.createUserWarehouse2,
              ),
              onTap: () {
                Navigator.pop(context);
                _quickCreateUser(
                  context,
                  'warehouse2',
                  loc.warehouse2,
                  'warehouse',
                  'warehouse2',
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _quickCreateUser(
    BuildContext context,
    String username,
    String name,
    String role,
    String password,
  ) async {
    try {
      final userRepo = ref.read(userRepositoryProvider);

      // Проверяем, существует ли пользователь
      final exists = await userRepo.userExists(username);
      if (exists) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${ref.watch(appLocalizationsProvider).userExists}: "$username"',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Создаем пользователя
      final newUser = User(id: 0, username: username, name: name, role: role);

      await userRepo.createUser(newUser, password: password);

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${ref.watch(appLocalizationsProvider).userCreated}: "$name"',
          ),
          backgroundColor: Colors.green,
        ),
      );
      // Обновляем экран пользователей, увеличивая ключ для пересоздания виджета
      setState(() {
        _usersRefreshKey++;
      });
    } catch (e) {
      ErrorHandler.instance.handleError(e);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${ref.watch(appLocalizationsProvider).userCreationError}: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCreateUserDialog(BuildContext context) async {
    // Импортируем UserFormDialog
    final result = await showDialog<User>(
      context: context,
      builder: (context) => const UserFormDialog(),
    );

    if (result != null && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${ref.watch(appLocalizationsProvider).userCreated}: "${result.name}"',
          ),
          backgroundColor: Colors.green,
        ),
      );
      // Обновляем экран пользователей, увеличивая ключ для пересоздания виджета
      setState(() {
        _usersRefreshKey++;
      });
    }
  }

  void _showAddProductSheet(BuildContext context) async {
    final result = await showModalBottomSheet<AddProductResult?>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AddProductSheet(manufacturers: const [], organizations: const []),
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
          notes: 'Добавление товара через админ-панель',
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
        await productRepo.createProduct(product, userId: userId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${ref.watch(appLocalizationsProvider).productAddedToWarehouse}: "${product.name}"',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Обновляем экран склада, увеличивая ключ для пересоздания виджета
      if (mounted) {
        setState(() {
          _warehouseRefreshKey++;
        });
      }
    } catch (e) {
      ErrorHandler.instance.handleError(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${ref.watch(appLocalizationsProvider).productAddError}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
}

/// Дашборд администратора
class _AdminDashboard extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToUsers;
  final VoidCallback onNavigateToWarehouse;

  const _AdminDashboard({
    required this.onNavigateToUsers,
    required this.onNavigateToWarehouse,
  });

  @override
  ConsumerState<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<_AdminDashboard> {
  // Общая статистика
  int _usersCount = 0;
  int _productsCount = 0;
  int _clientsCount = 0;

  // Статистика продаж
  double _todayRevenue = 0.0;
  double _weekRevenue = 0.0;
  double _monthRevenue = 0.0;
  int _todayReceipts = 0;
  int _weekReceipts = 0;
  int _monthReceipts = 0;
  double _averageReceipt = 0.0;
  int _activeShifts = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userRepo = ref.read(userRepositoryProvider);
      final productRepo = ref.read(productRepositoryProvider);
      final clientRepo = ref.read(clientRepositoryProvider);
      final receiptRepo = ref.read(receiptRepositoryProvider);
      final shiftRepo = ref.read(shiftRepositoryProvider);

      // Общая статистика
      final users = await userRepo.getAllUsers();
      final products = await productRepo.getAllProducts();
      final clients = await clientRepo.getAllClients();

      // Статистика продаж
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final weekEnd = now;
      final monthEnd = now;

      final todayStats = await receiptRepo.getReceiptsStatistics(
        todayStart,
        todayEnd,
      );
      final weekStats = await receiptRepo.getReceiptsStatistics(
        weekStart,
        weekEnd,
      );
      final monthStats = await receiptRepo.getReceiptsStatistics(
        monthStart,
        monthEnd,
      );

      // Активные смены
      final allUsers = await userRepo.getAllUsers();
      int activeShiftsCount = 0;
      for (final user in allUsers) {
        final activeShift = await shiftRepo.getActiveShift(user.id);
        if (activeShift != null) {
          activeShiftsCount++;
        }
      }

      if (!mounted) return;
      setState(() {
        _usersCount = users.length;
        _productsCount = products.length;
        _clientsCount = clients.length;

        _todayRevenue = (todayStats['totalAmount'] as num?)?.toDouble() ?? 0.0;
        _weekRevenue = (weekStats['totalAmount'] as num?)?.toDouble() ?? 0.0;
        _monthRevenue = (monthStats['totalAmount'] as num?)?.toDouble() ?? 0.0;
        _todayReceipts = todayStats['receiptsCount'] as int? ?? 0;
        _weekReceipts = weekStats['receiptsCount'] as int? ?? 0;
        _monthReceipts = monthStats['receiptsCount'] as int? ?? 0;
        _averageReceipt =
            (monthStats['averageAmount'] as num?)?.toDouble() ?? 0.0;
        _activeShifts = activeShiftsCount;

        _isLoading = false;
      });
    } catch (e) {
      ErrorHandler.instance.handleError(e);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(appLocalizationsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.dashboard,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc.welcomeToPharmacy,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadStatistics,
                tooltip: loc.refresh,
              ),
            ],
          ),
          const SizedBox(height: 32),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Общая статистика
                Text(
                  loc.generalStatistics,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: loc.users,
                        value: _usersCount.toString(),
                        icon: Icons.people,
                        color: Colors.blue,
                        onTap: widget.onNavigateToUsers,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: loc.products,
                        value: _productsCount.toString(),
                        icon: Icons.inventory_2,
                        color: Colors.green,
                        onTap: widget.onNavigateToWarehouse,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: loc.clientsCount,
                        value: _clientsCount.toString(),
                        icon: Icons.person_outline,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: loc.activeShifts,
                        value: _activeShifts.toString(),
                        icon: Icons.schedule,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Статистика продаж
                Text(
                  loc.salesStatistics,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Выручка
                Row(
                  children: [
                    Expanded(
                      child: _RevenueCard(
                        title: loc.todayRevenue,
                        subtitle: loc.today,
                        value: _todayRevenue,
                        receipts: _todayReceipts,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RevenueCard(
                        title: loc.weekRevenue,
                        subtitle: loc.thisWeek,
                        value: _weekRevenue,
                        receipts: _weekReceipts,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RevenueCard(
                        title: loc.monthRevenue,
                        subtitle: loc.thisMonth,
                        value: _monthRevenue,
                        receipts: _monthReceipts,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Средний чек
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: loc.averageReceipt,
                        value: Formatters.formatMoney(_averageReceipt),
                        icon: Icons.receipt_long,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Быстрые действия
                Text(
                  loc.quickActions,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _ActionCard(
                      title: loc.manageUsers,
                      icon: Icons.people,
                      color: Colors.blue,
                      onTap: widget.onNavigateToUsers,
                    ),
                    _ActionCard(
                      title: loc.manageWarehouse,
                      icon: Icons.inventory_2,
                      color: Colors.green,
                      onTap: widget.onNavigateToWarehouse,
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Карточка статистики
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Карточка выручки
class _RevenueCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final int receipts;
  final Color color;

  const _RevenueCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.receipts,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final loc = ref.watch(appLocalizationsProvider);

        return Card(
          elevation: 2,
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.attach_money, color: color, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  Formatters.formatMoney(value),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$receipts ${loc.receipt}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Карточка действия
class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
