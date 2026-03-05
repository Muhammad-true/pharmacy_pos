import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../features/shared/models/advertisement.dart';
import '../../auth/models/user.dart';

/// Диалог для создания/редактирования рекламы
class AdvertisementFormDialog extends ConsumerStatefulWidget {
  final Advertisement? advertisement;
  final int? createdByUserId;

  const AdvertisementFormDialog({
    super.key,
    this.advertisement,
    this.createdByUserId,
  });

  @override
  ConsumerState<AdvertisementFormDialog> createState() =>
      _AdvertisementFormDialogState();
}

class _AdvertisementFormDialogState
    extends ConsumerState<AdvertisementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _mediaUrlController = TextEditingController();
  final _discountTextController = TextEditingController();
  final _qrCodeTextController = TextEditingController();
  
  String _mediaType = 'gif';
  String? _qrCodeBase64;
  bool _isLoading = false;
  bool _cashiersLoading = false;
  List<User> _cashiers = [];
  int? _selectedCashierId;

  @override
  void initState() {
    super.initState();
    if (widget.advertisement != null) {
      final ad = widget.advertisement!;
      _titleController.text = ad.title;
      _descriptionController.text = ad.description ?? '';
      _mediaUrlController.text = ad.mediaUrl ?? '';
      _discountTextController.text = ad.discountText ?? '';
      _qrCodeTextController.text = ad.qrCodeText ?? '';
      _mediaType = ad.mediaType;
      _qrCodeBase64 = ad.qrCode;
      _selectedCashierId = ad.targetUserId;
    }
    _loadCashiers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _mediaUrlController.dispose();
    _discountTextController.dispose();
    _qrCodeTextController.dispose();
    super.dispose();
  }

  Future<void> _pickMediaFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gif', 'mp4', 'mov', 'jpg', 'jpeg', 'png', 'webp'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name.toLowerCase();
        
        // Определяем тип медиа по расширению
        String mediaType = 'gif';
        if (fileName.endsWith('.mp4') || fileName.endsWith('.mov')) {
          mediaType = 'video';
        } else if (fileName.endsWith('.jpg') ||
            fileName.endsWith('.jpeg') ||
            fileName.endsWith('.png') ||
            fileName.endsWith('.webp')) {
          mediaType = 'image';
        } else if (fileName.endsWith('.gif')) {
          mediaType = 'gif';
        }

        // Копируем файл в директорию приложения
        final appDir = await getApplicationDocumentsDirectory();
        final adsDir = Directory(path.join(appDir.path, 'advertisements'));
        if (!await adsDir.exists()) {
          await adsDir.create(recursive: true);
        }

        final fileNameOnly = path.basename(filePath);
        final destPath = path.join(adsDir.path, fileNameOnly);
        final sourceFile = File(filePath);
        await sourceFile.copy(destPath);

        setState(() {
          _mediaUrlController.text = destPath;
          _mediaType = mediaType;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка выбора файла: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _generateQRCode() {
    final text = _qrCodeTextController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите текст для QR кода'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Сохраняем текст, QR код будет генерироваться при отображении в AdBanner
    setState(() {
      _qrCodeBase64 = text;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR код будет сгенерирован при отображении'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _loadCashiers() async {
    setState(() => _cashiersLoading = true);
    try {
      final userRepository = ref.read(userRepositoryProvider);
      final cashiers = await userRepository.getUsersByRole('cashier');
      if (!mounted) return;
      setState(() {
        _cashiers = cashiers;
        _cashiersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cashiersLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось загрузить кассиров: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMediaPreview() {
    final mediaUrl = _mediaUrlController.text.trim();
    if (mediaUrl.isEmpty) {
      return const Center(
        child: Icon(Icons.perm_media, size: 48, color: Colors.grey),
      );
    }

    final isLocalFile = !mediaUrl.startsWith('http://') && !mediaUrl.startsWith('https://');

    if (_mediaType == 'video') {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Видео файл', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (isLocalFile) {
      final file = File(mediaUrl);
      if (!file.existsSync()) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 48, color: Colors.red),
              SizedBox(height: 8),
              Text('Файл не найден', style: TextStyle(color: Colors.red)),
            ],
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.error, color: Colors.red),
            );
          },
        ),
      );
    } else {
      // URL из интернета
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          mediaUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 48, color: Colors.red),
                  SizedBox(height: 8),
                  Text('Ошибка загрузки', style: TextStyle(color: Colors.red)),
                ],
              ),
            );
          },
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(advertisementRepositoryProvider);
      
      final advertisement = Advertisement(
        id: widget.advertisement?.id ?? 0,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        mediaUrl: _mediaUrlController.text.trim().isEmpty
            ? null
            : _mediaUrlController.text.trim(),
        mediaType: _mediaType,
        discountText: _discountTextController.text.trim().isEmpty
            ? null
            : _discountTextController.text.trim(),
        qrCode: _qrCodeBase64,
        qrCodeText: _qrCodeTextController.text.trim().isEmpty
            ? null
            : _qrCodeTextController.text.trim(),
        isActive: widget.advertisement?.isActive ?? true,
        displayOrder: widget.advertisement?.displayOrder ?? 0,
        createdByUserId: widget.advertisement?.createdByUserId ?? widget.createdByUserId,
        targetUserId: _selectedCashierId,
        createdAt: widget.advertisement?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.advertisement == null) {
        await repository.createAdvertisement(advertisement);
      } else {
        await repository.updateAdvertisement(advertisement);
      }

      if (mounted) {
        Navigator.of(context).pop(advertisement);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 800),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Заголовок
                Row(
                  children: [
                    Icon(
                      Icons.ad_units,
                      color: const Color(0xFF1976D2),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.advertisement == null
                          ? 'Создать рекламу'
                          : 'Редактировать рекламу',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Кассир / окно кассира
                DropdownButtonFormField<int?>(
                  value: _selectedCashierId,
                  decoration: const InputDecoration(
                    labelText: 'Кассир (опционально)',
                    hintText: 'Выберите кассу, где будет реклама',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Все кассы'),
                    ),
                    ..._cashiers.map(
                      (user) => DropdownMenuItem(
                        value: user.id,
                        child: Text(
                          user.name.isNotEmpty ? user.name : user.username,
                        ),
                      ),
                    ),
                  ],
                  onChanged: _cashiersLoading
                      ? null
                      : (value) {
                          setState(() => _selectedCashierId = value);
                        },
                  isExpanded: true,
                ),
                const SizedBox(height: 16),

                // Название
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Название *',
                    hintText: 'Введите название рекламы',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите название';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Описание
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    hintText: 'Введите описание рекламы',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Медиа файл
                TextFormField(
                  controller: _mediaUrlController,
                  decoration: InputDecoration(
                    labelText: 'Видео/GIF/Изображение (URL или путь)',
                    hintText: 'Введите URL или выберите файл',
                    prefixIcon: const Icon(Icons.perm_media),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.link),
                          onPressed: () {
                            // Разрешаем редактирование для ввода URL
                            setState(() {});
                          },
                          tooltip: 'Ввести URL',
                        ),
                        IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: _pickMediaFile,
                          tooltip: 'Выбрать файл',
                        ),
                      ],
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    // Автоматически определяем тип медиа по расширению или URL
                    if (value.isNotEmpty) {
                      final lowerValue = value.toLowerCase();
                      if (lowerValue.endsWith('.mp4') || lowerValue.endsWith('.mov') || lowerValue.contains('video')) {
                        setState(() => _mediaType = 'video');
                      } else if (lowerValue.endsWith('.jpg') || lowerValue.endsWith('.jpeg') || 
                                 lowerValue.endsWith('.png') || lowerValue.endsWith('.webp') ||
                                 lowerValue.contains('image')) {
                        setState(() => _mediaType = 'image');
                      } else if (lowerValue.endsWith('.gif') || lowerValue.contains('gif')) {
                        setState(() => _mediaType = 'gif');
                      }
                    }
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Тип медиа: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _mediaType,
                      items: const [
                        DropdownMenuItem(value: 'gif', child: Text('GIF')),
                        DropdownMenuItem(value: 'video', child: Text('Видео')),
                        DropdownMenuItem(value: 'image', child: Text('Изображение')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _mediaType = value);
                        }
                      },
                    ),
                  ],
                ),
                if (_mediaUrlController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[100],
                    ),
                    child: _buildMediaPreview(),
                  ),
                ],
                const SizedBox(height: 16),

                // Текст скидки
                TextFormField(
                  controller: _discountTextController,
                  decoration: const InputDecoration(
                    labelText: 'Текст скидки',
                    hintText: 'Например: Скидка 15%',
                    prefixIcon: Icon(Icons.discount),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // QR код
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qrCodeTextController,
                        decoration: const InputDecoration(
                          labelText: 'Текст для QR кода',
                          hintText: 'Введите текст для QR кода',
                          prefixIcon: Icon(Icons.qr_code),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _generateQRCode,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Сгенерировать'),
                    ),
                  ],
                ),
                if (_qrCodeBase64 != null && _qrCodeBase64!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: QrImageView(
                      data: _qrCodeBase64!,
                      version: QrVersions.auto,
                      size: 150,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Кнопки
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(widget.advertisement == null
                              ? 'Создать'
                              : 'Сохранить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

