#!/bin/bash

# Скрипт для быстрой установки приложения на iPhone

echo "🚀 Подготовка к установке на iPhone..."
echo ""

# Очистка
echo "📦 Очистка проекта..."
flutter clean
flutter pub get

# Обновление iOS зависимостей
echo "📱 Обновление iOS зависимостей..."
cd ios
pod install
cd ..

# Проверка устройств
echo ""
echo "📱 Проверка подключенных устройств..."
flutter devices

echo ""
echo "✅ Готово к установке!"
echo ""
echo "Для установки выполните:"
echo "  flutter run --release"
echo ""
echo "Или откройте Xcode:"
echo "  open ios/Runner.xcworkspace"
echo ""
