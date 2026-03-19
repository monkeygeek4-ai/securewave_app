# 🔧 Исправление ошибок при загрузке в App Store

## ❌ Ошибка 1: Missing app icon или Invalid large app icon

### Проблема A: Missing app icon
```
Missing app icon. Include a large app icon as a 1024 by 1024 pixel PNG
```

### Проблема B: Invalid large app icon (прозрачность)
```
Invalid large app icon. The large app icon can't be transparent or contain an alpha channel.
```

### Проблема:
```
Missing app icon. Include a large app icon as a 1024 by 1024 pixel PNG 
for the 'Any Appearance' image well in the asset catalog.
```

### Решение:

#### Вариант 1: Проверка в Xcode (РЕКОМЕНДУЕТСЯ)

1. Откройте проект в Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. В навигаторе проекта:
   - Откройте `Runner` → `Assets.xcassets` → `AppIcon`

3. Проверьте наличие иконки 1024x1024:
   - Должна быть заполнена ячейка **"iOS App Icon"** → **"1024pt"** → **"Any Appearance"**
   - Если ячейка пустая, перетащите файл `Icon-App-1024x1024@1x.png` в эту ячейку

4. Убедитесь, что файл:
   - Имеет размер 1024x1024 пикселей
   - Формат PNG
   - Без прозрачности
   - Без закругленных углов

5. Сохраните изменения (Cmd + S)

6. Очистите и пересоберите:
   ```bash
   cd ios
   rm -rf build
   cd ..
   flutter clean
   flutter pub get
   cd ios && pod install && cd ..
   ```

#### Вариант 2: Исправление прозрачности (альфа-канал)

Если иконка содержит альфа-канал (прозрачность), нужно конвертировать в RGB:

```bash
cd /Users/vladimir/development/securewave_app

# Метод 1: Через JPEG (убирает альфа-канал)
sips -s format jpeg -s formatOptions high \
  ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png \
  --out /tmp/icon.jpg
sips -s format png /tmp/icon.jpg \
  --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png

# Проверка результата
file ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
# Должно показать: PNG image data, 1024 x 1024, 8-bit/color RGB (не RGBA!)
```

#### Вариант 3: Проверка файла иконки

Проверьте, что файл существует и имеет правильный размер:

```bash
# Проверка размера и формата файла
file ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png

# Должно показать: PNG image data, 1024 x 1024, 8-bit/color RGB, non-interlaced
# НЕ должно быть: RGBA (это означает наличие альфа-канала)
```

Если файл отсутствует или неправильного размера:
1. Создайте иконку 1024x1024 пикселей
2. Сохраните как PNG **БЕЗ прозрачности** (RGB, не RGBA)
3. Поместите в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
4. Обновите в Xcode (см. Вариант 1)

---

## ❌ Ошибка 2: Upload Symbols Failed (WebRTC.framework)

### Проблема:
```
The archive did not include a dSYM for the WebRTC.framework with the UUIDs [...]
```

### Причина:
WebRTC.framework из flutter_webrtc не включает dSYM файлы, которые Apple требует для загрузки символов отладки.

### Решение:

#### Вариант 1: Отключить загрузку символов (БЫСТРОЕ РЕШЕНИЕ) ✅ УЖЕ ПРИМЕНЕНО

Файл `ios/ExportOptions.plist` уже настроен правильно:

```xml
<key>uploadSymbols</key>
<false/>
```

⚠️ **Важно:** Если ошибка все еще появляется, это может быть предупреждение, которое не блокирует загрузку. Проверьте статус в App Store Connect - если приложение все равно загружается, можно игнорировать это предупреждение.

**Недостаток:** Не будет символов отладки для crash reports (но приложение будет принято)

#### Вариант 2: Настроить Podfile для генерации dSYM (РЕКОМЕНДУЕТСЯ)

Обновите `ios/Podfile`:

```ruby
# Uncomment this line to define a global platform for your project
platform :ios, '13.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      
      # Генерация dSYM для всех фреймворков
      config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf-with-dsym'
      
      # Исключаем WebRTC из проверки символов (если проблема сохраняется)
      if target.name == 'WebRTC-SDK'
        config.build_settings['STRIP_INSTALLED_PRODUCT'] = 'NO'
      end
    end
  end
end
```

После обновления Podfile:

```bash
cd ios
pod deintegrate
pod install
cd ..
```

#### Вариант 3: Игнорировать предупреждение (если не критично)

Если ошибка не блокирует загрузку, можно игнорировать. Apple иногда принимает приложения с этой ошибкой, но с предупреждением.

---

## 🔄 Полная последовательность исправления

### Шаг 1: Исправить иконку

1. Откройте Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. Проверьте иконку 1024x1024 в Assets.xcassets

3. Если нужно, перетащите файл в ячейку

### Шаг 2: Исправить проблему с WebRTC

**Выберите один из вариантов:**

**A. Быстрое решение (отключить символы):**
```bash
# Обновите ExportOptions.plist (см. Вариант 1 выше)
# Затем пересоберите
flutter clean
flutter pub get
cd ios && pod install && cd ..
```

**B. Полное решение (настроить dSYM):**
```bash
# Обновите Podfile (см. Вариант 2 выше)
cd ios
pod deintegrate
pod install
cd ..
```

### Шаг 3: Очистка и пересборка

```bash
# Полная очистка
flutter clean
rm -rf ios/build
rm -rf build

# Обновление зависимостей
flutter pub get
cd ios
pod deintegrate
pod install
cd ..

# Сборка для проверки
flutter build ios --release --no-codesign
```

### Шаг 4: Создание архива заново

1. Откройте Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. В Xcode:
   - **Product** → **Clean Build Folder** (Shift + Cmd + K)
   - Выберите **Any iOS Device**
   - **Product** → **Archive**

3. После архивации:
   - **Distribute App** → **App Store Connect** → **Upload**

---

## ✅ Проверка перед загрузкой

### Проверка иконки:
- [ ] Иконка 1024x1024 есть в Assets.xcassets
- [ ] Иконка заполнена в Xcode (ячейка "Any Appearance")
- [ ] Файл имеет размер 1024x1024 пикселей
- [ ] Формат PNG без прозрачности

### Проверка WebRTC:
- [ ] ExportOptions.plist обновлен (если выбрали отключение символов)
- [ ] Или Podfile обновлен (если выбрали настройку dSYM)
- [ ] pod install выполнен успешно

### Проверка сборки:
- [ ] Проект собирается без ошибок
- [ ] Архив создается успешно
- [ ] Нет предупреждений о иконке
- [ ] Нет критических ошибок о символах

---

## 🆘 Если проблемы сохраняются

### Проблема с иконкой:

1. **Удалите и пересоздайте иконку:**
   ```bash
   # Удалите старую иконку
   rm ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
   
   # Создайте новую иконку 1024x1024
   # Поместите в папку и обновите в Xcode
   ```

2. **Проверьте Contents.json:**
   - Убедитесь, что запись для 1024x1024 правильная
   - Файл должен быть указан как `Icon-App-1024x1024@1x.png`

### Проблема с WebRTC:

1. **Попробуйте обновить flutter_webrtc:**
   ```bash
   flutter pub upgrade flutter_webrtc
   cd ios && pod update WebRTC-SDK && cd ..
   ```

2. **Или используйте отключение символов:**
   - Это безопасно и не влияет на функциональность
   - Просто не будет символов для crash reports

3. **Проверьте версию WebRTC:**
   ```bash
   cat ios/Podfile.lock | grep WebRTC
   ```

---

## 📝 Примечания

- **Иконка обязательна** - без неё приложение не будет принято
- **Символы WebRTC** - это предупреждение, можно отключить загрузку символов
- **После исправлений** всегда делайте полную очистку перед сборкой

---

**После исправления ошибок повторите загрузку в App Store Connect! 🚀**

