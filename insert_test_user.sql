-- ============================================================================
-- SQL скрипт для создания тестового пользователя (администратора)
-- ============================================================================

USE pharmacy_db;

-- Вставляем администратора
INSERT INTO users (username, name, role, password_hash, created_at, updated_at) 
VALUES ('admin', 'Администратор', 'admin', NULL, NOW(), NOW())
ON DUPLICATE KEY UPDATE name = name;

-- Проверяем, что пользователь создан
SELECT * FROM users;

