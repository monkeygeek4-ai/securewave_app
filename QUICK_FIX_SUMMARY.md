# ⚡ Быстрое исправление отклонения App Store

## ❌ Проблема
Apple отклонил приложение из-за упоминаний "Messenger" в метаданных.

## ✅ Что уже исправлено

1. ✅ `pubspec.yaml` - описание изменено
2. ✅ `web/index.html` - meta description обновлен
3. ✅ Build number увеличен: `1.0.0+2`
4. ✅ Создан файл с исправленными описаниями: `APP_STORE_DESCRIPTION_FIXED.md`

## 📝 Что нужно сделать СЕЙЧАС

### 1. Обновить метаданные в App Store Connect

Войдите в [App Store Connect](https://appstoreconnect.apple.com) и измените:

**Подзаголовок:**
- ❌ "Безопасный мессенджер"
- ✅ "Безопасный чат"

**Описание:**
Используйте вариант из `APP_STORE_DESCRIPTION_FIXED.md` (без слова "мессенджер")

**Ключевые слова:**
- ❌ `мессенджер,безопасность,шифрование...`
- ✅ `чат,безопасность,шифрование,звонки,общение,приватность,webrtc`

### 2. Пересобрать приложение

```bash
cd /Users/vladimir/development/securewave_app
flutter clean
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

В Xcode:
- Product → Archive
- Distribute App → App Store Connect → Upload

### 3. Отправить на повторное рассмотрение

После загрузки нового билда отправьте на модерацию.

---

**Все файлы готовы! Обновите метаданные в App Store Connect и загрузите новую версию! 🚀**

