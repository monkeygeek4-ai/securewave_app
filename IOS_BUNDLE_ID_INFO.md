# ℹ️ Информация о Bundle ID и Package Names

## 📱 iOS

**Bundle ID:** `com.securewavenew.app`

Где используется:
- ✅ Xcode проект (`ios/Runner.xcodeproj`)
- ✅ App ID в Apple Developer Portal
- ✅ VoIP Push Certificate topic: `com.securewavenew.app.voip`
- ✅ Документация обновлена

## 🤖 Android

**Package Name:** `com.securewave.app`

Где используется:
- ✅ `android/app/build.gradle`
- ✅ `AndroidManifest.xml`
- ✅ Kotlin файлы (`MainActivity.kt`, и т.д.)

## 📡 Method Channels

**Channel Names:** `com.securewave.app/...`

Это НЕ Bundle ID! Это просто имена для коммуникации между Flutter и Native:
- `com.securewave.app/call`
- `com.securewave.app/notification`
- `com.securewave.app/audio`
- `com.securewave.app/callkit`

Менять их НЕ нужно! Они могут быть любыми.

## ⚠️ Важно!

**iOS Bundle ID** и **Android Package Name** - это РАЗНЫЕ вещи и могут отличаться:
- iOS: `com.securewavenew.app`
- Android: `com.securewave.app`

Это нормально и не вызывает проблем!

## 🔧 Если нужно изменить

### iOS Bundle ID
1. Xcode → Runner → Signing & Capabilities → Bundle Identifier
2. Обновить в Apple Developer Portal
3. Пересоздать сертификаты и provisioning profiles

### Android Package Name
1. Обновить в `android/app/build.gradle`
2. Обновить в `AndroidManifest.xml`
3. Переименовать папки в `android/app/src/main/kotlin/...`
4. Обновить package в Kotlin файлах
