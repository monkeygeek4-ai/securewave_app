# 📱 Инструкция по публикации SecureWave в Google Play Store

## 📋 Содержание
1. [Подготовка keystore для подписи приложения](#1-подготовка-keystore)
2. [Настройка подписи в build.gradle](#2-настройка-подписи)
3. [Сборка AAB файла](#3-сборка-aab-файла)
4. [Создание приложения в Google Play Console](#4-создание-приложения)
5. [Загрузка и публикация](#5-загрузка-и-публикация)
6. [Требования Google Play](#6-требования-google-play)

---

## 1. Подготовка keystore

### Шаг 1.1: Создание keystore файла

Выполните команду в терминале (в корне проекта):

```bash
cd android
keytool -genkey -v -keystore securewave-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias securewave
```

**Важно:** Запомните или сохраните в безопасном месте:
- **Пароль keystore** (будет запрошен дважды)
- **Пароль alias** (можно использовать тот же)
- **Имя и организация** (можно указать любые)

**Пример ответов:**
```
Введите пароль хранилища ключей: [ваш_пароль]
Повторно введите пароль хранилища ключей: [ваш_пароль]
Введите имя и фамилию: SecureWave
Введите название организационного подразделения: Development
Введите название организации: SecureWave
Введите название города: Moscow
Введите название штата или области: Moscow
Введите двухбуквенный код страны: RU
```

### Шаг 1.2: Обновление key.properties

Файл `android/key.properties` уже существует. Обновите его следующим содержимым:

```properties
storePassword=ваш_пароль_keystore
keyPassword=ваш_пароль_alias
keyAlias=securewave
storeFile=securewave-release-key.jks
```

**⚠️ ВАЖНО:** 
- НЕ коммитьте `key.properties` и `securewave-release-key.jks` в Git!
- Добавьте их в `.gitignore`
- Храните keystore в безопасном месте (облако, зашифрованный архив)

---

## 2. Настройка подписи

### Шаг 2.1: Обновление build.gradle

Откройте файл `android/app/build.gradle` и замените секцию `android`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.withReader('UTF-8') { reader ->
        keystoreProperties.load(reader)
    }
}

android {
    namespace "com.securewave.app"
    compileSdk 36
    ndkVersion flutter.ndkVersion

    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_11
        targetCompatibility JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = '11'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "com.securewave.app"
        minSdkVersion flutter.minSdkVersion
        targetSdk 36
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
        multiDexEnabled true
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled false
            shrinkResources false
        }
    }
}
```

---

## 3. Сборка AAB файла

### Шаг 3.1: Обновление версии

В файле `pubspec.yaml` обновите версию:

```yaml
version: 1.0.0+1  # Формат: versionName+versionCode
```

**Где:**
- `1.0.0` - версия приложения (versionName)
- `1` - номер сборки (versionCode) - должен увеличиваться с каждой публикацией

### Шаг 3.2: Сборка AAB

Выполните команду:

```bash
flutter build appbundle --release
```

Готовый файл будет находиться в:
```
build/app/outputs/bundle/release/app-release.aab
```

**Размер файла:** обычно 20-50 МБ

---

## 4. Создание приложения в Google Play Console

### Шаг 4.1: Регистрация аккаунта разработчика

1. Перейдите на https://play.google.com/console
2. Зарегистрируйте аккаунт разработчика (одноразовый платеж $25)
3. Заполните профиль разработчика

### Шаг 4.2: Создание нового приложения

1. Нажмите **"Создать приложение"**
2. Заполните информацию:
   - **Название приложения:** SecureWave
   - **Язык по умолчанию:** Русский
   - **Тип приложения:** Приложение
   - **Бесплатное или платное:** Бесплатное

---

## 5. Загрузка и публикация

### Шаг 5.1: Заполнение информации о приложении

#### 5.1.1. Основная информация
- **Краткое описание:** Безопасный мессенджер с шифрованием
- **Полное описание:** 
```
SecureWave - это современный мессенджер с end-to-end шифрованием для безопасного общения.

Основные возможности:
• Безопасные текстовые сообщения
• Голосовые и видеозвонки
• Отправка медиафайлов
• Групповые чаты
• Push-уведомления
• Темная тема

Все данные защищены современными алгоритмами шифрования.
```

#### 5.1.2. Графические материалы

**Требуемые изображения:**
- **Иконка приложения:** 512x512 px (PNG, без прозрачности)
- **Скриншоты:** Минимум 2, максимум 8
  - Телефон: минимум 320px, максимум 3840px (ширина или высота)
  - Планшет: минимум 320px, максимум 3840px
- **Промо-графика:** 1024x500 px (опционально)

**Рекомендуемые размеры скриншотов:**
- 1080x1920 px (9:16) для телефонов
- 1920x1080 px (16:9) для планшетов

#### 5.1.3. Категория и теги
- **Категория:** Коммуникации
- **Теги:** мессенджер, безопасность, шифрование, чат

### Шаг 5.2: Загрузка AAB файла

1. Перейдите в раздел **"Выпуск" → "Производство"** (или **"Тестирование"** для бета-версии)
2. Нажмите **"Создать выпуск"**
3. Загрузите файл `app-release.aab`
4. Заполните **"Примечания к выпуску"** (что нового в этой версии)

### Шаг 5.3: Контент приложения

#### 5.3.1. Рейтинг контента
Заполните анкету о контенте:
- **Категория:** Коммуникации
- **Возрастной рейтинг:** PEGI 3 / 3+ (для всех возрастов)

#### 5.3.2. Политика конфиденциальности
- Создайте страницу политики конфиденциальности
- URL: `https://securewave.sbk-19.ru/privacy`
- Укажите этот URL в настройках приложения

### Шаг 5.4: Целевая аудитория и контент

1. **Целевая аудитория:** Для всех возрастов
2. **Категория контента:** Коммуникации
3. **Рейтинг:** Заполните анкету Google Play

---

## 6. Требования Google Play

### 6.1. Политика конфиденциальности
- ✅ Уже создана: `https://securewave.sbk-19.ru/privacy`

### 6.2. Разрешения
Все необходимые разрешения уже указаны в `AndroidManifest.xml`:
- Интернет
- Камера
- Микрофон
- Уведомления
- Хранилище (для Android 12 и ниже)

### 6.3. Целевой SDK
- ✅ `targetSdk 36` (Android 14) - актуальная версия

### 6.4. Подпись приложения
- ✅ Настроена через keystore

---

## 7. Публикация

### Шаг 7.1: Проверка перед публикацией

Убедитесь, что:
- [ ] AAB файл загружен
- [ ] Все скриншоты добавлены
- [ ] Описание приложения заполнено
- [ ] Политика конфиденциальности указана
- [ ] Рейтинг контента заполнен
- [ ] Иконка приложения загружена

### Шаг 7.2: Отправка на проверку

1. Нажмите **"Отправить на проверку"**
2. Ожидайте проверку Google (обычно 1-3 дня)
3. После одобрения приложение будет доступно в Google Play

---

## 8. Обновление приложения

Для обновления приложения:

1. Увеличьте `versionCode` в `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2  # +1 к versionCode
   ```

2. Соберите новый AAB:
   ```bash
   flutter build appbundle --release
   ```

3. Загрузите новый AAB в Google Play Console

---

## 9. Важные замечания

### ⚠️ Безопасность keystore
- **НЕ теряйте keystore файл!** Без него вы не сможете обновлять приложение
- Храните keystore в безопасном месте (облако, зашифрованный архив)
- Рекомендуется создать резервную копию

### 📝 Версионирование
- `versionCode` должен увеличиваться с каждой публикацией
- `versionName` может быть любым (например, 1.0.0, 1.0.1, 1.1.0)

### 🔒 Подпись приложения
- Google Play автоматически подписывает приложения дополнительным ключом
- Ваш keystore используется для подписи AAB перед загрузкой

---

## 10. Полезные ссылки

- [Google Play Console](https://play.google.com/console)
- [Документация Flutter по публикации](https://docs.flutter.dev/deployment/android)
- [Требования Google Play](https://support.google.com/googleplay/android-developer)

---

## 📞 Поддержка

При возникновении проблем:
1. Проверьте логи сборки: `flutter build appbundle --release -v`
2. Убедитесь, что все зависимости установлены: `flutter pub get`
3. Очистите кэш: `flutter clean && flutter pub get`

---

**Удачи с публикацией! 🚀**

