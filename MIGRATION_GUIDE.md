# Руководство по миграции базы данных для CallKit

## Обзор

Эта миграция добавляет поддержку iOS CallKit, добавляя поля `platform` и `voip_token` в таблицу `fcm_tokens`.

## Способ 1: Автоматический (рекомендуется)

Запустите PHP-скрипт миграции на вашем сервере:

```bash
cd /path/to/securewave_app/backend/migrations
php run_migration.php
```

Скрипт автоматически:
- Подключится к базе данных используя настройки из `.env`
- Выполнит миграцию
- Покажет структуру таблицы после миграции
- Покажет статистику токенов

## Способ 2: Вручную через psql

### 2.1 Подключитесь к PostgreSQL

Используйте данные из файла `backend/.env`:

```bash
psql -h <DB_HOST> -U <DB_USER> -d <DB_NAME>
```

Или если у вас локальная база:

```bash
psql -U postgres -d securewave
```

### 2.2 Выполните SQL-скрипт

```bash
psql -U postgres -d securewave -f backend/migrations/add_platform_and_voip_token.sql
```

Или скопируйте и вставьте SQL из файла `backend/migrations/add_platform_and_voip_token.sql` в psql консоль.

## Способ 3: Через GUI (pgAdmin, DBeaver, etc.)

1. Откройте `backend/migrations/add_platform_and_voip_token.sql`
2. Скопируйте весь SQL-код
3. Откройте ваш GUI инструмент для PostgreSQL
4. Подключитесь к базе данных `securewave`
5. Откройте SQL консоль
6. Вставьте и выполните SQL-код

## Проверка результата

После выполнения миграции проверьте, что поля добавлены:

```sql
-- Проверить структуру таблицы
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'fcm_tokens'
ORDER BY ordinal_position;
```

Вы должны увидеть:
- `platform` (character varying, default: 'android')
- `voip_token` (text, nullable)

```sql
-- Проверить индексы
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'fcm_tokens';
```

Вы должны увидеть:
- `idx_fcm_tokens_platform`
- `idx_fcm_tokens_voip_token`

```sql
-- Проверить статистику токенов
SELECT
    COUNT(*) as total_tokens,
    SUM(CASE WHEN platform = 'android' THEN 1 ELSE 0 END) as android_tokens,
    SUM(CASE WHEN platform = 'ios' THEN 1 ELSE 0 END) as ios_tokens,
    SUM(CASE WHEN voip_token IS NOT NULL THEN 1 ELSE 0 END) as tokens_with_voip
FROM fcm_tokens;
```

## Что делает миграция

1. **Добавляет колонку `platform`:**
   - Тип: VARCHAR(20)
   - По умолчанию: 'android'
   - Хранит платформу устройства ('ios' или 'android')

2. **Добавляет колонку `voip_token`:**
   - Тип: TEXT
   - Nullable: YES
   - Хранит VoIP Push токен для iOS устройств

3. **Создает индексы:**
   - `idx_fcm_tokens_platform` - для быстрой фильтрации по платформе
   - `idx_fcm_tokens_voip_token` - для быстрого поиска VoIP токенов (только не NULL)

4. **Обновляет существующие записи:**
   - Все существующие токены получают `platform = 'android'` по умолчанию

## После миграции

### Для iOS устройств:

iOS приложения должны будут заново зарегистрироваться и отправить:
- `platform: 'ios'`
- `fcmToken: <FCM token>`
- `voipToken: <VoIP Push token>`

### Для Android устройств:

Android приложения продолжат работать как прежде:
- `platform: 'android'` (установится автоматически)
- `fcmToken: <FCM token>`
- `voipToken: null`

## Откат миграции (если нужно)

Если что-то пошло не так, можно откатить изменения:

```sql
-- Удалить индексы
DROP INDEX IF EXISTS idx_fcm_tokens_platform;
DROP INDEX IF EXISTS idx_fcm_tokens_voip_token;

-- Удалить колонки
ALTER TABLE fcm_tokens DROP COLUMN IF EXISTS platform;
ALTER TABLE fcm_tokens DROP COLUMN IF EXISTS voip_token;
```

## Проблемы и решения

### Ошибка: "relation fcm_tokens does not exist"

Таблица `fcm_tokens` не создана. Сначала нужно создать основную структуру базы данных.

### Ошибка: "column already exists"

Миграция уже была выполнена ранее. Проверьте структуру таблицы:

```sql
\d fcm_tokens
```

### Ошибка прав доступа

Убедитесь, что пользователь базы данных имеет права на ALTER TABLE:

```sql
GRANT ALL PRIVILEGES ON TABLE fcm_tokens TO <your_user>;
```

## Следующие шаги

После успешной миграции:

1. ✅ Перезапустите WebSocket сервер
2. ✅ Обновите Flutter приложение для отправки новых полей
3. ✅ Протестируйте входящие звонки на iOS
4. ✅ Проверьте логи бэкенда для подтверждения работы

## Дополнительная информация

- Полная документация: `BACKEND_CALLKIT_INTEGRATION.md`
- SQL скрипт: `backend/migrations/add_platform_and_voip_token.sql`
- PHP скрипт: `backend/migrations/run_migration.php`
