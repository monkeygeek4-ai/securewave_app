# 📱 Публикация SecureWave в Google Play Store

## ✅ Быстрая проверка готовности

Перед началом убедитесь, что у вас есть:

- [ ] Аккаунт разработчика Google Play ($25 единоразово)
- [ ] Keystore файл для подписи приложения
- [ ] Настроенный `android/key.properties`
- [ ] Обновленный `android/app/build.gradle`

---

## 🚀 Быстрый старт (3 шага)

### 1️⃣ Создание keystore (если еще не создан)

```bash
./create_keystore.sh
```

**Или вручную:**
```bash
cd android
keytool -genkey -v -keystore securewave-release-key.jks \
    -keyalg RSA -keysize 2048 -validity 10000 -alias securewave
```

**Важно:** Запомните пароли! Без keystore вы не сможете обновлять приложение.

### 2️⃣ Проверка key.properties

Убедитесь, что файл `android/key.properties` содержит:

```properties
storePassword=ваш_пароль
keyPassword=ваш_пароль
keyAlias=securewave
storeFile=./securewave-release-key.jks
```

### 3️⃣ Сборка AAB

```bash
./build_aab.sh
```

**Или вручную:**
```bash
flutter build appbundle --release
```

Готовый файл: `build/app/outputs/bundle/release/app-release.aab`

---

## 📋 Подробная инструкция

См. файл **`ANDROID_PUBLISH_GUIDE.md`** для полной инструкции по:
- Созданию keystore
- Настройке подписи
- Заполнению информации в Google Play Console
- Загрузке и публикации приложения

---

## 📁 Созданные файлы

1. **`ANDROID_PUBLISH_GUIDE.md`** - Полная инструкция по публикации
2. **`QUICK_START_ANDROID.md`** - Краткая инструкция
3. **`create_keystore.sh`** - Скрипт для создания keystore
4. **`build_aab.sh`** - Скрипт для сборки AAB
5. **`android/key.properties.example`** - Пример файла конфигурации

---

## ⚠️ Важные замечания

### Безопасность keystore
- **НЕ коммитьте** `key.properties` и `*.jks` в Git (уже добавлены в `.gitignore`)
- Храните keystore в безопасном месте
- Создайте резервную копию keystore

### Версионирование
В `pubspec.yaml`:
```yaml
version: 1.0.0+1  # Формат: versionName+versionCode
```

- `1.0.0` - версия приложения (может быть любой)
- `1` - номер сборки (должен увеличиваться с каждой публикацией)

### Обновление приложения
1. Увеличьте `versionCode` в `pubspec.yaml`
2. Соберите новый AAB: `./build_aab.sh`
3. Загрузите в Google Play Console

---

## 🔗 Полезные ссылки

- [Google Play Console](https://play.google.com/console)
- [Документация Flutter](https://docs.flutter.dev/deployment/android)
- [Требования Google Play](https://support.google.com/googleplay/android-developer)

---

**Удачи с публикацией! 🚀**

