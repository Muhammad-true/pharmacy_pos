import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/settings_notifier.dart';
import '../../../features/shared/models/advertisement.dart';

/// Виджет для отображения рекламы, когда чек пустой
/// Поддерживает видео и GIF из базы данных
class AdBanner extends ConsumerStatefulWidget {
  final String? pharmacyName;
  final int? targetUserId;

  const AdBanner({super.key, this.pharmacyName, this.targetUserId});

  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner> {
  Advertisement? _advertisement;
  bool _isLoading = true;
  VideoPlayerController? _videoController;
  bool _videoError = false;

  @override
  void initState() {
    super.initState();
    _loadAdvertisement();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadAdvertisement() async {
    try {
      final repository = ref.read(advertisementRepositoryProvider);
      final ads = await repository.getActiveAdvertisements(
        userId: widget.targetUserId,
      );
      if (!mounted) return;

      if (ads.isNotEmpty) {
        final firstAd = ads.first;
        setState(() {
          _advertisement = firstAd; // Берем первую активную рекламу
          _isLoading = false;
        });
        await _prepareMedia(firstAd);
      } else {
        setState(() {
          _advertisement = null;
          _isLoading = false;
        });
        _disposeVideo();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _disposeVideo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final settingsAsync = ref.watch(appSettingsStateProvider);
    final defaultPharmacyName = settingsAsync.maybeWhen(
      data: (settings) => settings.pharmacyName,
      orElse: () => 'Аптека Хушдил',
    );
    final pharmacyName = widget.pharmacyName ?? defaultPharmacyName;
    
    if (_isLoading) {
      return Container(
        width: screenSize.width,
        height: screenSize.height,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    
    return Container(
      width: screenSize.width,
      height: screenSize.height,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Рекламное видео/GIF на весь экран
          _buildAdMedia(),
          // Заголовок поверх рекламы
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/img/logo.PNG',
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                    Icons.local_pharmacy,
                    color: Colors.white,
                    size: 32,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text(
                        'libiss pos',
                    style: const TextStyle(
                          fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                      ),
                      Text(
                        pharmacyName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Градиентный оверлей снизу для информации
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Информация из рекламы или дефолтная
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _advertisement != null
                        ? _buildAdvertisementContent(_advertisement!)
                        : _buildDefaultContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAdvertisementContent(Advertisement ad) {
    return Column(
      children: [
        // Заголовок рекламы
        if (ad.title.isNotEmpty) ...[
          Text(
            ad.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],
        // Описание
        if (ad.description != null && ad.description!.isNotEmpty) ...[
          Text(
            ad.description!,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],
        // Текст скидки
        if (ad.discountText != null && ad.discountText!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.discount, color: Colors.green[800], size: 20),
                const SizedBox(width: 8),
                Text(
                  ad.discountText!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        // QR код
        if (ad.qrCodeText != null && ad.qrCodeText!.isNotEmpty) ...[
          QrImageView(
            data: ad.qrCodeText!,
            version: QrVersions.auto,
            size: 120,
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
          const SizedBox(height: 8),
          Text(
            'Отсканируйте QR код',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildDefaultContent() {
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Преимущества постоянных клиентов',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildBenefitItem(
          Icons.discount,
          'Скидки до 15%',
          'Для постоянных клиентов',
        ),
        const SizedBox(height: 12),
        _buildBenefitItem(
          Icons.stars,
          'Накопление бонусов',
          '5% от суммы покупки',
        ),
        const SizedBox(height: 12),
        _buildBenefitItem(
          Icons.card_giftcard,
          'Специальные предложения',
          'Эксклюзивные акции',
        ),
      ],
    );
  }

  /// Создает виджет для отображения рекламного медиа (GIF или видео)
  Widget _buildAdMedia() {
    if (_advertisement == null || _advertisement!.mediaUrl == null) {
      return _buildFallbackAd();
    }

    final mediaUrl = _advertisement!.mediaUrl!;
    final mediaType = _advertisement!.mediaType;

    // Проверяем, является ли это локальным файлом
    final isLocalFile = !mediaUrl.startsWith('http://') && !mediaUrl.startsWith('https://');

    if (mediaType == 'video') {
      return _buildVideoPlayer();
    }

    if (isLocalFile) {
      // Локальный файл
      final file = File(mediaUrl);
      if (!file.existsSync()) {
        return _buildFallbackAd();
      }

      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackAd();
        },
      );
    } else {
      // URL (сеть)
      return Image.network(
        mediaUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackAd();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return Container(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _prepareMedia(Advertisement ad) async {
    if (ad.mediaType != 'video' || ad.mediaUrl == null) {
      _disposeVideo();
      return;
    }

    final mediaUrl = ad.mediaUrl!;
    final isLocalFile =
        !mediaUrl.startsWith('http://') && !mediaUrl.startsWith('https://');

    VideoPlayerController controller;
    if (isLocalFile) {
      final file = File(mediaUrl);
      if (!file.existsSync()) {
        _videoError = true;
        if (mounted) setState(() {});
        return;
      }
      controller = VideoPlayerController.file(file);
    } else {
      controller = VideoPlayerController.networkUrl(Uri.parse(mediaUrl));
    }

    _videoController?.dispose();
    _videoController = controller;
    _videoError = false;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _videoError = true;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
    _videoError = false;
  }

  Widget _buildVideoPlayer() {
    if (_videoError) {
      return _buildVideoPlaceholder(
        icon: Icons.error_outline,
        message: 'Видео недоступно',
      );
    }

    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return _buildVideoPlaceholder(
        icon: Icons.video_library,
        message: 'Загрузка видео...',
        showLoader: true,
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _buildVideoPlaceholder({
    required IconData icon,
    required String message,
    bool showLoader = false,
  }) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            if (showLoader) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }

  /// Резервный вариант рекламы, если медиа не загрузилось
  Widget _buildFallbackAd() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_pharmacy,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Добро пожаловать!',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Специальные предложения и акции для наших клиентов',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.9),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFF1976D2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

