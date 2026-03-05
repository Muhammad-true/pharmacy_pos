import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/models/user.dart';

/// Диалог создания/редактирования пользователя
class UserFormDialog extends ConsumerStatefulWidget {
  final User? user;

  const UserFormDialog({super.key, this.user});

  @override
  ConsumerState<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String _selectedRole = 'cashier';
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final List<Map<String, String>> _roles = const [
    {'value': 'cashier', 'label': 'Кассир'},
    {'value': 'warehouse', 'label': 'Склад'},
    {'value': 'admin', 'label': 'Администратор'},
    {'value': 'manager', 'label': 'Менеджер'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _usernameController.text = widget.user!.username;
      _nameController.text = widget.user!.name;
      _selectedRole = widget.user!.role;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // При редактировании пароль необязателен
    if (widget.user == null && _passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Пароль обязателен для нового пользователя';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userRepo = ref.read(userRepositoryProvider);
      
      if (widget.user == null) {
        // Создание нового пользователя
        final newUser = User(
          id: 0, // ID будет присвоен БД
          username: _usernameController.text.trim(),
          name: _nameController.text.trim(),
          role: _selectedRole,
        );
        
        // Проверяем, существует ли пользователь
        final exists = await userRepo.userExists(newUser.username);
        if (exists) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Пользователь с именем "${newUser.username}" уже существует';
          });
          return;
        }
        
        await userRepo.createUser(newUser, password: _passwordController.text.trim());
      } else {
        // Обновление существующего пользователя
        final updatedUser = User(
          id: widget.user!.id,
          username: _usernameController.text.trim(),
          name: _nameController.text.trim(),
          role: _selectedRole,
        );
        
        await userRepo.updateUser(updatedUser);
        
        // Если пароль указан, обновляем его
        if (_passwordController.text.trim().isNotEmpty) {
          // TODO: Добавить хэширование пароля
          await userRepo.updateUserPassword(
            widget.user!.id,
            _passwordController.text.trim(),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, User(
          id: widget.user?.id ?? 0,
          username: _usernameController.text.trim(),
          name: _nameController.text.trim(),
          role: _selectedRole,
        ));
      }
    } catch (e) {
      ErrorHandler.instance.handleError(e);
      setState(() {
        _isLoading = false;
        if (e is ValidationException || e is DatabaseException) {
          _errorMessage = e.toString();
        } else {
          _errorMessage = 'Ошибка сохранения пользователя: $e';
        }
      });
    }
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите имя пользователя';
    }
    if (value.trim().length < 3) {
      return 'Имя пользователя должно быть не менее 3 символов';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите имя';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (widget.user == null) {
      // Для нового пользователя пароль обязателен
      if (value == null || value.trim().isEmpty) {
        return 'Введите пароль';
      }
      if (value.trim().length < 3) {
        return 'Пароль должен быть не менее 3 символов';
      }
    } else {
      // При редактировании пароль необязателен, но если указан, должен быть валидным
      if (value != null && value.trim().isNotEmpty && value.trim().length < 3) {
        return 'Пароль должен быть не менее 3 символов';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user == null ? 'Добавить пользователя' : 'Редактировать пользователя'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Имя пользователя',
                  hintText: 'Введите имя пользователя',
                  prefixIcon: Icon(Icons.person),
                ),
                enabled: widget.user == null, // При редактировании нельзя менять username
                validator: _validateUsername,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Имя',
                  hintText: 'Введите полное имя',
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: _validateName,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: widget.user == null ? 'Пароль *' : 'Новый пароль (оставьте пустым, чтобы не менять)',
                  hintText: 'Введите пароль',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: _validatePassword,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Роль',
                  prefixIcon: Icon(Icons.work),
                ),
                items: _roles.map((role) {
                  return DropdownMenuItem<String>(
                    value: role['value'],
                    child: Text(role['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedRole = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.user == null ? 'Создать' : 'Сохранить'),
        ),
      ],
    );
  }
}

