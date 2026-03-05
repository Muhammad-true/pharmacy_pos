import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';

class UpdateInfo {
  final String version;
  final String? notes;
  final String? url;

  UpdateInfo({
    required this.version,
    this.notes,
    this.url,
  });
}

class UpdateService {
  Future<UpdateInfo?> checkForUpdates() async {
    final updateUrl = AppConfig.instance.updateUrl.trim();
    if (updateUrl.isEmpty) return null;

    final response = await http.get(Uri.parse(updateUrl));
    if (response.statusCode != 200) {
      throw DatabaseException(
        'Ошибка проверки обновлений: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw DatabaseException('Неверный формат ответа обновлений');
    }

    final version = data['version']?.toString();
    if (version == null || version.isEmpty) {
      throw DatabaseException('Не указана версия обновления');
    }

    final latest = UpdateInfo(
      version: version,
      notes: data['notes']?.toString(),
      url: data['url']?.toString(),
    );

    final currentVersion = AppConfig.instance.appVersion;
    if (_isNewerVersion(currentVersion, latest.version)) {
      return latest;
    }
    return null;
  }

  Future<File> downloadUpdate(String url, String version) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw DatabaseException(
        'Ошибка загрузки обновления: ${response.statusCode}',
      );
    }
    final dir = await getApplicationSupportDirectory();
    final updatesDir = Directory(p.join(dir.path, 'updates'));
    if (!await updatesDir.exists()) {
      await updatesDir.create(recursive: true);
    }
    final fileName = 'update_$version${_guessExt(url)}';
    final file = File(p.join(updatesDir.path, fileName));
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  Future<void> installUpdate(File file) async {
    if (!await file.exists()) {
      throw DatabaseException('Файл обновления не найден');
    }
    if (Platform.isWindows) {
      await Process.start(
        file.path,
        [],
        mode: ProcessStartMode.detached,
      );
      return;
    }
    throw DatabaseException('Автоустановка поддерживается только на Windows');
  }

  bool _isNewerVersion(String current, String latest) {
    final c = _parseVersion(current);
    final l = _parseVersion(latest);
    for (var i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  List<int> _parseVersion(String version) {
    final clean = version.split('+').first;
    final parts = clean.split('.');
    final nums = <int>[0, 0, 0];
    for (var i = 0; i < parts.length && i < 3; i++) {
      nums[i] = int.tryParse(parts[i].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return nums;
  }

  String _guessExt(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.msi')) return '.msi';
    if (lower.endsWith('.exe')) return '.exe';
    return '.bin';
  }
}

