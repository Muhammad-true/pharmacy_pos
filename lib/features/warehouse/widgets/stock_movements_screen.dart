import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/formatters.dart';
import '../../cashier/models/product.dart';
import '../../../core/repositories/stock_movement_repository.dart';
import '../../../core/providers/repository_providers.dart';

/// Экран для просмотра истории движения товаров
class StockMovementsScreen extends ConsumerStatefulWidget {
  final Product product;

  const StockMovementsScreen({
    super.key,
    required this.product,
  });

  @override
  ConsumerState<StockMovementsScreen> createState() => _StockMovementsScreenState();
}

class _StockMovementsScreenState extends ConsumerState<StockMovementsScreen> {
  bool _isLoading = true;
  List<StockMovement> _movements = [];
  Map<int, String> _userNames = {}; // Map userId -> userName

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final repository = StockMovementRepository();
      final movements = await repository.getMovementsByProductId(widget.product.id);
      
      // Получаем уникальные userId из движений
      final userIds = movements
          .where((m) => m.userId != null)
          .map((m) => m.userId!)
          .toSet()
          .toList();
      
      // Загружаем имена пользователей
      final userRepo = ref.read(userRepositoryProvider);
      final userNames = <int, String>{};
      for (final userId in userIds) {
        try {
          final user = await userRepo.getUserById(userId);
          if (user != null) {
            userNames[userId] = user.name;
          }
        } catch (e) {
          // Игнорируем ошибки получения пользователя
        }
      }
      
      setState(() {
        _movements = movements;
        _userNames = userNames;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки истории: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getMovementTypeText(String type) {
    switch (type) {
      case 'in':
        return 'Поступление';
      case 'out':
        return 'Продажа';
      case 'adjustment':
        return 'Корректировка';
      default:
        return type;
    }
  }

  IconData _getMovementTypeIcon(String type) {
    switch (type) {
      case 'in':
        return Icons.add_circle;
      case 'out':
        return Icons.remove_circle;
      case 'adjustment':
        return Icons.edit;
      default:
        return Icons.info;
    }
  }

  Color _getMovementTypeColor(String type) {
    switch (type) {
      case 'in':
        return Colors.green;
      case 'out':
        return Colors.red;
      case 'adjustment':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('История движения'),
            Text(
              widget.product.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[200],
                  ),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _movements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 72,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'История движения пуста',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMovements,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _movements.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final movement = _movements[index];
                      final typeColor = _getMovementTypeColor(movement.movementType);
                      final typeIcon = _getMovementTypeIcon(movement.movementType);
                      final isIncoming = movement.movementType == 'in';

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: typeColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: typeColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      typeIcon,
                                      color: typeColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getMovementTypeText(movement.movementType),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: typeColor,
                                          ),
                                        ),
                                        Text(
                                          Formatters.formatDateTime(movement.createdAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isIncoming
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${isIncoming ? '+' : ''}${movement.quantity}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isIncoming ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _InfoItem(
                                      label: 'Было',
                                      value: '${movement.stockBefore} ${widget.product.unit}',
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                                  Expanded(
                                    child: _InfoItem(
                                      label: 'Стало',
                                      value: '${movement.stockAfter} ${widget.product.unit}',
                                    ),
                                  ),
                                ],
                              ),
                              if (movement.price != null) ...[
                                const SizedBox(height: 8),
                                _InfoItem(
                                  label: 'Цена',
                                  value: Formatters.formatMoney(movement.price!),
                                ),
                              ],
                              if (movement.userId != null && _userNames.containsKey(movement.userId)) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Text(
                                      _userNames[movement.userId]!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (movement.notes != null && movement.notes!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.note_outlined, size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          movement.notes!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

