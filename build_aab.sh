#!/bin/bash

# ⭐⭐⭐ Скрипт для сборки AAB файла для публикации в Google Play
# Использование: ./build_aab.sh

echo "=========================================="
echo "📦 Сборка AAB файла для Google Play"
echo "=========================================="
echo ""

# Проверяем наличие key.properties
if [ ! -f "android/key.properties" ]; then
    echo "❌ Файл android/key.properties не найден!"
    echo ""
    echo "Создайте keystore и настройте key.properties:"
    echo "1. Запустите: ./create_keystore.sh"
    echo "2. Или создайте вручную: android/key.properties"
    echo ""
    exit 1
fi

# Проверяем наличие keystore
KEYSTORE_FILE=$(grep "storeFile=" android/key.properties | cut -d'=' -f2)
if [ -z "$KEYSTORE_FILE" ]; then
    echo "❌ storeFile не указан в key.properties"
    exit 1
fi

# Проверяем существование файла keystore
if [ ! -f "android/$KEYSTORE_FILE" ]; then
    echo "❌ Keystore файл не найден: android/$KEYSTORE_FILE"
    echo ""
    echo "Создайте keystore:"
    echo "  ./create_keystore.sh"
    echo ""
    exit 1
fi

echo "✅ Keystore найден: android/$KEYSTORE_FILE"
echo ""

# Очищаем предыдущие сборки
echo "🧹 Очистка предыдущих сборок..."
flutter clean
echo ""

# Получаем зависимости
echo "📥 Получение зависимостей..."
flutter pub get
echo ""

# Собираем AAB
echo "🔨 Сборка AAB файла..."
flutter build appbundle --release

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ AAB файл успешно собран!"
    echo "=========================================="
    echo ""
    echo "📁 Файл: build/app/outputs/bundle/release/app-release.aab"
    echo ""
    echo "📤 Следующие шаги:"
    echo "1. Откройте Google Play Console"
    echo "2. Перейдите в раздел 'Выпуск' → 'Производство'"
    echo "3. Нажмите 'Создать выпуск'"
    echo "4. Загрузите файл app-release.aab"
    echo ""
else
    echo ""
    echo "❌ Ошибка при сборке AAB"
    exit 1
fi

