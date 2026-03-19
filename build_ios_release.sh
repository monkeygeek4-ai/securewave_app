#!/bin/bash

# Скрипт для сборки iOS релизной версии для App Store
# Использование: ./build_ios_release.sh

set -e  # Остановка при ошибке

echo "🚀 Начинаем сборку iOS релизной версии для App Store..."

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Проверка, что мы в корне проекта
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Ошибка: Запустите скрипт из корня проекта${NC}"
    exit 1
fi

# Шаг 1: Очистка проекта
echo -e "${YELLOW}📦 Шаг 1: Очистка проекта...${NC}"
flutter clean
echo -e "${GREEN}✅ Проект очищен${NC}"

# Шаг 2: Получение зависимостей
echo -e "${YELLOW}📦 Шаг 2: Получение зависимостей Flutter...${NC}"
flutter pub get
echo -e "${GREEN}✅ Зависимости Flutter получены${NC}"

# Шаг 3: Обновление CocoaPods
echo -e "${YELLOW}📦 Шаг 3: Обновление CocoaPods...${NC}"
cd ios
pod deintegrate 2>/dev/null || true
pod install
cd ..
echo -e "${GREEN}✅ CocoaPods обновлены${NC}"

# Шаг 4: Проверка версии
echo -e "${YELLOW}📋 Шаг 4: Проверка версии приложения...${NC}"
VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
echo -e "${GREEN}✅ Текущая версия: $VERSION${NC}"

# Шаг 5: Сборка IPA
echo -e "${YELLOW}🏗️  Шаг 5: Сборка IPA файла...${NC}"
echo -e "${YELLOW}   Это может занять несколько минут...${NC}"

# Сборка с использованием ExportOptions.plist
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

# Проверка результата
if [ -f "build/ios/ipa/securewave_app.ipa" ]; then
    IPA_SIZE=$(du -h build/ios/ipa/securewave_app.ipa | cut -f1)
    echo -e "${GREEN}✅ IPA файл успешно создан!${NC}"
    echo -e "${GREEN}   Размер: $IPA_SIZE${NC}"
    echo -e "${GREEN}   Путь: build/ios/ipa/securewave_app.ipa${NC}"
    echo ""
    echo -e "${GREEN}📤 Следующие шаги:${NC}"
    echo -e "   1. Откройте Xcode: open ios/Runner.xcworkspace"
    echo -e "   2. Product → Archive"
    echo -e "   3. В Organizer выберите архив и нажмите 'Distribute App'"
    echo -e "   4. Или используйте Transporter для загрузки IPA файла"
    echo ""
    echo -e "${GREEN}🎉 Готово!${NC}"
else
    echo -e "${RED}❌ Ошибка: IPA файл не найден${NC}"
    echo -e "${YELLOW}Проверьте логи выше для деталей${NC}"
    exit 1
fi

