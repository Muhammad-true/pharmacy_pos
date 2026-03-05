import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/errors/app_exception.dart';
import '../core/repositories/settings_repository.dart';
import 'backup_service.dart';

class TelegramExportService {
  final SettingsRepository settingsRepository;
  final BackupService backupService;

  TelegramExportService({
    required this.settingsRepository,
    BackupService? backupService,
  }) : backupService = backupService ?? BackupService();

  Future<void> sendExportToTelegram() async {
    final settings = await settingsRepository.getSettings();
    final token = settings.telegramBotToken?.trim();
    final chatId = settings.telegramChatId?.trim();

    if (token == null || token.isEmpty || chatId == null || chatId.isEmpty) {
      throw DatabaseException('Не настроены токен или chat_id Telegram');
    }

    final file = await backupService.exportToJsonFile();
    await _sendFile(token, chatId, file);
  }

  Future<void> _sendFile(String token, String chatId, File file) async {
    final uri = Uri.parse('https://api.telegram.org/bot$token/sendDocument');
    final request = http.MultipartRequest('POST', uri);
    request.fields['chat_id'] = chatId;
    request.fields['caption'] = 'Экспорт базы данных';
    request.files.add(
      await http.MultipartFile.fromPath(
        'document',
        file.path,
        filename: file.uri.pathSegments.last,
      ),
    );

    final response = await request.send();
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw DatabaseException(
        'Ошибка отправки в Telegram: ${response.statusCode} $body',
      );
    }
  }
}

