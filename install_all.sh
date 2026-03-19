#!/bin/bash

echo "📱 Установка на все подключенные устройства..."

for device in $(adb devices | grep -v "List" | grep "device" | awk '{print $1}'); do
    echo ""
    echo "========================================="
    echo "📲 Установка на устройство: $device"
    echo "========================================="
    adb -s $device install -r build/app/outputs/flutter-apk/app-release.apk
    
    if [ $? -eq 0 ]; then
        echo "✅ Установлено на $device"
    else
        echo "❌ Ошибка установки на $device"
    fi
done

echo ""
echo "========================================="
echo "✅ Установка завершена на всех устройствах!"
echo "========================================="