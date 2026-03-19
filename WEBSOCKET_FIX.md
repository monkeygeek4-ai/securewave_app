# Исправление проблемы с WebSocket и PHP 8.2+

## Проблема
В логах WebSocket сервера появляются множественные предупреждения:
```
Deprecated: Creation of dynamic property Ratchet\Server\IoConnection::$remoteAddress is deprecated
```

Это происходит потому что:
- Ratchet 0.4.4 использует динамические свойства объектов
- PHP 8.2+ помечает создание динамических свойств как deprecated
- Это только warnings, не errors, но засоряют логи

## Решение

Добавлено подавление deprecated warnings в `backend/websocket/server.php`:

```php
// Подавляем deprecated warnings от Ratchet для PHP 8.2+
if (PHP_VERSION_ID >= 80200) {
    error_reporting(E_ALL & ~E_DEPRECATED);
}
```

## Что делать дальше

1. **Перезапустить WebSocket сервер:**
   ```bash
   cd ~/www/securewave.sbk-19.ru/backend
   ./start_websocket.sh restart
   ```

2. **Проверить логи:**
   ```bash
   tail -f websocket/server.log
   ```

3. **Проверить статус:**
   ```bash
   ./start_websocket.sh status
   ```

## Альтернативные решения (если проблема останется)

### Вариант 1: Обновить Ratchet (если доступна новая версия)
```bash
cd backend
composer update cboden/ratchet
```

### Вариант 2: Использовать PHP 8.1 (если возможно)
Ratchet 0.4.4 полностью совместим с PHP 8.1

### Вариант 3: Перейти на другую библиотеку
- ReactPHP WebSocket
- Swoole WebSocket
- Workerman

## Проверка работы WebSocket

После перезапуска проверьте:
1. Сервер запущен: `ps aux | grep server.php`
2. Порт слушается: `netstat -tuln | grep 8085`
3. Логи без ошибок: `tail -f websocket/server.log`
4. Клиент может подключиться

## Примечание

Эти warnings не влияют на функциональность WebSocket сервера - это только предупреждения о устаревшем коде в библиотеке Ratchet. Подавление их безопасно, так как это не ошибки выполнения.

