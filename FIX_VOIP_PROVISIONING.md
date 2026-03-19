# 🔧 Исправление VoIP Provisioning Profile

## ❌ Текущая проблема

При сборке приложения возникает ошибка:
```
Provisioning profile "iOS Team Provisioning Profile: com.securewavenew.app"
doesn't include the com.apple.developer.pushkit.unrestricted-voip entitlement.
```

**Причина:** Provisioning Profile не содержит VoIP entitlement, даже после попыток автоматического обновления через Xcode.

## ✅ Что уже настроено

- ✅ Bundle ID: `com.securewavenew.app`
- ✅ Team ID: `Q5CPN332XB`
- ✅ Entitlements файл с VoIP capability
- ✅ Код приложения (PushKit, CallKit)
- ✅ Backend код для отправки VoIP push
- ✅ Сертификат .p12 загружен на сервер

## 🎯 Что нужно сделать

### Вариант 1: Пересоздать Provisioning Profile в Apple Developer Portal (РЕКОМЕНДУЕТСЯ)

#### Шаг 1: Проверить App ID
1. Откройте [Apple Developer Portal → Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Найдите `com.securewavenew.app`
3. Нажмите на него
4. **Проверьте что включено:**
   - ✅ **Push Notifications** должно быть отмечено
   - Если не отмечено - отметьте и нажмите **Save**

#### Шаг 2: Удалить старый Provisioning Profile
1. Откройте [Profiles](https://developer.apple.com/account/resources/profiles/list)
2. Найдите профили для `com.securewavenew.app`
3. Удалите **iOS Team Provisioning Profile: com.securewavenew.app**
   - Нажмите на профиль → **Delete**

#### Шаг 3: Создать новый Development Provisioning Profile
1. На той же странице нажмите **➕** (Create Profile)
2. Выберите **iOS App Development**
3. Нажмите **Continue**
4. **App ID:** Выберите `com.securewavenew.app`
5. Нажмите **Continue**
6. **Certificates:** Выберите ваш Development Certificate
   - Должен быть `Apple Development: Vladimir Byzov (T77B9H9P86)`
7. Нажмите **Continue**
8. **Devices:** Выберите ваш iPhone
   - `iPhone (Владимир) - 00008140-001C5C820C09801C`
9. Нажмите **Continue**
10. **Profile Name:** `SecureWave Development`
11. Нажмите **Generate**
12. **Скачайте** созданный профиль (`.mobileprovision` файл)

#### Шаг 4: Установить новый профиль
```bash
# Откройте скачанный файл двойным кликом
# ИЛИ скопируйте в терминале:
open ~/Downloads/SecureWave_Development.mobileprovision
```

Xcode автоматически импортирует профиль.

#### Шаг 5: Пересобрать приложение
```bash
cd /Users/vladimir/development/securewave_app
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter build ios --release
flutter install --release
```

---

### Вариант 2: Использовать ручное управление подписью в Xcode

Если автоматическое управление не работает, можно переключиться на ручное:

#### Шаг 1: Открыть проект в Xcode
```bash
open /Users/vladimir/development/securewave_app/ios/Runner.xcworkspace
```

#### Шаг 2: Изменить настройки подписи
1. В левом навигаторе выберите **Runner** (синяя иконка проекта)
2. Выберите **Runner** target
3. Перейдите на вкладку **Signing & Capabilities**
4. **СНИМИТЕ** галочку "Automatically manage signing"
5. В поле **Provisioning Profile** выберите профиль, который создали в Варианте 1
6. Убедитесь что **Team** = `Vladimir Byzov (Q5CPN332XB)`

#### Шаг 3: Собрать через Xcode
1. Product → Clean Build Folder (⇧⌘K)
2. Product → Build (⌘B)
3. Если успешно → Product → Run (⌘R)

---

### Вариант 3: Использовать другой Bundle ID (НЕ РЕКОМЕНДУЕТСЯ)

Если проблема не решается, можно создать новый App ID:

1. Apple Developer Portal → Create New App ID
2. Bundle ID: `com.securewavenew.app.v2`
3. Включить Push Notifications
4. Создать новый Provisioning Profile
5. Обновить Bundle ID в `ios/Runner.xcodeproj`
6. Пересоздать VoIP сертификат для нового Bundle ID

**Но это потребует много изменений, поэтому рекомендую Вариант 1.**

---

## 🔍 Как проверить что профиль правильный

После установки нового профиля, проверьте:

```bash
# Посмотреть установленные профили
ls -la ~/Library/MobileDevice/Provisioning\ Profiles/

# Посмотреть содержимое профиля (если есть)
security cms -D -i ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision | grep -A 5 "com.apple.developer"
```

Должно быть:
```xml
<key>com.apple.developer.pushkit.unrestricted-voip</key>
<true/>
```

---

## 🐛 Если всё ещё не работает

### Проверка 1: Убедитесь что App ID правильный
```bash
cd /Users/vladimir/development/securewave_app/ios
grep -r "com.securewavenew.app" .
```

### Проверка 2: Посмотрите логи Xcode
```bash
xcodebuild -workspace Runner.xcworkspace -scheme Runner -destination 'id=00008140-001C5C820C09801C' -allowProvisioningUpdates build 2>&1 | grep -i "provisioning\|entitlement\|voip"
```

### Проверка 3: Проверьте что сертификат валидный
```bash
security find-identity -v -p codesigning
```

Должны увидеть:
```
1) ... "Apple Development: Vladimir Byzov (T77B9H9P86)"
```

---

## 📞 Контакты поддержки Apple

Если проблема не решается:
- [Apple Developer Support](https://developer.apple.com/support/)
- Телефон: +1 (408) 996-1010
- Email: через [Contact Us](https://developer.apple.com/contact/)

---

## 💡 Быстрая команда для пересборки

После исправления в Apple Developer Portal:

```bash
cd /Users/vladimir/development/securewave_app && \
flutter clean && \
flutter pub get && \
cd ios && \
pod install && \
cd .. && \
flutter build ios --release && \
flutter install --release -d 00008140-001C5C820C09801C
```

---

## ✅ После успешной сборки

Проверьте что VoIP работает:

1. Откройте Console в Xcode:
   - Window → Devices and Simulators
   - Выберите iPhone
   - Open Console

2. В логах должно появиться:
   ```
   📱 VoIP Push Token получен!
   Token: 1234567890abcdef...
   ```

3. Закройте приложение ПОЛНОСТЬЮ (из App Switcher)

4. Проверьте что токен записан в БД:
   ```sql
   SELECT * FROM push_tokens WHERE type = 'voip' AND platform = 'ios';
   ```

5. Позвоните с другого устройства - должен появиться CallKit UI!

---

## 📚 Дополнительная информация

- [Apple - Provisioning Profiles](https://developer.apple.com/documentation/xcode/managing-your-teams-provisioning-profiles)
- [Apple - PushKit](https://developer.apple.com/documentation/pushkit)
- [SETUP_CHECKLIST.md](SETUP_CHECKLIST.md) - полный чеклист настройки
