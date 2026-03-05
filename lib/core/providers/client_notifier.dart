import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/shared/models/client.dart';
import '../../features/shared/models/receipt_history.dart';
import 'repository_providers.dart';

part 'client_notifier.g.dart';

/// Состояние клиента
@riverpod
class ClientState extends _$ClientState {
  @override
  Client? build() {
    return null;
  }

  /// Загрузить клиента по телефону или QR-коду
  Future<void> loadClientByPhoneOrQr(String phoneOrQr) async {
    try {
      final clientRepo = ref.read(clientRepositoryProvider);
      final client = await clientRepo.findClientByPhoneOrQr(phoneOrQr);
      state = client;
    } catch (e) {
      // Ошибка обрабатывается в ErrorHandler
      state = null;
      rethrow;
    }
  }

  /// Загрузить клиента по ID
  Future<void> loadClientById(int id) async {
    try {
      final clientRepo = ref.read(clientRepositoryProvider);
      final client = await clientRepo.getClientById(id);
      state = client;
    } catch (e) {
      state = null;
      rethrow;
    }
  }

  /// Очистить клиента
  void clearClient() {
    state = null;
  }

  /// Обновить бонусы клиента
  Future<void> updateBonuses(double bonuses) async {
    final client = state;
    if (client == null) return;

    try {
      final clientRepo = ref.read(clientRepositoryProvider);
      await clientRepo.updateBonuses(client.id, bonuses);

      // Обновляем состояние
      state = Client(
        id: client.id,
        name: client.name,
        phone: client.phone,
        qrCode: client.qrCode,
        bonuses: bonuses,
        discountPercent: 0.0,
      );
    } catch (e) {
      rethrow;
    }
  }
}

/// Провайдер для истории чеков клиента
@riverpod
Future<List<ReceiptHistory>> clientReceiptsHistory(
  // ignore: deprecated_member_use_from_same_package
  // ClientReceiptsHistoryRef will be replaced with Ref in Riverpod 3.0
  ClientReceiptsHistoryRef ref,
  int clientId,
) async {
  final receiptRepo = ref.read(receiptRepositoryProvider);
  return await receiptRepo.getClientReceipts(clientId);
}
