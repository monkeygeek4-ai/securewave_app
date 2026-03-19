# iOS CallKit Integration - Полная Инструкция

## ✅ Что уже создано

### Swift файлы (Native iOS)
1. ✅ [CallKitManager.swift](ios/Runner/CallKitManager.swift) - Управление CallKit
2. ✅ [AudioSessionManager.swift](ios/Runner/AudioSessionManager.swift) - Управление аудио
3. ✅ [AppDelegate.swift](ios/Runner/AppDelegate.swift) - Интеграция с Flutter

### Dart файлы (Flutter)
1. ✅ [ios_callkit_helper.dart](lib/helpers/ios_callkit_helper.dart) - Обертка для CallKit
2. ✅ [ios_callkit_handler.dart](lib/helpers/ios_callkit_handler.dart) - Обработчик событий
3. ✅ [Info.plist](ios/Runner/Info.plist) - Permissions обновлены

---

## 📋 Шаги для завершения интеграции

### 1. Добавить Swift файлы в Xcode (ОБЯЗАТЕЛЬНО!)

```bash
cd ios
open Runner.xcworkspace
```

В Xcode:
1. **Правой кнопкой на папку Runner** (в навигаторе слева)
2. Выбрать **"Add Files to Runner..."**
3. Выбрать файлы:
   - `CallKitManager.swift`
   - `AudioSessionManager.swift`
4. ⚠️ **ВАЖНО**:
   - Убедиться что галочка **"Copy items if needed"** НЕ стоит
   - Target Membership: **Runner** должен быть отмечен
5. Нажать **"Add"**

### 2. Включить Capabilities в Xcode

1. Выбрать **Runner** (проект) в навигаторе
2. Выбрать **Target → Runner**
3. Вкладка **"Signing & Capabilities"**
4. Нажать **"+ Capability"** и добавить:

   **Background Modes**:
   - ✅ Audio, AirPlay, and Picture in Picture
   - ✅ Voice over IP
   - ✅ Remote notifications

   **Push Notifications**:
   - Просто добавить capability

### 3. Инициализировать iOS CallKit Handler в main.dart

Добавьте в `lib/main.dart` после импортов:

```dart
import 'dart:io';
import 'helpers/ios_callkit_handler.dart';
```

В `initState()` класса `_CallHandlerState` добавьте:

```dart
@override
void initState() {
  super.initState();
  print('[CallHandler] Инициализирован');

  _setupNotificationChannel();

  // ⭐ iOS CallKit
  if (Platform.isIOS) {
    IOSCallKitHandler().initialize();
  }

  if (!kIsWeb) {
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) _setupFCMCallback();
    });
  }
}
```

### 4. Показывать CallKit UI для входящих звонков

В методе где обрабатываются входящие звонки, добавьте:

```dart
// Для iOS - показываем CallKit UI
if (Platform.isIOS) {
  await IOSCallKitHandler().showIncomingCall(
    callId: callId,
    callerName: callerName,
    hasVideo: callType == 'video',
  );
  return; // Не открываем Flutter UI на iOS
}

// Для Android - открываем CallScreen
Navigator.of(context).push(...);
```

### 5. Уведомлять CallKit о статусе звонка

В `webrtc_service.dart`, когда звонок соединяется:

```dart
import '../helpers/ios_callkit_handler.dart';

// При соединении
if (Platform.isIOS) {
  await IOSCallKitHandler().reportCallConnected();
}

// При завершении
if (Platform.isIOS) {
  await IOSCallKitHandler().endCall(callId);
}
```

---

## 🔨 Сборка проекта

### Вариант 1: Flutter CLI
```bash
flutter build ios --debug
```

### Вариант 2: Xcode
1. Открыть `ios/Runner.xcworkspace`
2. Product → Build (⌘B)

### Запуск на устройстве
```bash
# Найти устройство
flutter devices

# Запустить
flutter run -d <device-id>
```

⚠️ **ВАЖНО**: CallKit работает **только на реальном iPhone**, симулятор не поддерживается!

---

## 🎯 Как это работает

### Flow входящего звонка на iOS:

```
1. VoIP Push / FCM
   ↓
2. AppDelegate получает push
   ↓
3. CallKitManager.reportIncomingCall()
   ↓
4. iOS показывает НАТИВНЫЙ CallKit UI
   (полноэкранный, как обычный звонок)
   ↓
5. Пользователь нажимает Accept/Decline
   ↓
6. CallKit вызывает delegate метод
   ↓
7. AppDelegate → Flutter via MethodChannel
   ↓
8. IOSCallKitHandler обрабатывает событие
   ↓
9. WebRTC Service принимает/отклоняет звонок
   ↓
10. CallScreen (Flutter UI) открывается
```

### Преимущества CallKit:

✅ Нативный iOS UI (выглядит как системный звонок)
✅ Работает даже когда приложение убито
✅ Отображается на lockscreen
✅ Интегрируется с историей звонков iOS
✅ Поддержка Bluetooth гарнитур
✅ Автоматическое управление аудио сессией

---

## 🐛 Troubleshooting

### Ошибка: "Module 'CallKit' not found"
**Решение**: Убедитесь что iOS Deployment Target >= 10.0
- В Xcode: Build Settings → iOS Deployment Target → 10.0

### Ошибка: "Use of unresolved identifier"
**Решение**:
1. Убедитесь что Swift файлы добавлены с правильным Target Membership
2. Product → Clean Build Folder (⌘⇧K)
3. Product → Build (⌘B)

### CallKit UI не показывается
**Причины**:
1. ❌ Запущено на симуляторе (используйте реальный iPhone!)
2. ❌ Background Modes не включены
3. ❌ Swift файлы не добавлены в проект

**Проверка**:
- Смотрите логи в Xcode Console
- Должны быть логи: `[CallKit] 📞 ВХОДЯЩИЙ ЗВОНОК`

### Аудио не работает
**Решение**:
- Проверьте что AudioSession настраивается
- Логи: `[AudioSession] 🔊 Настройка Audio Session`
- Убедитесь что микрофон permissions разрешены

---

## 📱 Тестирование

### 1. Build проекта
```bash
flutter build ios --debug
```

### 2. Запуск на iPhone
```bash
flutter run -d <iphone-name>
```

### 3. Отправить входящий звонок
- Со второго устройства позвонить в приложение
- Должен появиться **полноэкранный CallKit UI**
- Нажать Accept → звонок должен соединиться

### Ожидаемое поведение:
✅ CallKit UI показывается полноэкранно
✅ При нажатии Accept - звонок соединяется
✅ Аудио работает через earpiece
✅ Кнопка Speaker переключает на громкую связь
✅ При завершении - CallKit корректно закрывается

---

## 📝 Следующие шаги

### Текущий статус:
- ✅ Android: Полностью работает с нативным UI
- ⏳ iOS: Код создан, требует:
  1. Добавления Swift файлов в Xcode
  2. Включения Capabilities
  3. Тестирования на реальном iPhone

### Опционально (для production):
- 🔒 VoIP Push Certificate в Apple Developer
- 📤 Настройка APNs на сервере
- 🎨 Кастомизация CallKit UI (иконка, рингтон)
- 📊 Аналитика звонков

---

## 🆘 Нужна помощь?

Если что-то не работает:
1. Проверьте что все Swift файлы добавлены в Xcode
2. Убедитесь что Capabilities включены
3. Смотрите логи в Xcode Console
4. Тестируйте только на реальном iPhone (не симулятор!)

Все логи начинаются с префиксов:
- `[CallKit]` - CallKit события
- `[AudioSession]` - Аудио
- `[IOSCallKitHandler]` - Flutter обработчик
- `[IOSCallKit]` - Flutter helper
