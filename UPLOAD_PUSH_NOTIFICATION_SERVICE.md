# 📤 Загрузка PushNotificationService.php на сервер

## 🎯 Цель
Обновить файл `PushNotificationService.php` на сервере, чтобы метод `getUnreadMessagesCount()` начал работать и логи появились.

## ⚡ Быстрые шаги

### Шаг 1: Загрузите файл на сервер

**Вариант A: Через SSH (если есть доступ)**

```bash
# Загрузите файл на сервер
scp backend/lib/PushNotificationService.php sbk_19_ru_usr@securewave.sbk-19.ru:~/www/securewave.sbk-19.ru/backend/lib/
```

**Вариант B: Через FTP/SFTP клиент**

1. Подключитесь к серверу через FTP/SFTP
2. Перейдите в папку: `~/www/securewave.sbk-19.ru/backend/lib/`
3. Загрузите файл `backend/lib/PushNotificationService.php` из локального проекта

**Вариант C: Через веб-интерфейс хостинга (FastPanel)**

1. Войдите в FastPanel
2. Откройте файловый менеджер
3. Перейдите в `/var/www/sbk_19_ru_usr/data/www/securewave.sbk-19.ru/backend/lib/`
4. Загрузите файл `PushNotificationService.php`

### Шаг 2: Сбросьте PHP opcache

**Вариант A: Через веб-браузер**

1. Откройте в браузере: `https://securewave.sbk-19.ru/backend/clear_opcache.php`
2. Должно появиться сообщение об успешном сбросе

**Вариант B: Через SSH**

```bash
# Подключитесь к серверу
ssh sbk_19_ru_usr@securewave.sbk-19.ru

# Сбросьте opcache через PHP CLI
php -r "if (function_exists('opcache_reset')) { opcache_reset(); echo 'opcache reset OK\n'; } else { echo 'opcache not available\n'; }"

# Или перезапустите PHP-FPM
sudo systemctl restart php-fpm
# или
sudo service php8.3-fpm restart
```

### Шаг 3: Перезапустите WebSocket сервер

```bash
# Подключитесь к серверу
ssh sbk_19_ru_usr@securewave.sbk-19.ru

# Перейдите в папку backend
cd ~/www/securewave.sbk-19.ru/backend

# Перезапустите WebSocket сервер
./start_websocket.sh restart
```

### Шаг 4: Проверьте логи

```bash
# Следите за логами push-уведомлений
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

Должны появиться строки с методом.

## ⚠️ Если логи все еще не появляются

1. **Проверьте права доступа к файлу логов:**
   ```bash
   ls -la ~/www/securewave.sbk-19.ru/backend/logs/
   chmod 777 ~/www/securewave.sbk-19.ru/backend/logs/
   ```

2. **Проверьте, что WebSocket сервер использует правильный PHP:**
   ```bash
   which php
   /var/www/sbk_19_ru_usr/data/bin/php -v
   ```

3. **Проверьте error_log напрямую:**
   ```bash
   tail -100 /var/log/php-fpm/error.log | grep -i "push\|notification"
   ```

4. **Убедитесь, что сообщение действительно отправляется:**
   - Откройте веб-версию
   - Отправьте сообщение на iOS
   - Проверьте, что сообщение появилось в базе данных

