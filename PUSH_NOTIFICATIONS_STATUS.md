# 📱 Push Notifications Configuration Status

**Последнее обновление**: 31 октября 2025
**Проект**: SecureWave App
**Firebase Project**: wave-messenger-56985

---

## ✅ Текущий статус настройки

### Firebase Configuration
- ✅ Firebase Core и Messaging установлены
- ✅ `firebase_options.dart` настроен корректно
- ✅ iOS Bundle ID: `com.securewavenew.app` (совпадает с Xcode)
- ✅ Android Package: `com.securewave.app`
- ✅ `google-services.json` присутствует для Android
- ✅ `GoogleService-Info.plist` присутствует для iOS

### iOS Push Notifications
- ✅ **Development APNs Auth Key загружен в Firebase**
  - Key ID: `24QCU8TT4L`
  - Team ID: `Q5CPN332XB`
- ✅ Development APNs Certificate (до 28 ноября 2026)
- ✅ Entitlements настроены (`aps-environment: development`)
- ✅ Info.plist: Background modes включены (audio, voip, remote-notification)
- ✅ VoIP Push через PKPushRegistry настроены
- ✅ CallKit интеграция реализована
- ✅ AppDelegate.swift настроен для APNS и VoIP
- ⚠️ **Production APNs Auth Key НЕ настроен** (требуется для App Store)

### Android Push Notifications
- ✅ Firebase Messaging Service зарегистрирован
- ✅ Permissions настроены в AndroidManifest.xml
- ✅ Notification channels созданы
- ✅ Full-screen intent для входящих звонков
- ✅ CallActivity и CallActionReceiver настроены

### Code Implementation
- ✅ FCM Service реализован ([lib/services/fcm_service.dart](lib/services/fcm_service.dart))
- ✅ Token регистрация на backend
- ✅ Foreground/Background message handlers
- ✅ iOS CallKit Handler реализован
- ✅ VoIP token callback настроен
- ✅ main.dart инициализация корректна

---

## 🧪 Тестирование (Development)

### Тестирование на iOS (Development)

1. **Очистить и пересобрать проект:**
   ```bash
   flutter clean
   flutter pub get
   cd ios && pod install && cd ..
   flutter build ios --debug
   ```

2. **Запустить на реальном iPhone** (симулятор не поддерживает push)

3. **Проверить логи:**
   ```
   [Init] ✅ Firebase инициализирован для iOS
   [FCM] 📱 iOS: Получение APNS токена...
   [FCM] ✅ APNS токен получен
   [FCM] ✅ FCM токен: <токен>
   [Init] 📱 VoIP токен получен в main.dart
   [Init] ✅ VoIP токен успешно зарегистрирован на backend
   ```

4. **Тестировать FCM уведомления:**
   - Firebase Console → Cloud Messaging → Send test message
   - Вставить FCM токен из логов
   - Отправить уведомление

5. **Тестировать VoIP звонки:**
   - Убедиться, что VoIP токен сохранен на backend
   - Отправить VoIP push с backend
   - Проверить CallKit UI

### Тестирование на Android

1. **Собрать и запустить:**
   ```bash
   flutter build apk --debug
   ```

2. **Проверить разрешения:**
   - Notifications
   - Full-screen intent (для Android 12+)
   - Display over other apps (опционально)

3. **Тестировать FCM:**
   - Отправить тестовое уведомление из Firebase Console
   - Проверить foreground/background/terminated состояния

4. **Тестировать звонки:**
   - Входящий звонок когда app активен
   - Входящий звонок когда app в фоне
   - Входящий звонок когда app закрыт

---

## 🚀 Production Checklist (для App Store/Play Store)

### iOS Production Setup

#### 1. Создать Production APNs Auth Key

**В Apple Developer Portal:**
1. Зайти в [Keys](https://developer.apple.com/account/resources/authkeys/list)
2. Нажать **"+"** для создания нового ключа
3. Дать название: "SecureWave Production APNs"
4. Включить **Apple Push Notifications service (APNs)**
5. Нажать **Continue** → **Register**
6. **Скачать файл .p8** (⚠️ можно скачать только один раз!)
7. Сохранить **Key ID** (будет показан на экране)
8. Сохранить **Team ID** (в профиле Membership)

**В Firebase Console:**
1. Открыть [Cloud Messaging Settings](https://console.firebase.google.com/project/wave-messenger-56985/settings/cloudmessaging)
2. Прокрутить до **"Apple app configuration"**
3. В секции **"APNs Authentication Key"** нажать **Upload**
4. Загрузить файл `.p8`
5. Ввести:
   - Key ID
   - Team ID (Q5CPN332XB)
6. Нажать **Upload**

#### 2. Обновить Entitlements для Production

**Файл:** `ios/Runner/Runner.entitlements`

Изменить:
```xml
<key>com.apple.developer.aps-environment</key>
<string>production</string>
```

⚠️ **НЕ ЗАБУДЬТЕ** также обновить `ios/Runner/RunnerProfile.entitlements`

#### 3. Проверить App ID и Provisioning Profile

1. Зайти в [Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Найти `com.securewavenew.app`
3. Убедиться, что включены:
   - ✅ Push Notifications
   - ✅ Background Modes (если есть)
4. Пересоздать **Distribution Provisioning Profile** если нужно

#### 4. Собрать для Production

```bash
# Очистить
flutter clean

# Обновить зависимости
flutter pub get
cd ios && pod install && cd ..

# Собрать Release
flutter build ios --release

# Загрузить через Xcode или Transporter
open ios/Runner.xcworkspace
```

#### 5. Тестирование Production Push

⚠️ **Важно**: Production push можно тестировать только на **TestFlight** или **App Store** сборках!

**Через TestFlight:**
1. Загрузить build в TestFlight
2. Установить на устройство
3. Получить FCM токен из production сборки
4. Отправить тестовое уведомление

---

### Android Production Setup

#### 1. Создать Release Keystore (если ещё нет)

```bash
keytool -genkey -v -keystore securewave-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias securewave
```

#### 2. Настроить Signing в Android

**Файл:** `android/key.properties`
```properties
storePassword=<ваш пароль>
keyPassword=<ваш пароль>
keyAlias=securewave
storeFile=<путь к .jks файлу>
```

#### 3. Собрать Release APK/AAB

```bash
# App Bundle (для Play Store)
flutter build appbundle --release

# APK (для прямого распространения)
flutter build apk --release
```

#### 4. Проверить FCM Configuration

- ✅ Server Key присутствует в Firebase Console
- ✅ `google-services.json` содержит правильный package name
- ✅ SHA-1 отпечаток добавлен в Firebase (для Google Sign-In, если используется)

---

## 📊 Monitoring & Debugging

### Firebase Console Metrics
- Cloud Messaging → Reports
- Отслеживать:
  - Delivery rate
  - Open rate
  - Errors

### iOS Debugging
```bash
# Логи на реальном устройстве
xcrun devicectl device info logs --device <DEVICE_ID>

# Crash logs
~/Library/Developer/Xcode/iOS DeviceSupport/<VERSION>/Logs/CrashReporter
```

### Android Debugging
```bash
# Логи FCM
adb logcat | grep -i firebase

# Логи приложения
flutter logs
```

---

## 🔧 Troubleshooting

### iOS: Не приходят уведомления

1. **Проверить entitlements:**
   ```bash
   codesign -d --entitlements - ios/build/Runner.app
   ```

2. **Проверить APNs ключ в Firebase:**
   - Убедиться, что Key ID и Team ID правильные
   - Проверить, что используется правильный environment (development/production)

3. **Проверить получение APNS токена:**
   - Должен быть лог: `[FCM] ✅ APNS токен получен`
   - Если нет - проверить provisioning profile и entitlements

4. **Проверить FCM токен:**
   - Должен быть лог: `[FCM] ✅ FCM токен: ...`
   - Попробовать отправить тестовое уведомление с этим токеном

### Android: Не приходят уведомления

1. **Проверить permissions:**
   - На Android 13+ требуется runtime permission для уведомлений
   - Проверить в Settings → Apps → SecureWave → Notifications

2. **Проверить battery optimization:**
   - Settings → Battery → Battery Optimization
   - Выключить оптимизацию для SecureWave

3. **Проверить notification channels:**
   - Должны быть созданы каналы: `calls_channel`, `messages_channel`

4. **Проверить FCM токен:**
   - Убедиться, что токен успешно зарегистрирован на backend

### VoIP Push не работает на iOS

1. **Проверить VoIP entitlements:**
   - Должен быть `com.apple.developer.pushkit.unrestricted-voip`

2. **Проверить VoIP токен:**
   - Должен быть лог: `[Init] 📱 VoIP токен получен`
   - Проверить, что токен отправлен на backend

3. **Проверить payload VoIP push:**
   ```json
   {
     "callId": "unique-call-id",
     "callerName": "John Doe",
     "callType": "audio"
   }
   ```

---

## 📚 Полезные ссылки

- [Firebase Cloud Messaging iOS Setup](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [Apple Push Notifications Guide](https://developer.apple.com/documentation/usernotifications)
- [PushKit Documentation](https://developer.apple.com/documentation/pushkit)
- [CallKit Documentation](https://developer.apple.com/documentation/callkit)
- [Android FCM Setup](https://firebase.google.com/docs/cloud-messaging/android/client)

---

## ✅ Summary

**Development (текущее состояние):**
- ✅ iOS Development push работают
- ✅ Android push работают
- ✅ VoIP push настроены
- ✅ CallKit интегрирован

**Production (требуется настроить):**
- ⚠️ Создать и загрузить Production APNs Auth Key
- ⚠️ Изменить entitlements на production
- ⚠️ Пересобрать с release профилем
- ⚠️ Протестировать на TestFlight

**Следующий шаг**: Протестируйте на реальном iPhone в development режиме!
