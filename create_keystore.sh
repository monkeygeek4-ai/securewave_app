#!/bin/bash

# ⭐⭐⭐ Скрипт для создания keystore для подписи Android приложения
# Использование: ./create_keystore.sh

echo "=========================================="
echo "🔐 Создание keystore для SecureWave"
echo "=========================================="
echo ""

# Переходим в директорию android
cd "$(dirname "$0")/android" || exit 1

# Проверяем, существует ли уже keystore
if [ -f "securewave-release-key.jks" ]; then
    echo "⚠️  Keystore уже существует: securewave-release-key.jks"
    read -p "Перезаписать? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Отменено"
        exit 1
    fi
    rm -f securewave-release-key.jks
fi

echo "📝 Заполните следующие данные:"
echo ""

# Создаем keystore
keytool -genkey -v -keystore securewave-release-key.jks \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias securewave

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ Keystore успешно создан!"
    echo "=========================================="
    echo ""
    echo "📁 Файл: android/securewave-release-key.jks"
    echo ""
    echo "⚠️  ВАЖНО:"
    echo "1. Сохраните keystore в безопасном месте"
    echo "2. Запомните пароли (storePassword и keyPassword)"
    echo "3. Без keystore вы не сможете обновлять приложение!"
    echo ""
    echo "📝 Теперь обновите android/key.properties:"
    echo "   storePassword=ваш_пароль"
    echo "   keyPassword=ваш_пароль"
    echo "   keyAlias=securewave"
    echo "   storeFile=securewave-release-key.jks"
    echo ""
else
    echo ""
    echo "❌ Ошибка при создании keystore"
    exit 1
fi

