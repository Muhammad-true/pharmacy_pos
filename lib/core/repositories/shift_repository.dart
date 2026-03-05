import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/database_provider.dart';
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import '../../features/shared/models/shift_record.dart';

class ShiftRepository {
  final ErrorHandler _errorHandler = ErrorHandler.instance;

  Future<AppDatabase> get _database async => await DatabaseProvider.getDatabase();

  String _toSqlDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final iso = local.toIso8601String();
    final withoutT = iso.replaceFirst('T', ' ');
    final dotIndex = withoutT.indexOf('.');
    return dotIndex >= 0 ? withoutT.substring(0, dotIndex) : withoutT;
  }

  /// Парсит DateTime из числовых/строковых значений, возвращаемых драйвером MySQL
  DateTime _parseDateTime(dynamic value) {
    DateTime asDateTime;
    if (value is DateTime) {
      asDateTime = value;
    } else if (value is int) {
      // Drift хранит Unix timestamp в СЕКУНДАХ (UTC)
      final isSeconds = value.abs() < 100000000000; // < ~ Sat Nov 16 5138
      final millis = isSeconds ? value * 1000 : value;
      asDateTime = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    } else if (value is String) {
      // Строковые значения приходят в локальном формате "YYYY-MM-DD HH:MM:SS"
      // Интерпретируем как локальное время
      asDateTime = DateTime.parse(value);
    } else {
      throw FormatException('Не удалось распарсить DateTime: $value');
    }
    // Переводим в локальную зону для отображения
    return asDateTime.isUtc ? asDateTime.toLocal() : asDateTime;
  }

  Future<ShiftRecord?> getActiveShift(int userId) async {
    try {
      final db = await _database;

      final result = await db.customSelect(
        '''
        SELECT s.*, u.name AS user_name
        FROM shifts s
        JOIN users u ON u.id = s.user_id
        WHERE s.user_id = ? AND s.end_time IS NULL
        ORDER BY s.start_time DESC
        LIMIT 1
        ''',
        variables: [Variable<int>(userId)],
      ).get();

      if (result.isEmpty) return null;
      final row = result.first.data;
      return ShiftRecord(
        id: row['id'] as int,
        userId: row['user_id'] as int,
        userName: row['user_name'] as String? ?? '',
        startTime: _parseDateTime(row['start_time']),
        endTime: row['end_time'] != null ? _parseDateTime(row['end_time']) : null,
        totalRevenue: (row['total_revenue'] as num?)?.toDouble() ?? 0,
        totalReceipts: row['total_receipts'] as int? ?? 0,
      );
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Не удалось получить активную смену: ${e.toString()}');
    }
  }

  Future<ShiftRecord> startShift(int userId, String userName) async {
    try {
      final db = await _database;
      final existing = await getActiveShift(userId);
      if (existing != null) {
        throw DatabaseException('Смена уже открыта');
      }
      final now = DateTime.now();

      final shiftId = await db.customInsert(
        '''
        INSERT INTO shifts (user_id, start_time, created_at, updated_at)
        VALUES (?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ''',
        variables: [Variable<int>(userId), Variable<String>(_toSqlDateTime(now))],
      );

      return ShiftRecord(
        id: shiftId,
        userId: userId,
        userName: userName,
        startTime: now,
        endTime: null,
        totalRevenue: 0,
        totalReceipts: 0,
      );
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Не удалось открыть смену: ${e.toString()}');
    }
  }

  Future<ShiftRecord?> endShift(int shiftId, int userId) async {
    try {
      final db = await _database;

      final activeShift = await db.customSelect(
        '''
        SELECT * FROM shifts
        WHERE id = ? AND user_id = ? AND end_time IS NULL
        ''',
        variables: [Variable<int>(shiftId), Variable<int>(userId)],
      ).getSingleOrNull();

      if (activeShift == null) {
        return null;
      }

      final startTime = _parseDateTime(activeShift.data['start_time']);
      final endTime = DateTime.now();

      final userRow = await db.customSelect(
        'SELECT name FROM users WHERE id = ?',
        variables: [Variable<int>(userId)],
      ).getSingleOrNull();
      final userName = userRow?.data['name'] as String? ?? '';

      final dateComparison = 'created_at >= ? AND created_at <= ?';
      
      final totals = await db.customSelect(
        '''
        SELECT 
          COUNT(*) as total_receipts,
          COALESCE(SUM(total), 0) as total_revenue
        FROM receipts
        WHERE user_id = ?
          AND $dateComparison
        ''',
        variables: [
          Variable<int>(userId),
          Variable<String>(_toSqlDateTime(startTime)),
          Variable<String>(_toSqlDateTime(endTime)),
        ],
      ).getSingle();

      final totalReceipts = totals.data['total_receipts'] as int? ?? 0;
      final totalRevenue = (totals.data['total_revenue'] as num?)?.toDouble() ?? 0.0;

      await db.customUpdate(
        '''
        UPDATE shifts
        SET end_time = ?, 
            total_revenue = ?, 
            total_receipts = ?, 
            updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
        ''',
        variables: [
          Variable<String>(_toSqlDateTime(endTime)),
          Variable<double>(totalRevenue),
          Variable<int>(totalReceipts),
          Variable<int>(shiftId),
        ],
      );

      return ShiftRecord(
        id: shiftId,
        userId: userId,
        userName: userName,
        startTime: startTime,
        endTime: endTime,
        totalRevenue: totalRevenue,
        totalReceipts: totalReceipts,
      );
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Не удалось закрыть смену: ${e.toString()}');
    }
  }

  Future<List<ShiftRecord>> getShifts({
    DateTime? startDate,
    DateTime? endDate,
    int? userId,
  }) async {
    try {
      final db = await _database;

      final where = <String>[];
      final vars = <Variable>[];

      if (startDate != null) {
        where.add('s.start_time >= ?');
        vars.add(Variable<String>(_toSqlDateTime(startDate)));
      }
      if (endDate != null) {
        where.add('s.start_time <= ?');
        vars.add(Variable<String>(_toSqlDateTime(endDate)));
      }
      if (userId != null) {
        where.add('s.user_id = ?');
        vars.add(Variable<int>(userId));
      }

      final query = '''
        SELECT s.*, u.name AS user_name
        FROM shifts s
        JOIN users u ON u.id = s.user_id
        ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
        ORDER BY s.start_time DESC
      ''';

      final rows = await db.customSelect(query, variables: vars).get();

      return rows.map((rowData) {
        final row = rowData.data;
        return ShiftRecord(
          id: row['id'] as int,
          userId: row['user_id'] as int,
          userName: row['user_name'] as String? ?? '',
          startTime: _parseDateTime(row['start_time']),
          endTime: row['end_time'] != null ? _parseDateTime(row['end_time']) : null,
          totalRevenue: (row['total_revenue'] as num?)?.toDouble() ?? 0.0,
          totalReceipts: row['total_receipts'] as int? ?? 0,
        );
      }).toList();
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Не удалось получить список смен: ${e.toString()}');
    }
  }
}

