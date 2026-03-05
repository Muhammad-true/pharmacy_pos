import 'package:drift/drift.dart';

import '../database.dart';

part 'shifts_dao.g.dart';

/// DAO для работы с таблицей смен
@DriftAccessor(tables: [Shifts])
class ShiftsDao extends DatabaseAccessor<AppDatabase> with _$ShiftsDaoMixin {
  ShiftsDao(super.db);

  /// Получить активную смену для пользователя
  Future<Shift?> getActiveShift(int userId) async {
    final query = select(shifts)
      ..where((s) => s.userId.equals(userId))
      ..where((s) => s.endTime.isNull())
      ..orderBy([(s) => OrderingTerm.desc(s.startTime)])
      ..limit(1);

    return (await query.getSingleOrNull());
  }

  /// Создать новую смену
  Future<int> createShift(ShiftsCompanion shift) async {
    return await into(shifts).insert(shift);
  }

  /// Обновить смену
  Future<bool> updateShift(int shiftId, ShiftsCompanion shift) async {
    final result = await (update(
      shifts,
    )..where((s) => s.id.equals(shiftId))).write(shift);
    return result > 0;
  }

  /// Получить смены с фильтрацией
  Future<List<Shift>> getShifts({
    DateTime? startDate,
    DateTime? endDate,
    int? userId,
  }) async {
    var query = select(shifts);

    if (startDate != null) {
      query = query..where((s) => s.startTime.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query = query..where((s) => s.startTime.isSmallerOrEqualValue(endDate));
    }
    if (userId != null) {
      query = query..where((s) => s.userId.equals(userId));
    }

    query = query..orderBy([(s) => OrderingTerm.desc(s.startTime)]);

    return await query.get();
  }

  /// Получить смену по ID
  Future<Shift?> getShiftById(int shiftId) async {
    return await (select(
      shifts,
    )..where((s) => s.id.equals(shiftId))).getSingleOrNull();
  }
}
