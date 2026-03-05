import 'package:drift/drift.dart';

import '../database.dart';

part 'clients_dao.g.dart';

/// DAO для работы с клиентами
@DriftAccessor(tables: [Clients])
class ClientsDao extends DatabaseAccessor<AppDatabase> with _$ClientsDaoMixin {
  ClientsDao(super.db);

  /// Получить всех клиентов
  Future<List<Client>> getAllClients() async {
    return await (select(
      clients,
    )..orderBy([(c) => OrderingTerm.asc(c.name)])).get();
  }

  /// Получить клиента по ID
  Future<Client?> getClientById(int id) async {
    return await (select(
      clients,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  /// Получить клиента по телефону
  Future<Client?> getClientByPhone(String phone) async {
    // Нормализуем телефон (убираем все нецифровые символы)
    final normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    return await (select(
      clients,
    )..where((c) => c.phone.isNotNull())).get().then((clients) {
      // Ищем клиента, у которого телефон совпадает (после нормализации)
      for (final client in clients) {
        if (client.phone != null) {
          final clientPhone = client.phone!.replaceAll(RegExp(r'[^\d]'), '');
          if (clientPhone.contains(normalizedPhone) ||
              normalizedPhone.contains(clientPhone)) {
            return client;
          }
        }
      }
      return null;
    });
  }

  /// Получить клиента по QR-коду
  Future<Client?> getClientByQrCode(String qrCode) async {
    return await (select(
      clients,
    )..where((c) => c.qrCode.equals(qrCode))).getSingleOrNull();
  }

  /// Поиск клиента по телефону или QR-коду
  Future<Client?> findClientByPhoneOrQr(String phoneOrQr) async {
    // Сначала пробуем найти по QR-коду
    final byQr = await getClientByQrCode(phoneOrQr);
    if (byQr != null) return byQr;

    // Потом по телефону
    return await getClientByPhone(phoneOrQr);
  }

  /// Поиск клиентов по имени
  Future<List<Client>> searchClients(String query) async {
    final lowerQuery = query.toLowerCase();
    return await (select(clients)
          ..where((c) => c.name.lower().contains(lowerQuery))
          ..orderBy([(c) => OrderingTerm.asc(c.name)])
          ..limit(50))
        .get();
  }

  /// Создать клиента
  Future<int> insertClient(ClientsCompanion client) async {
    return await into(clients).insert(client);
  }

  /// Обновить клиента
  Future<bool> updateClient(Client client) async {
    return await update(clients).replace(client);
  }

  /// Удалить клиента
  Future<int> deleteClient(int id) async {
    return await (delete(clients)..where((c) => c.id.equals(id))).go();
  }

  /// Обновить бонусы клиента
  Future<bool> updateClientBonuses(int id, double bonuses) async {
    final result = await (update(clients)..where((c) => c.id.equals(id))).write(
      ClientsCompanion(bonuses: Value(bonuses)),
    );
    return result > 0;
  }

  /// Добавить бонусы клиенту
  Future<bool> addClientBonuses(int id, double amount) async {
    final client = await getClientById(id);
    if (client == null) return false;

    final newBonuses = client.bonuses + amount;
    return await updateClientBonuses(id, newBonuses);
  }

  /// Списать бонусы у клиента
  Future<bool> subtractClientBonuses(int id, double amount) async {
    final client = await getClientById(id);
    if (client == null) return false;

    final newBonuses = (client.bonuses - amount).clamp(0.0, double.infinity);
    return await updateClientBonuses(id, newBonuses);
  }

}
