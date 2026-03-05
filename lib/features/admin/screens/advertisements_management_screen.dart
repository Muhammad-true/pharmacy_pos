import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_notifier.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../features/shared/models/advertisement.dart';
import '../widgets/advertisement_form_dialog.dart';

/// Экран управления рекламой
class AdvertisementsManagementScreen extends ConsumerStatefulWidget {
  const AdvertisementsManagementScreen({super.key});

  @override
  ConsumerState<AdvertisementsManagementScreen> createState() =>
      _AdvertisementsManagementScreenState();
}

class _AdvertisementsManagementScreenState
    extends ConsumerState<AdvertisementsManagementScreen> {
  List<Advertisement> _advertisements = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Загружаем данные после того, как виджет полностью построен
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAdvertisements();
    });
  }

  Future<void> _loadAdvertisements() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final repository = ref.read(advertisementRepositoryProvider);
      final ads = await repository.getAllAdvertisements();
      if (mounted) {
        setState(() {
          _advertisements = ads;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки рекламы: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createAdvertisement() async {
    final currentUser = ref.read(authStateProvider);
    final result = await showDialog<Advertisement>(
      context: context,
      builder: (context) =>
          AdvertisementFormDialog(createdByUserId: currentUser?.id),
    );

    if (result != null && mounted) {
      await _loadAdvertisements();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Реклама создана'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _editAdvertisement(Advertisement advertisement) async {
    final result = await showDialog<Advertisement>(
      context: context,
      builder: (context) =>
          AdvertisementFormDialog(advertisement: advertisement),
    );

    if (result != null && mounted) {
      await _loadAdvertisements();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Реклама обновлена'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteAdvertisement(Advertisement advertisement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить рекламу?'),
        content: Text(
          'Вы уверены, что хотите удалить рекламу "${advertisement.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repository = ref.read(advertisementRepositoryProvider);
        await repository.deleteAdvertisement(advertisement.id);
        await _loadAdvertisements();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Реклама удалена'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка удаления: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleActive(Advertisement advertisement) async {
    try {
      final repository = ref.read(advertisementRepositoryProvider);
      await repository.toggleAdvertisementActive(
        advertisement.id,
        !advertisement.isActive,
      );
      await _loadAdvertisements();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              advertisement.isActive
                  ? 'Реклама деактивирована'
                  : 'Реклама активирована',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _advertisements.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.ad_units_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Реклама не найдена',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Нажмите кнопку "+" чтобы создать рекламу',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _advertisements.length,
              itemBuilder: (context, index) {
                final ad = _advertisements[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: ad.isActive ? Colors.green : Colors.grey,
                      child: Icon(
                        ad.mediaType == 'video'
                            ? Icons.video_library
                            : ad.mediaType == 'image'
                            ? Icons.image
                            : Icons.gif,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      ad.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: ad.isActive
                            ? TextDecoration.none
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ad.description != null) ...[
                          const SizedBox(height: 4),
                          Text(ad.description!),
                        ],
                        if (ad.discountText != null) ...[
                          const SizedBox(height: 4),
                          Chip(
                            label: Text(ad.discountText!),
                            backgroundColor: Colors.green[100],
                            labelStyle: TextStyle(
                              color: Colors.green[800],
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_pin_circle,
                              size: 16,
                              color: Colors.blueGrey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ad.targetUserId == null
                                  ? 'Все кассы'
                                  : 'Кассир ID: ${ad.targetUserId}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              ad.isActive ? Icons.check_circle : Icons.cancel,
                              size: 16,
                              color: ad.isActive ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ad.isActive ? 'Активна' : 'Неактивна',
                              style: TextStyle(
                                color: ad.isActive ? Colors.green : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            ad.isActive
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: ad.isActive ? Colors.grey : Colors.green,
                          ),
                          onPressed: () => _toggleActive(ad),
                          tooltip: ad.isActive
                              ? 'Деактивировать'
                              : 'Активировать',
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editAdvertisement(ad),
                          tooltip: 'Редактировать',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteAdvertisement(ad),
                          tooltip: 'Удалить',
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'advertisements_add',
        onPressed: _createAdvertisement,
        tooltip: 'Создать рекламу',
        child: const Icon(Icons.add),
      ),
    );
  }
}
