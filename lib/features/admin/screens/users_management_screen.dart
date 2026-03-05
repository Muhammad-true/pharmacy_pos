import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/providers/auth_notifier.dart';
import '../../../core/providers/repository_providers.dart';
import '../../auth/models/user.dart';
import '../widgets/user_form_dialog.dart';
import '../widgets/user_list_item.dart';

/// Экран управления пользователями (для администратора)
class UsersManagementScreen extends ConsumerStatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  ConsumerState<UsersManagementScreen> createState() =>
      _UsersManagementScreenState();
}

class _UsersManagementScreenState extends ConsumerState<UsersManagementScreen> {
  List<User> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterRole = 'all';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userRepo = ref.read(userRepositoryProvider);
      final users = await userRepo.getAllUsers();

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      ErrorHandler.instance.handleError(e);
      setState(() {
        _errorMessage = 'Ошибка загрузки пользователей: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _editUser(User user) async {
    final result = await showDialog<User>(
      context: context,
      builder: (context) => UserFormDialog(user: user),
    );

    if (result != null && mounted) {
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Пользователь "${result.name}" обновлен'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: Text(
          'Вы уверены, что хотите удалить пользователя "${user.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final userRepo = ref.read(userRepositoryProvider);
        await userRepo.deleteUser(user.id);
        await _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Пользователь "${user.name}" удален'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        ErrorHandler.instance.handleError(e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка удаления пользователя: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  List<User> get _filteredUsers {
    if (_filterRole == 'all') {
      return _users;
    }
    return _users.where((u) => u.role == _filterRole).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider);

    return Column(
      children: [
        // Фильтр по ролям
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Text(
                'Фильтр:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('Все')),
                    ButtonSegment(value: 'cashier', label: Text('Кассиры')),
                    ButtonSegment(value: 'warehouse', label: Text('Склад')),
                    ButtonSegment(value: 'admin', label: Text('Админы')),
                  ],
                  selected: {_filterRole},
                  onSelectionChanged: (Set<String> selected) {
                    setState(() {
                      _filterRole = selected.first;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        // Список пользователей
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUsers,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _filteredUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Пользователи не найдены',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return UserListItem(
                        user: user,
                        onEdit: () => _editUser(user),
                        onDelete: () => _deleteUser(user),
                        canDelete:
                            currentUser?.id != user.id, // Нельзя удалить себя
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
