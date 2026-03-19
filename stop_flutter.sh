#!/bin/bash
# Остановить все процессы Flutter

echo "🛑 Останавливаем все процессы Flutter..."

pkill -f "flutter.*run" 2>/dev/null
pkill -f "flutter.*logs" 2>/dev/null
pkill -f "idevicesyslog" 2>/dev/null

echo "✅ Все процессы Flutter остановлены"
echo ""
echo "Теперь можно запустить:"
echo "  flutter run --debug -d 00008140-001C5C820C09801C"
echo "  или"
echo "  open ios/Runner.xcworkspace"

