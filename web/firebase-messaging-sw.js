// web/firebase-messaging-sw.js
// Service Worker для обработки push-уведомлений SecureWave

console.log('[firebase-messaging-sw.js] 🔥 Загрузка Service Worker...');

// ========================================
// ИМПОРТ FIREBASE SDK
// ========================================
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

console.log('[firebase-messaging-sw.js] ✅ Firebase SDK загружен');

// ========================================
// ИНИЦИАЛИЗАЦИЯ FIREBASE
// ВАЖНО: Конфигурация ДОЛЖНА СОВПАДАТЬ с index.html!
// ========================================
firebase.initializeApp({
  apiKey: 'AIzaSyAW5HurHMo1l9ub2XKyr2nk-yP22bc_6F4',
  authDomain: 'wave-messenger-56985.firebaseapp.com',
  projectId: 'wave-messenger-56985',
  storageBucket: 'wave-messenger-56985.firebasestorage.app',
  messagingSenderId: '394959992893',
  appId: '1:394959992893:web:c7d493658ad06278661254'
});

const messaging = firebase.messaging();

console.log('[firebase-messaging-sw.js] ✅ Firebase инициализирован');

// ========================================
// ФУНКЦИЯ ОБНОВЛЕНИЯ TITLE
// ========================================
function updatePageTitle(increment = 1) {
  console.log('[firebase-messaging-sw.js] 📋 Обновляем title страницы, increment:', increment);
  
  // Отправляем сообщение всем открытым вкладкам/окнам приложения
  self.clients.matchAll({ 
    type: 'window', 
    includeUncontrolled: true 
  }).then(clients => {
    console.log('[firebase-messaging-sw.js] 📤 Отправляем UPDATE_TITLE в', clients.length, 'клиентов');
    
    clients.forEach(client => {
      client.postMessage({
        type: 'UPDATE_TITLE',
        increment: increment
      });
    });
  });
}

// ========================================
// ОБРАБОТКА ФОНОВЫХ УВЕДОМЛЕНИЙ
// Срабатывает когда приложение не в фокусе
// ========================================
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] 📨 Received background message:', payload);
  
  const data = payload.data || {};
  const type = data.type;
  
  console.log('[firebase-messaging-sw.js] Message type:', type);
  console.log('[firebase-messaging-sw.js] Message data:', data);
  
  let notificationTitle = payload.notification?.title || 'SecureWave';
  let notificationOptions = {
    body: payload.notification?.body || 'Новое уведомление',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: data.callId || data.chatId || 'default',
    requireInteraction: false,
    data: data,
  };

  // ========================================
  // НАСТРОЙКИ В ЗАВИСИМОСТИ ОТ ТИПА
  // ========================================
  
  if (type === 'incoming_call') {
    // ВХОДЯЩИЙ ЗВОНОК - требует взаимодействия пользователя
    console.log('[firebase-messaging-sw.js] 📞 Входящий звонок от:', data.callerName);
    
    notificationOptions.requireInteraction = true;
    notificationOptions.actions = [
      {
        action: 'accept',
        title: '✅ Принять',
        icon: '/icons/accept.png'
      },
      {
        action: 'decline',
        title: '❌ Отклонить',
        icon: '/icons/decline.png'
      }
    ];
    notificationOptions.vibrate = [200, 100, 200, 100, 200, 100, 200];
    notificationOptions.silent = false;
    
  } else if (type === 'new_message') {
    // НОВОЕ СООБЩЕНИЕ
    console.log('[firebase-messaging-sw.js] 💬 Новое сообщение от:', data.senderName);
    
    // ⭐ ОБНОВЛЯЕМ TITLE СТРАНИЦЫ
    updatePageTitle(1);
    
    notificationOptions.actions = [
      {
        action: 'reply',
        title: '💬 Ответить',
        icon: '/icons/reply.png'
      },
      {
        action: 'mark_read',
        title: '✓ Прочитано',
        icon: '/icons/check.png'
      }
    ];
    notificationOptions.vibrate = [200, 100, 200];
    
  } else if (type === 'call_ended') {
    // ЗВОНОК ЗАВЕРШЕН - закрываем уведомление о звонке
    console.log('[firebase-messaging-sw.js] 📵 Звонок завершен:', data.callId);
    
    const callId = data.callId;
    if (callId) {
      self.registration.getNotifications({ tag: callId }).then(notifications => {
        console.log('[firebase-messaging-sw.js] Закрываем уведомления о звонке:', notifications.length);
        notifications.forEach(notification => notification.close());
      });
    }
    return; // Не показываем новое уведомление
  }

  // Показываем уведомление
  console.log('[firebase-messaging-sw.js] 🔔 Показываем уведомление:', notificationTitle);
  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// ========================================
// ОБРАБОТКА КЛИКОВ ПО УВЕДОМЛЕНИЯМ
// ========================================
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] 👆 Notification click:', event);
  console.log('[firebase-messaging-sw.js] Action:', event.action);
  console.log('[firebase-messaging-sw.js] Data:', event.notification.data);
  
  event.notification.close();
  
  const data = event.notification.data || {};
  const action = event.action;
  const type = data.type;
  
  // ========================================
  // ОБРАБОТКА ДЕЙСТВИЙ
  // ========================================
  
  if (action === 'accept' && type === 'incoming_call') {
    // ПРИНЯТЬ ЗВОНОК
    console.log('[firebase-messaging-sw.js] ✅ Принимаем звонок:', data.callId);
    event.waitUntil(
      clients.openWindow(`/call/${data.callId}?action=accept`)
    );
    
  } else if (action === 'decline' && type === 'incoming_call') {
    // ОТКЛОНИТЬ ЗВОНОК
    console.log('[firebase-messaging-sw.js] ❌ Отклоняем звонок:', data.callId);
    fetch('/api/calls/decline', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ callId: data.callId })
    });
    
  } else if (action === 'reply' && type === 'new_message') {
    // ОТКРЫТЬ ЧАТ ДЛЯ ОТВЕТА
    console.log('[firebase-messaging-sw.js] 💬 Открываем чат для ответа:', data.chatId);
    event.waitUntil(
      clients.openWindow(`/chat/${data.chatId}`)
    );
    
  } else if (action === 'mark_read' && type === 'new_message') {
    // ОТМЕТИТЬ КАК ПРОЧИТАННОЕ
    console.log('[firebase-messaging-sw.js] ✓ Отмечаем как прочитанное');
    fetch('/api/messages/read', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ messageId: data.messageId })
    });
    
  } else {
    // КЛИК ПО УВЕДОМЛЕНИЮ БЕЗ ВЫБОРА ДЕЙСТВИЯ
    console.log('[firebase-messaging-sw.js] Открываем приложение');
    
    if (type === 'incoming_call') {
      event.waitUntil(
        clients.openWindow(`/call/${data.callId}`)
      );
    } else if (type === 'new_message') {
      event.waitUntil(
        clients.openWindow(`/chat/${data.chatId}`)
      );
    } else {
      // Открыть главную страницу
      event.waitUntil(
        clients.openWindow('/')
      );
    }
  }
});

// ========================================
// ОБРАБОТКА ЗАКРЫТИЯ УВЕДОМЛЕНИЙ
// ========================================
self.addEventListener('notificationclose', (event) => {
  console.log('[firebase-messaging-sw.js] 🗑️ Notification closed:', event);
  
  const data = event.notification.data || {};
  
  // Если закрыли уведомление о звонке, отклоняем звонок
  if (data.type === 'incoming_call' && data.callId) {
    console.log('[firebase-messaging-sw.js] Отклоняем звонок (уведомление закрыто)');
    fetch('/api/calls/decline', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        callId: data.callId, 
        reason: 'notification_dismissed' 
      })
    });
  }
});

// ========================================
// LIFECYCLE СОБЫТИЯ SERVICE WORKER
// ========================================

self.addEventListener('install', (event) => {
  console.log('[firebase-messaging-sw.js] 🔧 Service Worker установлен');
  self.skipWaiting(); // Активируем сразу без ожидания
});

self.addEventListener('activate', (event) => {
  console.log('[firebase-messaging-sw.js] ✅ Service Worker активирован');
  event.waitUntil(clients.claim()); // Берем контроль над всеми клиентами
});

// ========================================
// ОБРАБОТКА СООБЩЕНИЙ ОТ ПРИЛОЖЕНИЯ
// ========================================
self.addEventListener('message', (event) => {
  console.log('[firebase-messaging-sw.js] 📬 Получено сообщение от приложения:', event.data);
  
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

console.log('[firebase-messaging-sw.js] 🎉 Service Worker loaded');