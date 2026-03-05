# Создание таблиц MySQL вручную

## 📋 Инструкция

### Шаг 1: Создайте базу данных (если еще не создана)

```sql
CREATE DATABASE IF NOT EXISTS pharmacy_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### Шаг 2: Выполните SQL скрипт

**Вариант 1: Через командную строку MySQL**

```bash
mysql -u root -p023637 pharmacy_db < create_mysql_tables.sql
```

**Вариант 2: Через MySQL Workbench или другой клиент**

1. Откройте MySQL Workbench
2. Подключитесь к серверу MySQL
3. Откройте файл `create_mysql_tables.sql`
4. Выполните скрипт (Ctrl+Shift+Enter)

**Вариант 3: Через командную строку MySQL (интерактивно)**

```bash
mysql -u root -p023637
```

Затем в MySQL:

```sql
USE pharmacy_db;
SOURCE create_mysql_tables.sql;
```

### Шаг 3: Проверьте создание таблиц

```sql
USE pharmacy_db;
SHOW TABLES;
```

Должны быть созданы следующие таблицы:
- `manufacturers` - Производители
- `users` - Пользователи
- `products` - Товары
- `clients` - Клиенты
- `receipts` - Чеки
- `receipt_items` - Позиции в чеке
- `stock_movements` - Движение товаров
- `advertisements` - Реклама
- `settings` - Настройки
- `shifts` - Смены кассиров
- `drift_schema_version` - Версия схемы (для Drift)

### Шаг 4: Проверьте структуру таблицы (пример)

```sql
DESCRIBE users;
DESCRIBE products;
DESCRIBE receipts;
```

## ⚠️ Важные замечания

1. **Версия схемы**: Скрипт создает таблицы с версией схемы 8, что соответствует текущей версии в коде.

2. **Пересоздание таблиц**: Скрипт сначала удаляет все существующие таблицы (если они есть), а затем создает их заново. **ВНИМАНИЕ: Все данные будут удалены!**

3. **Если нужно сохранить данные**: 
   - Сначала сделайте резервную копию: `mysqldump -u root -p023637 pharmacy_db > backup.sql`
   - Затем выполните скрипт

4. **После создания таблиц**: Приложение автоматически создаст администратора при первом запуске (если таблица `users` пустая).

## 🔧 Создание администратора вручную (опционально)

Если хотите создать администратора вручную:

```sql
INSERT INTO users (username, name, role, created_at, updated_at) 
VALUES ('admin', 'Администратор', 'admin', NOW(), NOW());
```

## ✅ После создания таблиц

1. Убедитесь, что в `.env` файле указано:
   ```env
   DATABASE_TYPE=mysql
   MYSQL_HOST=localhost
   MYSQL_PORT=3306
   MYSQL_USER=root
   MYSQL_PASSWORD=023637
   MYSQL_DATABASE=pharmacy_db
   ```

2. Запустите приложение:
   ```bash
   flutter run -d windows
   ```

3. Приложение должно подключиться к MySQL и работать с созданными таблицами.

