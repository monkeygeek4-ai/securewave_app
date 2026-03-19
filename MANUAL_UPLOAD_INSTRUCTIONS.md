# 📤 Инструкция по ручной загрузке PushNotificationService.php

## 🎯 Цель
Обновить файл `PushNotificationService.php` на сервере, чтобы метод `getUnreadMessagesCount()` начал работать.

## ⚡ Быстрые шаги

### Шаг 1: Загрузите файл на сервер

**Вариант A: Через FastPanel (рекомендуется)**

1. Войдите в FastPanel: `https://securewave.sbk-19.ru:8888` (или ваш адрес FastPanel)
2. Откройте **Файловый менеджер**
3. Перейдите в папку: `/var/www/sbk_19_ru_usr/data/www/securewave.sbk-19.ru/backend/lib/`
4. Найдите файл `PushNotificationService.php`
5. **Загрузите** новый файл из локального проекта: `backend/lib/PushNotificationService.php`
6. Замените существующий файл

**Вариант B: Через SSH (если есть доступ)**

```bash
# На вашем локальном компьютере
cd /Users/vladimir/development/securewave_app
scp backend/lib/PushNotificationService.php sbk_19_ru_usr@securewave.sbk-19.ru:~/www/securewave.sbk-19.ru/backend/lib/
```

**Вариант C: Через FTP/SFTP клиент**

1. Подключитесь к серверу через FileZilla или другой FTP-клиент
2. Перейдите в: `/var/www/sbk_19_ru_usr/data/www/securewave.sbk-19.ru/backend/lib/`
3. Загрузите файл `PushNotificationService.php` из локального проекта

### Шаг 2: Выполните проверку на сервере

**Вариант A: Через SSH**

```bash
# Подключитесь к серверу
ssh sbk_19_ru_usr@securewave.sbk-19.ru

# Загрузите скрипт проверки (если еще не загружен)
# Или скопируйте содержимое check_and_update_push_service.sh

# Выполните скрипт
chmod +x check_and_update_push_service.sh
./check_and_update_push_service.sh
```

**Вариант B: Через FastPanel Terminal**

1. Войдите в FastPanel
2. Откройте **Терминал** (если доступен)
3. Выполните команды из скрипта `check_and_update_push_service.sh`

**Вариант C: Вручную через SSH**

```bash
# Подключитесь к серверу
ssh sbk_19_ru_usr@securewave.sbk-19.ru

# Перейдите в папку backend
cd ~/www/securewave.sbk-19.ru/backend

# Проверьте наличие метода
grep -n "getUnreadMessagesCount" lib/PushNotificationService.php

# Сбросьте opcache
/var/www/sbk_19_ru_usr/data/bin/php -r "if (function_exists('opcache_reset')) { opcache_reset(); echo 'opcache reset OK\n'; }"

# Перезапустите WebSocket сервер
./start_websocket.sh restart
```

### Шаг 3: Проверьте логи

```bash
# На сервере, следите за логами
tail -f ~/www/securewave.sbk-19.ru/backend/logs/push_notifications_*.log

# Или проверьте error_log
tail -f /var/log/php-fpm/error.log | grep -i "getUnreadMessagesCount\|unreadCount\|badge"
```

## ✅ Что должно появиться в логах

После отправки сообщения с веб-версии на iOS, в логах должны появиться:

```
🔍 ВЫЗОВ getUnreadMessagesCount для userId: 1
🔍 getUnreadMessagesCount: Начало для userId: 1
🔍 getUnreadMessagesCount: ИТОГО непрочитанных: X
📊 Непрочитанных сообщений для пользователя 1: X
📤 Calling sendToTokens с unreadCount=X...
📊 Badge будет установлен в: X
```

## 🔍 Проверка файла на сервере

Убедитесь, что файл обновлен:

```bash
# Проверьте наличие метода getUnreadMessagesCount
grep -n "getUnreadMessagesCount" ~/www/securewave.sbk-19.ru/backend/lib/PushNotificationService.php
```

Должны появиться строки:
- `67: $this->logToFile("🔍 ВЫЗОВ getUnreadMessagesCount для userId: $userId");`
- `115: private function getUnreadMessagesCount($userId) {`
- и другие строки с этим методом

## ⚠️ Если логи все еще не появляются

1. **Проверьте права доступа к файлу логов:**
   ```bash
   ls -la ~/www/securewave.sbk-19.ru/backend/logs/
   chmod 777 ~/www/securewave.sbk-19.ru/backend/logs/
   ```

2. **Проверьте, что WebSocket сервер использует правильный PHP:**
   ```bash
   cat ~/www/securewave.sbk-19.ru/backend/start_websocket.sh | grep php
   ```

3. **Убедитесь, что сообщение действительно отправляется:**
   - Откройте веб-версию
   - Отправьте сообщение на iOS
   - Проверьте, что сообщение появилось в базе данных

4. **Проверьте, что метод вызывается:**
   ```bash
   # Добавьте временный лог в начало метода sendNewMessageNotification
   # И проверьте, появляется ли он в логах
   ```

## 📝 Файлы для загрузки

- `backend/lib/PushNotificationService.php` - основной файл (20,853 байт)
- `check_and_update_push_service.sh` - скрипт для проверки на сервере
- `backend/clear_opcache.php` - скрипт для сброса opcache через веб (опционально)

