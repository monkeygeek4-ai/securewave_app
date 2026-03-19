# iOS CallKit Setup Instructions

## Шаги для настройки iOS проекта

### 1. Открыть проект в Xcode

```bash
cd ios
open Runner.xcworkspace
```

### 2. Добавить Swift файлы в проект

В Xcode:

1. **Правой кнопкой на папку `Runner`** (слева в навигаторе)
2. Выбрать **"Add Files to Runner..."**
3. Выбрать следующие файлы:
   - `CallKitManager.swift`
   - `AudioSessionManager.swift`
4. **ВАЖНО:** Убедиться что галочка "Copy items if needed" **НЕ стоит** (файлы уже в папке)
5. Target Membership: **Runner** должен быть отмечен
6. Нажать **"Add"**

### 3. Проверить Bridging Header

Файл `Runner-Bridging-Header.h` должен существовать. Если его нет, Xcode создаст автоматически.

### 4. Включить Capabilities

В Xcode:
1. Выбрать **Runner** (проект) в навигаторе
2. Выбрать **Target → Runner**
3. Перейти на вкладку **"Signing & Capabilities"**
4. Нажать **"+ Capability"** и добавить:
   - **Background Modes**
     - ✅ Audio, AirPlay, and Picture in Picture
     - ✅ Voice over IP
     - ✅ Remote notifications
   - **Push Notifications**

### 5. Настроить Bundle Identifier

В **Signing & Capabilities**:
- Bundle Identifier: `com.securewave.app` (или ваш)
- Team: Выбрать вашу команду разработчика

### 6. Проверить Info.plist

Файл уже обновлён и содержит:
- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- `UIBackgroundModes`

### 7. Build проект

```bash
flutter build ios --debug
```

Или в Xcode: **Product → Build** (⌘B)

### 8. Проверить ошибки компиляции

Если есть ошибки:
- Убедитесь что все импорты корректны
- Проверьте что Swift версия >= 5.0 (Build Settings → Swift Language Version)

---

## Структура файлов iOS

```
ios/Runner/
├── AppDelegate.swift              ← Обновлён (CallKit + VoIP Push)
├── CallKitManager.swift           ← НОВЫЙ (управление звонками)
├── AudioSessionManager.swift      ← НОВЫЙ (управление аудио)
├── Info.plist                     ← Обновлён (permissions)
└── Runner-Bridging-Header.h       ← Существующий
```

---

## Тестирование

### Запуск на реальном устройстве

```bash
flutter run -d <DEVICE_ID>
```

Найти DEVICE_ID:
```bash
flutter devices
```

### Проверка CallKit

1. Запустить приложение на iPhone
2. Отправить входящий звонок
3. Должен появиться **нативный UI CallKit**:
   - Полноэкранный экран звонка
   - Имя звонящего
   - Кнопки Accept/Decline

---

## Troubleshooting

### Ошибка: "Module 'CallKit' not found"
- Проверьте что iOS Deployment Target >= 10.0
- В Build Settings → iOS Deployment Target → 10.0 или выше

### Ошибка: "Use of unresolved identifier"
- Убедитесь что Swift файлы добавлены в Target Membership
- Rebuild проект (Product → Clean Build Folder, затем Build)

### CallKit UI не показывается
- Проверьте что приложение запущено на **реальном устройстве** (не симулятор)
- Проверьте логи в Xcode Console
- Убедитесь что Background Modes включены

### VoIP Push не работает
- Нужно настроить VoIP сертификат в Apple Developer Portal
- Настроить APNs на вашем сервере
- Для начала можно тестировать через FCM (уже настроено)

---

## Следующие шаги

1. ✅ Добавить файлы в Xcode
2. ✅ Включить Capabilities
3. ✅ Build проект
4. 📱 Тестировать на реальном iPhone
5. 🔧 Интегрировать с Flutter кодом
