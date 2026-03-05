-- ============================================================================
-- SQL скрипт для создания всех таблиц в MySQL
-- База данных: pharmacy_db
-- Версия схемы: 11
-- ============================================================================

-- Используем базу данных
USE pharmacy_db;

-- Удаляем таблицы, если они существуют (для пересоздания)
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS receipt_items;
DROP TABLE IF EXISTS receipts;
DROP TABLE IF EXISTS stock_movements;
DROP TABLE IF EXISTS shifts;
DROP TABLE IF EXISTS advertisements;
DROP TABLE IF EXISTS purchase_requests;
DROP TABLE IF EXISTS settings;
DROP TABLE IF EXISTS clients;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS manufacturers;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS drift_schema_version;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- Таблица производителей
-- ============================================================================
CREATE TABLE manufacturers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL UNIQUE,
  country TEXT NULL,
  address TEXT NULL,
  phone TEXT NULL,
  email TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Таблица пользователей
-- ============================================================================
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(100) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL,
  password_hash TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Таблица товаров
-- ============================================================================
CREATE TABLE products (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  barcode VARCHAR(255) NOT NULL UNIQUE,
  qr_code TEXT NULL,
  price DOUBLE NOT NULL,
  stock INT NOT NULL DEFAULT 0,
  unit VARCHAR(50) NOT NULL,
  units_per_package INT NOT NULL DEFAULT 1,
  unit_name VARCHAR(50) NOT NULL DEFAULT 'шт',
  inventory_code VARCHAR(255) NULL,
  organization VARCHAR(255) NULL,
  shelf_location VARCHAR(100) NULL,
  manufacturer_id INT NULL,
  composition TEXT NULL,
  indications TEXT NULL,
  preparation_method TEXT NULL,
  requires_prescription TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (manufacturer_id) REFERENCES manufacturers(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Таблица клиентов
-- ============================================================================
CREATE TABLE clients (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  phone TEXT NULL,
  qr_code VARCHAR(500) NULL,
  bonuses DOUBLE NOT NULL DEFAULT 0.0,
  discount_percent DOUBLE NOT NULL DEFAULT 0.0,
  created_by_user_id INT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Создаем UNIQUE индекс для qr_code отдельно
CREATE UNIQUE INDEX idx_clients_qr_code_unique ON clients(qr_code);

-- ============================================================================
-- Таблица чеков
-- ============================================================================
CREATE TABLE receipts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  receipt_number VARCHAR(50) NOT NULL UNIQUE,
  client_id INT NULL,
  subtotal DOUBLE NOT NULL DEFAULT 0.0,
  discount DOUBLE NOT NULL DEFAULT 0.0,
  discount_percent DOUBLE NOT NULL DEFAULT 0.0,
  discount_is_percent TINYINT(1) NOT NULL DEFAULT 0,
  bonuses DOUBLE NOT NULL DEFAULT 0.0,
  total DOUBLE NOT NULL DEFAULT 0.0,
  received DOUBLE NOT NULL DEFAULT 0.0,
  `change` DOUBLE NOT NULL DEFAULT 0.0,
  payment_method VARCHAR(50) NOT NULL DEFAULT 'cash',
  user_id INT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (client_id) REFERENCES clients(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Таблица позиций в чеке
-- ============================================================================
CREATE TABLE receipt_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  receipt_id INT NOT NULL,
  product_id INT NOT NULL,
  quantity DOUBLE NOT NULL,
  price DOUBLE NOT NULL,
  units_in_package INT NOT NULL,
  `index` INT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (receipt_id) REFERENCES receipts(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Таблица истории движения товаров на складе
-- ============================================================================
CREATE TABLE stock_movements (
  id INT AUTO_INCREMENT PRIMARY KEY,
  product_id INT NOT NULL,
  movement_type VARCHAR(50) NOT NULL,
  quantity INT NOT NULL,
  stock_before INT NOT NULL,
  stock_after INT NOT NULL,
  price DOUBLE NULL,
  notes TEXT NULL,
  user_id INT NULL,
  receipt_id INT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES products(id),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (receipt_id) REFERENCES receipts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Таблица рекламы/баннеров
-- ============================================================================
CREATE TABLE advertisements (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT NULL,
  media_url TEXT NULL,
  media_type VARCHAR(50) NOT NULL DEFAULT 'gif',
  discount_text TEXT NULL,
  qr_code TEXT NULL,
  qr_code_text TEXT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  display_order INT NOT NULL DEFAULT 0,
  created_by_user_id INT NULL,
  target_user_id INT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by_user_id) REFERENCES users(id),
  FOREIGN KEY (target_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Таблица заявок на закупку
-- ============================================================================
CREATE TABLE purchase_requests (
  id INT AUTO_INCREMENT PRIMARY KEY,
  product_id INT NOT NULL,
  product_name VARCHAR(255) NOT NULL,
  requested_by_user_id INT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'open',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES products(id),
  FOREIGN KEY (requested_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Таблица настроек приложения
-- ============================================================================
CREATE TABLE settings (
  id INT AUTO_INCREMENT PRIMARY KEY,
  `key` VARCHAR(100) NOT NULL UNIQUE,
  value TEXT NOT NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Таблица смен кассиров
-- ============================================================================
CREATE TABLE shifts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  start_time DATETIME NOT NULL,
  end_time DATETIME NULL,
  total_revenue DOUBLE NOT NULL DEFAULT 0.0,
  total_receipts INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Таблица версии схемы Drift (для миграций)
-- ============================================================================
CREATE TABLE drift_schema_version (
  version INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Вставляем версию схемы
INSERT INTO drift_schema_version (version) VALUES (10);

-- ============================================================================
-- Создание индексов для улучшения производительности
-- ============================================================================

-- Индексы для таблицы products
CREATE INDEX idx_products_barcode ON products(barcode);
CREATE INDEX idx_products_manufacturer ON products(manufacturer_id);

-- Индексы для таблицы receipts
CREATE INDEX idx_receipts_client ON receipts(client_id);
CREATE INDEX idx_receipts_user ON receipts(user_id);
CREATE INDEX idx_receipts_created_at ON receipts(created_at);
CREATE INDEX idx_receipts_receipt_number ON receipts(receipt_number);

-- Индексы для таблицы receipt_items
CREATE INDEX idx_receipt_items_receipt ON receipt_items(receipt_id);
CREATE INDEX idx_receipt_items_product ON receipt_items(product_id);

-- Индексы для таблицы stock_movements
CREATE INDEX idx_stock_movements_product ON stock_movements(product_id);
CREATE INDEX idx_stock_movements_user ON stock_movements(user_id);
CREATE INDEX idx_stock_movements_receipt ON stock_movements(receipt_id);
CREATE INDEX idx_stock_movements_created_at ON stock_movements(created_at);

-- Индексы для таблицы shifts
CREATE INDEX idx_shifts_user ON shifts(user_id);
CREATE INDEX idx_shifts_start_time ON shifts(start_time);

-- Индексы для таблицы clients
CREATE INDEX idx_clients_phone ON clients(phone(20));
-- UNIQUE индекс для qr_code уже создан выше

-- ============================================================================
-- Готово!
-- ============================================================================
SELECT 'Все таблицы успешно созданы!' AS status;
