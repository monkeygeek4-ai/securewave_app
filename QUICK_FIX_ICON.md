# ⚡ Быстрое исправление: Иконка 1024x1024

## ❌ Проблема

Текущая иконка имеет размер **960x960**, а требуется **1024x1024**.

## ✅ Решение

### Вариант 1: Масштабирование существующей иконки (БЫСТРО)

```bash
cd /Users/vladimir/development/securewave_app

# Используем sips (встроенная утилита macOS) для масштабирования
sips -z 1024 1024 ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png --out ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png

# Проверка размера
file ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
# Должно показать: PNG image data, 1024 x 1024, ...
```

### Вариант 2: Создание новой иконки (РЕКОМЕНДУЕТСЯ)

1. Откройте исходную иконку в графическом редакторе (Photoshop, GIMP, Preview)
2. Измените размер на **1024x1024 пикселей**
3. Сохраните как PNG без прозрачности
4. Замените файл:
   ```bash
   # Скопируйте новую иконку в папку
   cp /путь/к/новой/иконке.png ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
   ```

### Вариант 3: Через Xcode

1. Откройте проект:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. В навигаторе: `Runner` → `Assets.xcassets` → `AppIcon`

3. Найдите ячейку **"1024pt"** → **"Any Appearance"**

4. Удалите старую иконку (если есть)

5. Перетащите новую иконку 1024x1024 в эту ячейку

6. Сохраните (Cmd + S)

## 🔄 После исправления

```bash
# Очистка
flutter clean
rm -rf ios/build

# Пересборка
flutter pub get
cd ios && pod install && cd ..

# Проверка
flutter build ios --release --no-codesign
```

## ✅ Проверка

```bash
# Проверка размера файла
file ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png

# Должно показать: PNG image data, 1024 x 1024, ...
```

## 📝 Требования к иконке

- ✅ Размер: **1024x1024 пикселей** (точно!)
- ✅ Формат: PNG
- ✅ Без прозрачности (RGB, не RGBA)
- ✅ Без закругленных углов (Apple добавит автоматически)
- ✅ Квадратная форма

---

**После исправления создайте новый архив и загрузите в App Store Connect!**

