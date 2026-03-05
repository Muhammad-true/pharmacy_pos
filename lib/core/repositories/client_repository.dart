import 'dart:math';

import '../../features/shared/models/client.dart';
import '../../utils/qr_code_generator.dart';
import '../database/database_provider.dart';
import '../database/database.dart' as db;
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import 'i_client_repository.dart';
import 'mappers/database_mappers.dart';

/// Реализация репозитория для работы с клиентами
class ClientRepository implements IClientRepository {
  final ErrorHandler _errorHandler = ErrorHandler.instance;

  /// Получить БД
  Future<db.AppDatabase> get _database async => await DatabaseProvider.getDatabase();

  @override
  Future<List<Client>> getAllClients() async {
    try {
      final database = await _database;
      final dbClients = await database.clientsDao.getAllClients();
      // Для каждого клиента получаем имя создателя
      final clients = <Client>[];
      for (final dbClient in dbClients) {
        String? createdByUserName;
        if (dbClient.createdByUserId != null) {
          try {
            final user = await database.usersDao.getUserById(dbClient.createdByUserId!);
            createdByUserName = user?.name;
          } catch (e) {
            // Игнорируем ошибку получения пользователя
          }
        }
        clients.add(DatabaseMappers.toAppClient(dbClient, createdByUserName: createdByUserName));
      }
      return clients;
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения клиентов: ${e.toString()}');
    }
  }

  @override
  Future<Client?> getClientById(int id) async {
    try {
      final database = await _database;
      final dbClient = await database.clientsDao.getClientById(id);
      if (dbClient == null) return null;
      // Получаем имя пользователя, если есть createdByUserId
      String? createdByUserName;
      if (dbClient.createdByUserId != null) {
        try {
          final user = await database.usersDao.getUserById(dbClient.createdByUserId!);
          createdByUserName = user?.name;
        } catch (e) {
          // Игнорируем ошибку получения пользователя
        }
      }
      return DatabaseMappers.toAppClient(dbClient, createdByUserName: createdByUserName);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка получения клиента: ${e.toString()}');
    }
  }

  @override
  Future<Client?> getClientByPhone(String phone) async {
    try {
      final database = await _database;
      final dbClient = await database.clientsDao.getClientByPhone(phone);
      if (dbClient == null) return null;
      // Получаем имя пользователя, если есть createdByUserId
      String? createdByUserName;
      if (dbClient.createdByUserId != null) {
        try {
          final user = await database.usersDao.getUserById(dbClient.createdByUserId!);
          createdByUserName = user?.name;
        } catch (e) {
          // Игнорируем ошибку получения пользователя
        }
      }
      return DatabaseMappers.toAppClient(dbClient, createdByUserName: createdByUserName);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка поиска клиента по телефону: ${e.toString()}');
    }
  }

  @override
  Future<Client?> getClientByQrCode(String qrCode) async {
    try {
      final database = await _database;
      final dbClient = await database.clientsDao.getClientByQrCode(qrCode);
      if (dbClient == null) return null;
      // Получаем имя пользователя, если есть createdByUserId
      String? createdByUserName;
      if (dbClient.createdByUserId != null) {
        try {
          final user = await database.usersDao.getUserById(dbClient.createdByUserId!);
          createdByUserName = user?.name;
        } catch (e) {
          // Игнорируем ошибку получения пользователя
        }
      }
      return DatabaseMappers.toAppClient(dbClient, createdByUserName: createdByUserName);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка поиска клиента по QR-коду: ${e.toString()}');
    }
  }

  @override
  Future<Client?> findClientByPhoneOrQr(String phoneOrQr) async {
    try {
      final database = await _database;
      final dbClient = await database.clientsDao.findClientByPhoneOrQr(phoneOrQr);
      if (dbClient == null) return null;
      // Получаем имя пользователя, если есть createdByUserId
      String? createdByUserName;
      if (dbClient.createdByUserId != null) {
        try {
          final user = await database.usersDao.getUserById(dbClient.createdByUserId!);
          createdByUserName = user?.name;
        } catch (e) {
          // Игнорируем ошибку получения пользователя
        }
      }
      return DatabaseMappers.toAppClient(dbClient, createdByUserName: createdByUserName);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка поиска клиента: ${e.toString()}');
    }
  }

  @override
  Future<List<Client>> searchClients(String query) async {
    try {
      if (query.isEmpty) return [];
      
      final database = await _database;
      final dbClients = await database.clientsDao.searchClients(query);
      // Для каждого клиента получаем имя создателя
      final clients = <Client>[];
      for (final dbClient in dbClients) {
        String? createdByUserName;
        if (dbClient.createdByUserId != null) {
          try {
            final user = await database.usersDao.getUserById(dbClient.createdByUserId!);
            createdByUserName = user?.name;
          } catch (e) {
            // Игнорируем ошибку получения пользователя
          }
        }
        clients.add(DatabaseMappers.toAppClient(dbClient, createdByUserName: createdByUserName));
      }
      return clients;
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка поиска клиентов: ${e.toString()}');
    }
  }

  @override
  Future<Client> createClient(Client client) async {
    try {
      final database = await _database;
      
      // Проверяем, существует ли клиент с таким QR-кодом
      String qrCode = client.qrCode ?? '';
      if (qrCode.isNotEmpty) {
        final existingClient = await database.clientsDao.getClientByQrCode(qrCode);
        if (existingClient != null) {
          // Если клиент существует - генерируем уникальный QR-код
          // Пробуем до 10 раз, пока не найдем уникальный код
          bool foundUnique = false;
          for (int i = 0; i < 10; i++) {
            qrCode = QrCodeGenerator.generateClientQrCode();
            final checkClient = await database.clientsDao.getClientByQrCode(qrCode);
            if (checkClient == null) {
              // Найден уникальный QR-код
              foundUnique = true;
              break;
            }
          }
          // Если все попытки неудачны - используем timestamp + random для гарантии уникальности
          if (!foundUnique) {
            qrCode = 'CLIENT-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';
          }
        }
      } else {
        // Если QR-код не указан - генерируем уникальный
        qrCode = QrCodeGenerator.generateClientQrCode();
      }
      
      // Создаем клиента с уникальным QR-кодом
      final clientWithUniqueQr = Client(
        id: client.id,
        name: client.name,
        phone: client.phone,
        qrCode: qrCode,
        bonuses: client.bonuses,
        discountPercent: 0.0,
        createdByUserId: client.createdByUserId,
        createdByUserName: client.createdByUserName,
      );
      
      final dbClient = DatabaseMappers.toDbClient(clientWithUniqueQr);
      final id = await database.clientsDao.insertClient(dbClient);
      // Получаем созданного клиента из БД для получения всех полей
      final createdDbClient = await database.clientsDao.getClientById(id);
      if (createdDbClient == null) {
        throw DatabaseException('Клиент не был создан');
      }
      // Получаем имя пользователя, если есть createdByUserId
      String? createdByUserName;
      if (createdDbClient.createdByUserId != null) {
        try {
          final user = await database.usersDao.getUserById(createdDbClient.createdByUserId!);
          createdByUserName = user?.name;
        } catch (e) {
          // Игнорируем ошибку получения пользователя
        }
      }
      return DatabaseMappers.toAppClient(createdDbClient, createdByUserName: createdByUserName);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка создания клиента: ${e.toString()}');
    }
  }

  @override
  Future<Client> updateClient(Client client) async {
    try {
      final database = await _database;
      final existing = await database.clientsDao.getClientById(client.id);
      if (existing == null) {
        throw DatabaseException('Клиент не найден');
      }
      
      final updatedDbClient = db.Client(
        id: client.id,
        name: client.name,
        phone: client.phone,
        qrCode: client.qrCode,
        bonuses: client.bonuses,
        discountPercent: 0.0,
        createdByUserId: client.createdByUserId ?? existing.createdByUserId,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      
      final updated = await database.clientsDao.updateClient(updatedDbClient);
      if (!updated) {
        throw DatabaseException('Не удалось обновить клиента');
      }
      // Получаем обновленного клиента из БД
      final updatedDbClientFromDb = await database.clientsDao.getClientById(client.id);
      if (updatedDbClientFromDb == null) {
        throw DatabaseException('Клиент не найден после обновления');
      }
      // Получаем имя пользователя, если есть createdByUserId
      String? createdByUserName;
      if (updatedDbClientFromDb.createdByUserId != null) {
        try {
          final user = await database.usersDao.getUserById(updatedDbClientFromDb.createdByUserId!);
          createdByUserName = user?.name;
        } catch (e) {
          // Игнорируем ошибку получения пользователя
        }
      }
      return DatabaseMappers.toAppClient(updatedDbClientFromDb, createdByUserName: createdByUserName);
    } catch (e) {
      _errorHandler.handleError(e);
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Ошибка обновления клиента: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteClient(int id) async {
    try {
      final database = await _database;
      await database.clientsDao.deleteClient(id);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка удаления клиента: ${e.toString()}');
    }
  }

  @override
  Future<void> updateBonuses(int id, double bonuses) async {
    try {
      final database = await _database;
      final updated = await database.clientsDao.updateClientBonuses(id, bonuses);
      if (!updated) {
        throw DatabaseException('Не удалось обновить бонусы клиента');
      }
    } catch (e) {
      _errorHandler.handleError(e);
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Ошибка обновления бонусов: ${e.toString()}');
    }
  }

  @override
  Future<void> addBonuses(int id, double amount) async {
    try {
      final database = await _database;
      final updated = await database.clientsDao.addClientBonuses(id, amount);
      if (!updated) {
        throw DatabaseException('Не удалось добавить бонусы клиенту');
      }
    } catch (e) {
      _errorHandler.handleError(e);
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Ошибка добавления бонусов: ${e.toString()}');
    }
  }

  @override
  Future<bool> subtractBonuses(int id, double amount) async {
    try {
      final database = await _database;
      return await database.clientsDao.subtractClientBonuses(id, amount);
    } catch (e) {
      _errorHandler.handleError(e);
      throw DatabaseException('Ошибка списания бонусов: ${e.toString()}');
    }
  }

}

