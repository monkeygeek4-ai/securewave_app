# 📸 Скриншоты для App Store

## ✅ Преобразованные изображения

Все изображения преобразованы под требуемые размеры для App Store.

### Размеры:

1. **1242 × 2688px** - для iPhone 6.5" (iPhone 11 Pro Max, XS Max)
2. **1284 × 2778px** - для iPhone 6.7" (iPhone 14 Pro Max, 15 Pro Max)

### Файлы:

Все преобразованные файлы находятся в папке `converted/`:

- `IMG_7472_1242x2688.png` - 1242 × 2688px
- `IMG_7472_1284x2778.png` - 1284 × 2778px
- `IMG_7473_1242x2688.png` - 1242 × 2688px
- `IMG_7473_1284x2778.png` - 1284 × 2778px
- `IMG_7474_1242x2688.png` - 1242 × 2688px
- `IMG_7474_1284x2778.png` - 1284 × 2778px

### Исходные файлы:

- `IMG_7472.PNG` - 1320 × 2868px (оригинал)
- `IMG_7473.PNG` - 1320 × 2868px (оригинал)
- `IMG_7474.PNG` - 1320 × 2868px (оригинал)

## 📱 Использование в App Store Connect

### Для iPhone 6.5":
Используйте файлы с суффиксом `_1242x2688.png`

### Для iPhone 6.7":
Используйте файлы с суффиксом `_1284x2778.png`

## 🔄 Если нужно преобразовать заново

```bash
cd /Users/vladimir/development/securewave_app/photo

# Для размера 1242 × 2688px
sips -z 2688 1242 IMG_7472.PNG --out converted/IMG_7472_1242x2688.png

# Для размера 1284 × 2778px
sips -z 2778 1284 IMG_7472.PNG --out converted/IMG_7472_1284x2778.png
```

## ✅ Проверка размеров

```bash
cd converted
sips -g pixelWidth -g pixelHeight *.png | grep -E "pixelWidth|pixelHeight"
```

---

**Готово к загрузке в App Store Connect! 🚀**

