import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/database/database_provider.dart';

class BackupService {
  static const _tablesInDeleteOrder = [
    'receipt_items',
    'receipts',
    'stock_movements',
    'shifts',
    'advertisements',
    'purchase_requests',
    'settings',
    'clients',
    'products',
    'manufacturers',
    'users',
  ];

  static const _tablesInInsertOrder = [
    'manufacturers',
    'users',
    'products',
    'clients',
    'receipts',
    'receipt_items',
    'stock_movements',
    'advertisements',
    'settings',
    'shifts',
    'purchase_requests',
  ];

  Future<File> exportToJsonFile() async {
    final database = await DatabaseProvider.getDatabase();
    final tables = <String, List<Map<String, dynamic>>>{};

    for (final table in _tablesInInsertOrder.toSet()) {
      final rows = await database.customSelect('SELECT * FROM $table').get();
      tables[table] = rows.map((row) => _normalizeRow(row.data)).toList();
    }

    final payload = {
      'meta': {
        'createdAt': DateTime.now().toIso8601String(),
      },
      'tables': tables,
    };

    final dir = await getApplicationSupportDirectory();
    final fileName = 'backup_${_timestamp()}.json';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(jsonEncode(payload));
    return file;
  }

  Future<void> importFromJsonFile(File file) async {
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Неверный формат файла');
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, dynamic>) {
      throw Exception('В файле нет таблиц');
    }

    final database = await DatabaseProvider.getDatabase();
    await database.customStatement('SET FOREIGN_KEY_CHECKS=0');

    for (final table in _tablesInDeleteOrder) {
      await database.customStatement('DELETE FROM $table');
    }

    for (final table in _tablesInInsertOrder) {
      final rows = tables[table];
      if (rows is! List) continue;
      for (final row in rows) {
        if (row is! Map<String, dynamic>) continue;
        await _insertRow(database, table, row);
      }
    }

    await database.customStatement('SET FOREIGN_KEY_CHECKS=1');
  }

  Map<String, dynamic> _normalizeRow(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      result[key] = _normalizeValue(value);
    });
    return result;
  }

  dynamic _normalizeValue(dynamic value) {
    if (value is DateTime) {
      return _toSqlDateTime(value);
    }
    if (value is bool) {
      return value ? 1 : 0;
    }
    return value;
  }

  Future<void> _insertRow(
    DatabaseConnectionUser database,
    String table,
    Map<String, dynamic> row,
  ) async {
    if (row.isEmpty) return;
    final columns = row.keys.toList();
    final values = columns.map((c) => _sqlValue(row[c])).join(',');
    final sql = 'INSERT INTO $table (${columns.join(',')}) VALUES ($values)';
    await database.customStatement(sql);
  }

  String _sqlValue(dynamic value) {
    if (value == null) return 'NULL';
    if (value is num) return value.toString();
    if (value is bool) return value ? '1' : '0';
    final text = value.toString().replaceAll("'", "''");
    return "'$text'";
  }

  String _timestamp() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    return '$y$m$d-$h$min';
  }

  String _toSqlDateTime(DateTime dateTime) {
    return dateTime.toIso8601String().replaceFirst('T', ' ').split('.').first;
  }
}

