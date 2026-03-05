import '../../features/shared/models/advertisement.dart';

/// Интерфейс репозитория для работы с рекламой
abstract class IAdvertisementRepository {
  /// Получить все рекламы
  Future<List<Advertisement>> getAllAdvertisements();

  /// Получить активные рекламы (можно указать кассира)
  Future<List<Advertisement>> getActiveAdvertisements({int? userId});

  /// Получить рекламу по ID
  Future<Advertisement?> getAdvertisementById(int id);

  /// Создать рекламу
  Future<Advertisement> createAdvertisement(Advertisement advertisement);

  /// Обновить рекламу
  Future<Advertisement> updateAdvertisement(Advertisement advertisement);

  /// Удалить рекламу
  Future<void> deleteAdvertisement(int id);

  /// Активировать/деактивировать рекламу
  Future<void> toggleAdvertisementActive(int id, bool isActive);
}

