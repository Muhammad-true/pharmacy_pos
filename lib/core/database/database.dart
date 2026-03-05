import 'package:dorukhonai_man/core/database/dao/stock_movements_dao.dart';
import 'package:drift/drift.dart';
import 'package:mysql1/mysql1.dart';

import '../config/app_config.dart';
import '../errors/error_handler.dart';
import 'dao/advertisements_dao.dart';
import 'dao/clients_dao.dart';
import 'dao/manufacturers_dao.dart';
import 'dao/products_dao.dart';
import 'dao/purchase_requests_dao.dart';
import 'dao/receipts_dao.dart';
import 'dao/settings_dao.dart';
import 'dao/shifts_dao.dart';
import 'dao/users_dao.dart';
import 'mysql_executor.dart';

part 'database.g.dart';

// ============================================================================
// ТАБЛИЦЫ
// ============================================================================

/// Таблица производителей
class Manufacturers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name =>
      text().withLength(min: 1, max: 255).unique()(); // Название производителя
  TextColumn get country => text().nullable()(); // Страна производителя
  TextColumn get address => text().nullable()(); // Адрес производителя
  TextColumn get phone => text().nullable()(); // Телефон производителя
  TextColumn get email => text().nullable()(); // Email производителя
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица товаров
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get barcode => text().withLength(min: 1, max: 255).unique()();
  TextColumn get qrCode => text().nullable()(); // QR-код товара
  RealColumn get price => real()(); // Цена за упаковку
  IntColumn get stock => integer().withDefault(
    const Constant(0),
  )(); // Остаток на складе (в упаковках)
  TextColumn get unit => text().withLength(
    min: 1,
    max: 50,
  )(); // Единица измерения (упаковка, шт и т.д.)
  IntColumn get unitsPerPackage => integer().withDefault(
    const Constant(1),
  )(); // Количество единиц в упаковке
  TextColumn get unitName => text()
      .withLength(min: 1, max: 50)
      .withDefault(
        const Constant('шт'),
      )(); // Название единицы (таблетка, капсула и т.д.)
  TextColumn get inventoryCode =>
      text().withLength(min: 1, max: 255).nullable()(); // Код товара/инвентаря
  TextColumn get organization => text()
      .withLength(min: 1, max: 255)
      .nullable()(); // Склад / организация хранения
  TextColumn get shelfLocation =>
      text().withLength(min: 1, max: 100).nullable()(); // Полка/ячейка хранения
  IntColumn get manufacturerId =>
      integer().nullable().references(Manufacturers, #id)(); // Производитель
  TextColumn get composition => text().nullable()(); // Состав лекарства
  TextColumn get indications => text().nullable()(); // Показания к применению
  TextColumn get preparationMethod =>
      text().nullable()(); // Способ приготовления/применения
  BoolColumn get requiresPrescription => boolean().withDefault(
    const Constant(false),
  )(); // Требуется ли рецепт врача
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица клиентов
class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get phone => text().nullable()();
  TextColumn get qrCode => text().nullable().unique()();
  RealColumn get bonuses =>
      real().withDefault(const Constant(0.0))(); // Бонусы клиента
  RealColumn get discountPercent =>
      real().withDefault(const Constant(0.0))(); // Процент скидки
  IntColumn get createdByUserId => integer().nullable().references(
    Users,
    #id,
  )(); // ID кассира, создавшего клиента
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица пользователей
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().withLength(min: 1, max: 100).unique()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get role => text().withLength(
    min: 1,
    max: 50,
  )(); // cashier, warehouse, admin, manager
  TextColumn get passwordHash =>
      text().nullable()(); // Хэш пароля (для будущей реализации)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица чеков
class Receipts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get receiptNumber => text().withLength(min: 1, max: 50).unique()();
  IntColumn get clientId =>
      integer().nullable().references(Clients, #id)(); // Связь с клиентом
  RealColumn get subtotal =>
      real().withDefault(const Constant(0.0))(); // Сумма без скидки
  RealColumn get discount =>
      real().withDefault(const Constant(0.0))(); // Сумма скидки
  RealColumn get discountPercent =>
      real().withDefault(const Constant(0.0))(); // Процент скидки
  BoolColumn get discountIsPercent => boolean().withDefault(
    const Constant(false),
  )(); // Тип скидки (процент или сумма)
  RealColumn get bonuses =>
      real().withDefault(const Constant(0.0))(); // Списано бонусов
  RealColumn get total =>
      real().withDefault(const Constant(0.0))(); // Итоговая сумма
  RealColumn get received =>
      real().withDefault(const Constant(0.0))(); // Получено от клиента
  RealColumn get change => real().withDefault(const Constant(0.0))(); // Сдача
  TextColumn get paymentMethod => text()
      .withLength(min: 1, max: 50)
      .withDefault(const Constant('cash'))(); // Метод оплаты
  IntColumn get userId => integer().nullable().references(
    Users,
    #id,
  )(); // Кассир, который оформил чек
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица позиций в чеке
class ReceiptItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get receiptId => integer().references(
    Receipts,
    #id,
    onDelete: KeyAction.cascade,
  )(); // Связь с чеком
  IntColumn get productId =>
      integer().references(Products, #id)(); // Связь с товаром
  RealColumn get quantity => real()(); // Количество в единицах (таблетках)
  RealColumn get price => real()(); // Цена за упаковку
  IntColumn get unitsInPackage => integer()(); // Количество единиц в упаковке
  IntColumn get index => integer()(); // Порядковый номер в чеке
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица истории движения товаров на складе
class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId =>
      integer().references(Products, #id)(); // Связь с товаром
  TextColumn get movementType => text().withLength(
    min: 1,
    max: 50,
  )(); // Тип движения: 'in' (поступление), 'out' (продажа), 'adjustment' (корректировка)
  IntColumn get quantity =>
      integer()(); // Количество в упаковках (положительное для поступления, отрицательное для продажи)
  IntColumn get stockBefore => integer()(); // Остаток до движения
  IntColumn get stockAfter => integer()(); // Остаток после движения
  RealColumn get price => real().nullable()(); // Цена за упаковку (для продажи)
  TextColumn get notes => text().nullable()(); // Примечания
  IntColumn get userId => integer().nullable().references(
    Users,
    #id,
  )(); // Пользователь, выполнивший операцию
  IntColumn get receiptId => integer().nullable().references(
    Receipts,
    #id,
  )(); // Связь с чеком (если движение связано с продажей)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица рекламы/баннеров
class Advertisements extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title =>
      text().withLength(min: 1, max: 255)(); // Заголовок рекламы
  TextColumn get description => text().nullable()(); // Описание/текст рекламы
  TextColumn get mediaUrl =>
      text().nullable()(); // URL видео/GIF (локальный путь или URL)
  TextColumn get mediaType => text()
      .withLength(min: 1, max: 50)
      .withDefault(
        const Constant('gif'),
      )(); // Тип медиа: 'gif', 'video', 'image'
  TextColumn get discountText =>
      text().nullable()(); // Текст о скидке (например, "Скидка 15%")
  TextColumn get qrCode =>
      text().nullable()(); // QR код (текст или изображение в base64)
  TextColumn get qrCodeText => text().nullable()(); // Текст для QR кода
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))(); // Активна ли реклама
  IntColumn get displayOrder =>
      integer().withDefault(const Constant(0))(); // Порядок отображения
  IntColumn get createdByUserId =>
      integer().nullable().references(Users, #id)(); // Кто создал
  IntColumn get targetUserId => integer().nullable().references(
    Users,
    #id,
  )(); // Целевая касса (null = все кассы)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица настроек приложения
class Settings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key =>
      text().withLength(min: 1, max: 100).unique()(); // Ключ настройки
  TextColumn get value => text()(); // Значение настройки
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица смен кассиров
class Shifts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)(); // Кассир
  DateTimeColumn get startTime => dateTime()(); // Время начала смены
  DateTimeColumn get endTime =>
      dateTime().nullable()(); // Время окончания смены
  RealColumn get totalRevenue =>
      real().withDefault(const Constant(0.0))(); // Общая выручка за смену
  IntColumn get totalReceipts =>
      integer().withDefault(const Constant(0))(); // Количество чеков за смену
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Таблица заявок на закупку
class PurchaseRequests extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId =>
      integer().references(Products, #id)(); // Связь с товаром
  TextColumn get productName =>
      text().withLength(min: 1, max: 255)(); // Название товара
  IntColumn get requestedByUserId =>
      integer().nullable().references(Users, #id)(); // Кассир
  TextColumn get status => text()
      .withLength(min: 1, max: 50)
      .withDefault(const Constant('open'))(); // open/resolved
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// ============================================================================
// БАЗА ДАННЫХ
// ============================================================================

@DriftDatabase(
  tables: [
    Manufacturers,
    Products,
    Clients,
    Users,
    Receipts,
    ReceiptItems,
    StockMovements,
    PurchaseRequests,
    Advertisements,
    Settings,
    Shifts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Версия БД (увеличиваем при миграциях)
  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Можно добавить начальные данные здесь
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Миграция с версии 1 на 2: увеличиваем размер поля barcode
        if (from < 2) {
          // Миграция не требуется - размер текстового поля в SQLite не ограничен жестко,
          // а обрезание выполняется на уровне приложения перед сохранением
        }

        // Миграция с версии 2 на 3: добавляем новые поля в Products и таблицу Manufacturers
        if (from < 3) {
          // Создаем таблицу производителей
          await m.createTable(manufacturers);

          // Добавляем новые поля в таблицу товаров через SQL ALTER TABLE
          // SQLite поддерживает ADD COLUMN для новых полей
          final db = m.database;
          await db.customStatement(
            'ALTER TABLE products ADD COLUMN qr_code TEXT',
          );
          await db.customStatement(
            'ALTER TABLE products ADD COLUMN manufacturer_id INTEGER REFERENCES manufacturers(id)',
          );
          await db.customStatement(
            'ALTER TABLE products ADD COLUMN composition TEXT',
          );
          await db.customStatement(
            'ALTER TABLE products ADD COLUMN indications TEXT',
          );
          await db.customStatement(
            'ALTER TABLE products ADD COLUMN preparation_method TEXT',
          );
          await db.customStatement(
            'ALTER TABLE products ADD COLUMN requires_prescription INTEGER NOT NULL DEFAULT 0',
          );
        }

        // Миграция с версии 3 на 4: добавляем таблицу истории движения товаров
        if (from < 4) {
          await m.createTable(stockMovements);
        }

        // Миграция с версии 4 на 5: добавляем поле createdByUserId в таблицу Clients
        if (from < 5) {
          final db = m.database;

          // Пытаемся добавить колонку, игнорируя ошибку "duplicate column name"
          // SQLite не поддерживает IF NOT EXISTS для ALTER TABLE ADD COLUMN,
          // поэтому используем try-catch для обработки ошибки дубликата
          try {
            await db.customStatement(
              'ALTER TABLE clients ADD COLUMN created_by_user_id INTEGER REFERENCES users(id)',
            );
          } catch (e) {
            // Если колонка уже существует, SQLite вернет ошибку:
            // "SqliteException(1): while executing, duplicate column name: created_by_user_id, SQL logic error (code 1)"
            final errorStr = e.toString();
            final errorStrLower = errorStr.toLowerCase();

            // Проверяем, что это именно ошибка дубликата колонки created_by_user_id
            final isDuplicateColumnError =
                errorStrLower.contains('duplicate column') &&
                errorStrLower.contains('created_by_user_id');

            if (!isDuplicateColumnError) {
              // Если это не ошибка дубликата колонки, пробрасываем её дальше
              rethrow;
            }
            // Иначе - колонка уже существует, это нормально, игнорируем ошибку
          }
        }

        // Миграция с версии 5 на 6: добавляем таблицу рекламы
        if (from < 6) {
          await m.createTable(advertisements);
        }

        // Миграция с версии 6 на 7: добавляем таблицу настроек
        if (from < 7) {
          await m.createTable(settings);
          // Добавляем начальные настройки
          final db = m.database;
          await db.customStatement(
            "INSERT INTO settings (key, value) VALUES ('pharmacy_name', 'Аптека Хушдил')",
          );
          await db.customStatement(
            "INSERT INTO settings (key, value) VALUES ('language', 'ru')",
          );
          await db.customStatement(
            "INSERT INTO settings (key, value) VALUES ('theme_mode', 'light')",
          );
          await db.customStatement(
            "INSERT INTO settings (key, value) VALUES ('primary_color', '#1976D2')",
          );
        }

        // Миграция с версии 7 на 8: добавляем таблицу смен
        if (from < 8) {
          await m.createTable(shifts);
        }

        // Миграция с версии 8 на 9: добавляем поля склада в products
        if (from < 9) {
          await m.addColumn(products, products.inventoryCode);
          await m.addColumn(products, products.organization);
          await m.addColumn(products, products.shelfLocation);
        }

        // Миграция: добавляем target_user_id в рекламу
        if (from < 10) {
          await m.addColumn(advertisements, advertisements.targetUserId);
        }

        // Миграция с версии 10 на 11: добавляем заявки на закупку
        if (from < 11) {
          await m.createTable(purchaseRequests);
        }
      },
    );
  }

  // ==========================================================================
  // DAO
  // ==========================================================================

  /// DAO для работы с производителями
  ManufacturersDao get manufacturersDao => ManufacturersDao(this);

  /// DAO для работы с товарами
  ProductsDao get productsDao => ProductsDao(this);

  /// DAO для работы с клиентами
  ClientsDao get clientsDao => ClientsDao(this);

  /// DAO для работы с пользователями
  UsersDao get usersDao => UsersDao(this);

  /// DAO для работы с чеками
  ReceiptsDao get receiptsDao => ReceiptsDao(this);

  /// DAO для работы с историей движения товаров
  StockMovementsDao get stockMovementsDao => StockMovementsDao(this);

  /// DAO для работы с рекламой
  AdvertisementsDao get advertisementsDao => AdvertisementsDao(this);

  /// DAO для работы с заявками на закупку
  PurchaseRequestsDao get purchaseRequestsDao => PurchaseRequestsDao(this);

  /// DAO для работы с настройками
  SettingsDao get settingsDao => SettingsDao(this);

  /// DAO для работы со сменами
  ShiftsDao get shiftsDao => ShiftsDao(this);
}

/// Создание соединения с БД
///
/// Подключение к MySQL (единственная поддерживаемая БД)
Future<QueryExecutor> createDatabaseConnection() async {
  // Подключение к MySQL
  final settings = ConnectionSettings(
    host: AppConfig.mysqlHost,
    port: AppConfig.mysqlPort,
    user: AppConfig.mysqlUser,
    password: AppConfig.mysqlPassword,
    db: AppConfig.mysqlDatabase,
    useSSL: AppConfig.mysqlSslEnabled,
  );

  ErrorHandler.instance.debug('[БД] Подключение к MySQL:');
  ErrorHandler.instance.debug('   Host: ${settings.host}:${settings.port}');
  ErrorHandler.instance.debug('   Database: ${settings.db}');
  ErrorHandler.instance.debug(
    '   SSL: ${AppConfig.mysqlSslEnabled ? "включен" : "отключен"}',
  );

  try {
    // Создаем соединение с MySQL
    final connection = await MySqlConnection.connect(settings);

    // Устанавливаем настройки кодировки (как в Workbench)
    // Это необходимо для корректной работы с utf8mb4
    try {
      await connection.query('SET NAMES utf8mb4');
      await connection.query('SET CHARACTER SET utf8mb4');
      ErrorHandler.instance.debug(
        '[БД] Настройки кодировки установлены: utf8mb4',
      );
    } catch (charsetError) {
      ErrorHandler.instance.warning(
        '[БД] Не удалось установить настройки кодировки: $charsetError',
      );
      // Продолжаем работу, даже если не удалось установить кодировку
    }

    ErrorHandler.instance.info('[БД] ✅ MySQL подключение установлено!');

    // Drift использует MySqlExecutor для работы с MySQL
    return MySqlExecutor(connection, logStatements: false);
  } catch (e) {
    ErrorHandler.instance.warning(
      '[БД] ❌ Ошибка подключения к MySQL: $e\n'
      'Убедитесь, что:\n'
      '1. MySQL сервер запущен\n'
      '2. MySQL сервер доступен по адресу ${AppConfig.mysqlHost}:${AppConfig.mysqlPort}\n'
      '3. Указаны правильные учетные данные в .env файле\n'
      '4. База данных ${AppConfig.mysqlDatabase} существует',
    );
    rethrow;
  }
}
