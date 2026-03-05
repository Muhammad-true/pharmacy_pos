import 'package:drift/drift.dart';

import '../database.dart';

part 'advertisements_dao.g.dart';

/// DAO для работы с рекламой
@DriftAccessor(tables: [Advertisements])
class AdvertisementsDao extends DatabaseAccessor<AppDatabase>
    with _$AdvertisementsDaoMixin {
  AdvertisementsDao(super.db);

  /// Получить все рекламы
  Future<List<Advertisement>> getAllAdvertisements() async {
    return await (select(advertisements)..orderBy([
          (ad) => OrderingTerm.asc(ad.displayOrder),
          (ad) => OrderingTerm.desc(ad.createdAt),
        ]))
        .get();
  }

  /// Получить активные рекламы (с фильтром по кассиру)
  Future<List<Advertisement>> getActiveAdvertisements({int? userId}) async {
    final query = select(advertisements)
      ..where(
        (ad) {
          final isActive = ad.isActive.equals(true);
          if (userId == null) {
            return isActive;
          }
          return isActive &
              (ad.targetUserId.equals(userId) | ad.targetUserId.isNull());
        },
      )
      ..orderBy([
        (ad) => OrderingTerm.asc(ad.displayOrder),
        (ad) => OrderingTerm.desc(ad.createdAt),
      ]);

    return query.get();
  }

  /// Получить рекламу по ID
  Future<Advertisement?> getAdvertisementById(int id) async {
    return await (select(
      advertisements,
    )..where((ad) => ad.id.equals(id))).getSingleOrNull();
  }

  /// Создать рекламу
  Future<Advertisement> createAdvertisement(
    AdvertisementsCompanion advertisement,
  ) async {
    final id = await into(advertisements).insert(advertisement);
    final created = await getAdvertisementById(id);
    if (created == null) {
      throw Exception('Не удалось получить рекламу после вставки (id=$id)');
    }
    return created;
  }

  /// Обновить рекламу
  Future<bool> updateAdvertisement(
    int id,
    AdvertisementsCompanion advertisement,
  ) async {
    return await (update(
          advertisements,
        )..where((ad) => ad.id.equals(id))).write(advertisement) >
        0;
  }

  /// Удалить рекламу
  Future<bool> deleteAdvertisement(int id) async {
    return await (delete(
          advertisements,
        )..where((ad) => ad.id.equals(id))).go() >
        0;
  }

  /// Активировать/деактивировать рекламу
  Future<bool> toggleAdvertisementActive(int id, bool isActive) async {
    return await (update(advertisements)..where((ad) => ad.id.equals(id)))
            .write(AdvertisementsCompanion(isActive: Value(isActive))) >
        0;
  }
}
