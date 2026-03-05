import 'package:flutter/material.dart';

import '../../auth/models/user.dart';

/// Элемент списка пользователей
class UserListItem extends StatelessWidget {
  final User user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canDelete;

  const UserListItem({
    super.key,
    required this.user,
    required this.onEdit,
    required this.onDelete,
    this.canDelete = true,
  });

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'cashier':
        return 'Кассир';
      case 'warehouse':
        return 'Склад';
      case 'admin':
        return 'Администратор';
      case 'manager':
        return 'Менеджер';
      default:
        return role;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'cashier':
        return Icons.point_of_sale;
      case 'warehouse':
        return Icons.inventory;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'manager':
        return Icons.business_center;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'cashier':
        return Colors.blue;
      case 'warehouse':
        return Colors.orange;
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role),
          child: Icon(
            _getRoleIcon(user.role),
            color: Colors.white,
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${user.username}'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getRoleColor(user.role).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getRoleColor(user.role).withOpacity(0.3),
                ),
              ),
              child: Text(
                _getRoleLabel(user.role),
                style: TextStyle(
                  color: _getRoleColor(user.role),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
              tooltip: 'Редактировать',
            ),
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: onDelete,
                tooltip: 'Удалить',
                color: Colors.red,
              ),
          ],
        ),
      ),
    );
  }
}

