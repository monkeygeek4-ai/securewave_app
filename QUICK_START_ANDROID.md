# 🚀 Быстрый старт: Публикация в Google Play

## Шаг 1: Создание keystore (один раз)

```bash
./create_keystore.sh
```

Или вручную:
```bash
cd android
keytool -genkey -v -keystore securewave-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias securewave
```

**Важно:** Запомните пароли!

## Шаг 2: Настройка key.properties

Файл `android/key.properties` уже существует. Убедитесь, что он содержит:

```properties
storePassword=ваш_пароль
keyPassword=ваш_пароль
keyAlias=securewave
storeFile=securewave-release-key.jks
```

## Шаг 3: Сборка AAB

```bash
./build_aab.sh
```

Или вручную:
```bash
flutter build appbundle --release
```

Готовый файл: `build/app/outputs/bundle/release/app-release.aab`

## Шаг 4: Публикация в Google Play

1. Откройте [Google Play Console](https://play.google.com/console)
2. Создайте новое приложение
3. Загрузите AAB файл
4. Заполните информацию о приложении
5. Отправьте на проверку

---

📖 **Подробная инструкция:** См. `ANDROID_PUBLISH_GUIDE.md`

