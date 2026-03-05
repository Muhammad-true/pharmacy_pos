import '../../features/shared/models/client.dart';

/// Интерфейс репозитория для работы с клиентами
abstract class IClientRepository {
  /// Получить всех клиентов
  Future<List<Client>> getAllClients();

  /// Получить клиента по ID
  Future<Client?> getClientById(int id);

  /// Получить клиента по телефону
  Future<Client?> getClientByPhone(String phone);

  /// Получить клиента по QR-коду
  Future<Client?> getClientByQrCode(String qrCode);

  /// Поиск клиента по телефону или QR-коду
  Future<Client?> findClientByPhoneOrQr(String phoneOrQr);

  /// Поиск клиентов по имени
  Future<List<Client>> searchClients(String query);

  /// Создать клиента
  Future<Client> createClient(Client client);

  /// Обновить клиента
  Future<Client> updateClient(Client client);

  /// Удалить клиента
  Future<void> deleteClient(int id);

  /// Обновить бонусы клиента
  Future<void> updateBonuses(int id, double bonuses);

  /// Добавить бонусы клиенту
  Future<void> addBonuses(int id, double amount);

  /// Списать бонусы у клиента
  Future<bool> subtractBonuses(int id, double amount);
}

