# 🔍 Проверка подключения к MySQL

## Шаг 1: Убедитесь, что MySQL сервер запущен

```bash
# Windows (если MySQL установлен как служба)
# Проверьте в "Службы" (Services) или:
net start MySQL80

# Или проверьте через командную строку MySQL:
mysql -u root -p023637
```

## Шаг 2: Создайте базу данных

Подключитесь к MySQL и выполните:

```sql
CREATE DATABASE pharmacy_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

Или используйте командную строку:

```bash
mysql -u root -p023637 -e "CREATE DATABASE IF NOT EXISTS pharmacy_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

## Шаг 3: Создайте файл .env

Создайте файл `.env` в корне проекта со следующим содержимым:

```env
DATABASE_TYPE=mysql
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=023637
MYSQL_DATABASE=pharmacy_db
```

## Шаг 4: Проверьте подключение (вариант 1 - тестовый скрипт)

Запустите тестовый скрипт:

```bash
dart test_mysql_connection.dart
```

Этот скрипт проверит:
- ✅ Подключение к MySQL
- ✅ Версию MySQL
- ✅ Существующие таблицы
- ✅ Кодировку базы данных

## Шаг 5: Проверьте подключение (вариант 2 - запуск приложения)

Запустите приложение:

```bash
flutter run -d windows
```

При первом запуске приложение:
1. Подключится к MySQL
2. Создаст все необходимые таблицы автоматически
3. Создаст администратора (если БД пустая)

## Шаг 6: Проверьте логи

В консоли вы должны увидеть:

```
✅ Начало инициализации БД...
✅ Соединение с БД создано
✅ Экземпляр AppDatabase создан
✅ Используется MySQL, WAL режим не требуется
✅ БД инициализирована, версия схемы: 8
```

## Возможные проблемы

### Ошибка: "Can't connect to MySQL server"
- Проверьте, запущен ли MySQL сервер
- Проверьте правильность `MYSQL_HOST` и `MYSQL_PORT` в `.env`

### Ошибка: "Access denied for user"
- Проверьте логин и пароль в `.env`
- Убедитесь, что пользователь имеет права на базу данных

### Ошибка: "Unknown database 'pharmacy_db'"
- Создайте базу данных (см. Шаг 2)

### Ошибка: "Table already exists"
- Это нормально, если таблицы уже созданы
- Приложение продолжит работу

## Проверка через MySQL Workbench или phpMyAdmin

1. Откройте MySQL Workbench или phpMyAdmin
2. Подключитесь к серверу
3. Проверьте, что база данных `pharmacy_db` существует
4. После первого запуска приложения проверьте, что таблицы созданы:
   - `users`
   - `products`
   - `clients`
   - `receipts`
   - `receipt_items`
   - `shifts`
   - и другие...

## Готово! 🎉

Если все проверки пройдены, ваше приложение готово к работе с MySQL!

