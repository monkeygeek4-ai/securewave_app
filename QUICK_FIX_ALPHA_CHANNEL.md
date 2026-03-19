# ⚡ Быстрое исправление: Удаление альфа-канала из иконки

## ❌ Проблема

```
Invalid large app icon. The large app icon can't be transparent or contain an alpha channel.
```

Иконка содержит альфа-канал (прозрачность), а Apple требует RGB формат без прозрачности.

## ✅ Решение (УЖЕ ПРИМЕНЕНО)

Иконка уже исправлена! Проверка:

```bash
file ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
```

**Должно показать:** `PNG image data, 1024 x 1024, 8-bit/color RGB, non-interlaced`
**НЕ должно быть:** `RGBA` (это означает наличие альфа-канала)

## 🔄 Если нужно исправить вручную

### Метод 1: Через sips (macOS)

```bash
cd /Users/vladimir/development/securewave_app

# Конвертация через JPEG (убирает альфа-канал)
sips -s format jpeg -s formatOptions high \
  ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png \
  --out /tmp/icon.jpg

# Обратно в PNG (теперь без альфа-канала)
sips -s format png /tmp/icon.jpg \
  --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png

# Проверка
file ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
```

### Метод 2: Через графический редактор

1. Откройте иконку в Preview, Photoshop или другом редакторе
2. Убедитесь, что размер 1024x1024
3. **Сохраните как PNG БЕЗ прозрачности** (RGB, не RGBA)
4. Замените файл в `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

### Метод 3: Через Xcode

1. Откройте `ios/Runner.xcworkspace`
2. `Runner` → `Assets.xcassets` → `AppIcon`
3. Удалите старую иконку 1024x1024
4. Перетащите новую иконку **БЕЗ прозрачности**
5. Сохраните (Cmd + S)

## ✅ Требования к иконке

- ✅ Размер: **1024x1024 пикселей** (точно!)
- ✅ Формат: PNG
- ✅ **БЕЗ прозрачности** (RGB, НЕ RGBA!)
- ✅ Без закругленных углов
- ✅ Квадратная форма

## 🔄 После исправления

```bash
# Очистка
flutter clean
rm -rf ios/build

# Пересборка
flutter pub get
cd ios && pod install && cd ..

# Создание нового архива в Xcode
open ios/Runner.xcworkspace
```

---

**Иконка уже исправлена! Создайте новый архив и загрузите в App Store Connect.**

