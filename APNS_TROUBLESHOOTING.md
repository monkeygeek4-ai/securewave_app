# APNS Token Issue - Root Cause Analysis

**Дата**: 31 октября 2025
**Проблема**: APNS токен не получается в Release сборке
**Ошибка**: `строки авторизации «aps-environment» для приложения не найдены`

---

## Корневая причина

**Проблема НЕ в entitlements файлах** - они настроены правильно:
- `Runner/Runner.entitlements` (Debug) ✅
- `Runner/RunnerProfile.entitlements` (Release) ✅
- `ios/Runner.xcodeproj/project.pbxproj` - правильно указывает entitlements ✅

**Реальная проблема**: App ID `com.securewavenew.app` в Apple Developer Portal **НЕ ИМЕЕТ** включенной Push Notifications capability.

---

## Доказательства

### 1. Entitlements файлы правильны

**Runner/RunnerProfile.entitlements**:
```xml
<key>com.apple.developer.aps-environment</key>
<string>development</string>
```

**project.pbxproj** (линия 735 - Release конфигурация):
```
CODE_SIGN_ENTITLEMENTS = Runner/RunnerProfile.entitlements;
```

### 2. Provisioning Profile не включает push notifications

При проверке собранного приложения:
```bash
codesign -d --entitlements :- Runner.app
```

**Результат**:
```xml
<dict>
  <key>application-identifier</key>
  <string>Q5CPN332XB.com.securewavenew.app</string>
  <key>com.apple.developer.team-identifier</key>
  <string>Q5CPN332XB</string>
  <key>get-task-allow</key>
  <true/>
</dict>
```

❌ **НЕТ** `com.apple.developer.aps-environment` в собранном приложении!

### 3. Xcode использует Automatic Provisioning Profile

Из логов xcodebuild:
```
Provisioning Profile: "iOS Team Provisioning Profile: com.securewavenew.app"
                      (5945493e-183e-49ed-87d8-562848de9891)
```

Xcode **автоматически** создает provisioning profile на основе capabilities в App ID.
Если App ID не имеет Push Notifications → provisioning profile тоже не будет его включать.

---

## Решение

### Шаг 1: Включить Push Notifications в App ID

1. Зайти на [Apple Developer Portal → Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Найти App ID: `com.securewavenew.app`
3. Нажать "Edit"
4. Включить **"Push Notifications"** capability
5. Нажать "Save"

### Шаг 2: Удалить старые provisioning profiles

После изменения App ID нужно удалить кэшированные provisioning profiles:

```bash
# Найти и удалить старые profiles для этого приложения
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*
```

Или удалить выборочно:
```bash
find ~/Library/MobileDevice/Provisioning\ Profiles -name "*.mobileprovision" \
  -exec sh -c 'security cms -D -i "{}" | grep -q "com.securewavenew.app" && rm "{}"' \;
```

### Шаг 3: Пересобрать приложение

После включения Push Notifications в App ID и удаления старых profiles:

```bash
flutter clean
cd ios && xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination 'id=00008140-001C5C820C09801C' \
  -allowProvisioningUpdates \
  clean build install
```

Xcode создаст **новый** provisioning profile с Push Notifications capability.

### Шаг 4: Проверить entitlements в собранном приложении

```bash
codesign -d --entitlements :- \
  "/Users/vladimir/Library/Developer/Xcode/DerivedData/Runner-*/Build/Intermediates.noindex/ArchiveIntermediates/Runner/InstallationBuildProductsLocation/Applications/Runner.app"
```

**Ожидаемый результат**:
```xml
<key>com.apple.developer.aps-environment</key>
<string>development</string>
```

---

## Почему это происходит

Apple требует, чтобы capabilities были **явно включены** в App ID **перед** использованием.

Последовательность проверки:
1. App ID capabilities (на Apple Developer Portal)
2. Provisioning Profile включает capabilities из App ID
3. Entitlements файл указывает нужные capabilities
4. При подписи приложения Xcode проверяет:
   - Есть ли capability в Provisioning Profile?
   - Если НЕТ → игнорирует entitlements и не добавляет в приложение

**Таким образом**: даже с правильными entitlements файлами, если App ID не имеет Push Notifications, приложение не получит `aps-environment` entitlement.

---

## Дальнейшие шаги

### Development (текущая настройка)

После включения Push Notifications в App ID:
- ✅ Development APNs Auth Key уже загружен в Firebase
- ✅ Entitlements файлы настроены
- ✅ AppDelegate настроен для APNS
- ❌ **КРИТИЧНО**: Включить Push Notifications в App ID!

### Production (для App Store)

1. Создать Production APNs Auth Key в Apple Developer Portal
2. Загрузить в Firebase Console
3. Изменить entitlements на `production`:
   ```xml
   <key>com.apple.developer.aps-environment</key>
   <string>production</string>
   ```
4. Убедиться, что Production provisioning profile включает Push Notifications

---

## Проверочный список

- [ ] Включить Push Notifications в App ID `com.securewavenew.app`
- [ ] Удалить старые provisioning profiles
- [ ] Пересобрать приложение с `--allowProvisioningUpdates`
- [ ] Проверить entitlements в собранном приложении (должен быть `aps-environment`)
- [ ] Запустить на iPhone и проверить логи:
  - ✅ Должно быть: `[FCM] ✅ APNS токен получен`
  - ❌ НЕ должно быть: `строки авторизации «aps-environment» для приложения не найдены`
- [ ] Отправить тестовое push уведомление из Firebase Console

---

## Полезные команды

### Проверить entitlements в приложении
```bash
codesign -d --entitlements :- Runner.app 2>&1
```

### Найти provisioning profiles для приложения
```bash
find ~/Library/MobileDevice/Provisioning\ Profiles -name "*.mobileprovision" -exec sh -c '
  security cms -D -i "{}" 2>/dev/null | grep -q "com.securewavenew.app" && echo "{}"
' \;
```

### Проверить capabilities в provisioning profile
```bash
security cms -D -i "путь_к_profile.mobileprovision" | grep -A 20 "Entitlements"
```

---

**Создано**: 31 октября 2025
**Статус**: Требуется включить Push Notifications в App ID на Apple Developer Portal
