// lib/helpers/ios_callkit_handler.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import '../services/webrtc_service.dart';
import '../services/websocket_manager.dart';
import '../models/call.dart';
import 'ios_callkit_helper.dart';

/// ⭐⭐⭐ iOS CallKit Handler
/// Обрабатывает события от CallKit и связывает их с WebRTC
class IOSCallKitHandler {
  static final IOSCallKitHandler _instance = IOSCallKitHandler._internal();
  factory IOSCallKitHandler() => _instance;
  IOSCallKitHandler._internal();

  final WebRTCService _webrtcService = WebRTCService.instance;
  bool _isInitialized = false;

  /// Инициализация обработчика CallKit
  void initialize() {
    if (_isInitialized || !Platform.isIOS) {
      // print('[IOSCallKitHandler] ⚠️ Уже инициализирован или не iOS');
      return;
    }

    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] 🚀 Инициализация');
    // print('[IOSCallKitHandler] Platform: ${Platform.isIOS}');
    // print('[IOSCallKitHandler] ========================================');

    // Слушаем события от CallKit
    // print('[IOSCallKitHandler] 📡 Настраиваем method channel handler...');
    IOSCallKitHelper.setCallKitMethodCallHandler(_handleCallKitEvent);
    // print('[IOSCallKitHandler] ✅ Method channel handler настроен');

    _isInitialized = true;
    // print('[IOSCallKitHandler] ✅ Инициализирован');
    // print('[IOSCallKitHandler] ========================================');
  }

  /// Обработка событий от CallKit
  Future<dynamic> _handleCallKitEvent(MethodCall call) async {
    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] 📞 Событие получено от CallKit!');
    // print('[IOSCallKitHandler] Method: ${call.method}');
    // print('[IOSCallKitHandler] Arguments: ${call.arguments}');
    // print('[IOSCallKitHandler] Arguments type: ${call.arguments.runtimeType}');
    // print('[IOSCallKitHandler] ========================================');

    switch (call.method) {
      case 'callAccepted':
        // print('[IOSCallKitHandler] ✅ Обрабатываем callAccepted');
        await _onCallAccepted(call.arguments);
        break;

      case 'callEnded':
        await _onCallEnded(call.arguments);
        break;

      case 'callStarted':
        await _onCallStarted(call.arguments);
        break;

      case 'audioSessionActivated':
        await _onAudioSessionActivated();
        break;

      case 'voipTokenReceived':
        await _onVoipTokenReceived(call.arguments);
        break;

      case 'incomingVoIPCall':
        await _onIncomingCallReceived(call.arguments);
        break;

      case 'wasCallKitShownForCall':
        // ⭐⭐⭐ НОВОЕ: Обработчик для проверки, был ли CallKit показан для звонка
        // Используется AppDelegate для предотвращения двойного CallKit
        final callId = call.arguments as String?;
        if (callId != null) {
          final wasShown = wasCallKitShownForCall(callId);
          // print('[IOSCallKitHandler] 🔍 Проверка wasCallKitShownForCall для $callId: $wasShown');
          return wasShown;
        }
        return false;

      case 'markCallKitShownForCall':
        // ⭐⭐⭐ НОВОЕ: Обработчик для пометки, что CallKit был показан для звонка
        // Используется AppDelegate для предотвращения двойного CallKit
        final callId = call.arguments as String?;
        if (callId != null) {
          markCallKitShownForCall(callId);
          // print('[IOSCallKitHandler] ✅ CallId помечен как показанный: $callId');
        }
        return null;

      default:
        // print('[IOSCallKitHandler] ⚠️ Неизвестное событие: ${call.method}');
    }

    return null;
  }

  bool _callAcceptedViaCallKit = false;
  String? _acceptedCallId;
  DateTime? _callAcceptedTime; // ⭐⭐⭐ НОВОЕ: Время принятия звонка
  Timer? _waitForOfferTimer; // ⭐⭐⭐ НОВОЕ: Таймер ожидания call_offer
  
  // ⭐⭐⭐ НОВОЕ: Сохраняем данные VoIP звонка при получении push
  Map<String, dynamic>? _pendingVoIPCallData;
  
  // ⭐⭐⭐ НОВОЕ: Set для отслеживания звонков, для которых CallKit уже был показан
  // Это предотвращает двойной показ CallKit
  final Set<String> _callKitShownCallIds = {};

  /// Пользователь принял звонок через CallKit UI
  Future<void> _onCallAccepted(dynamic arguments) async {
    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] ✅ Пользователь ПРИНЯЛ звонок через CallKit');
    // print('[IOSCallKitHandler] Время: ${DateTime.now()}');
    // print('[IOSCallKitHandler] ========================================');

    final data = arguments as Map<Object?, Object?>;
    final callId = data['callId'] as String?;

    if (callId == null) {
      // print('[IOSCallKitHandler] ❌ callId отсутствует');
      return;
    }

    // ⭐⭐⭐ КРИТИЧНО: Устанавливаем флаг для автоматического принятия
    _callAcceptedViaCallKit = true;
    _acceptedCallId = callId;
    _callAcceptedTime = DateTime.now(); // ⭐⭐⭐ Сохраняем время принятия
    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] 🚩 Флаг установлен для $callId');
    // print('[IOSCallKitHandler] ⏳ Ждём когда придёт call_offer');
    // print('[IOSCallKitHandler] Время установки флага: ${DateTime.now()}');
    
    // ⭐⭐⭐ НОВОЕ: Проверяем состояние WebSocket
    final wsManager = WebSocketManager.instance;
    // print('[IOSCallKitHandler] WebSocket подключен: ${wsManager.isConnected}');
    // print('[IOSCallKitHandler] ========================================');

    // ⭐⭐⭐ КРИТИЧНО: Настраиваем аудио сессию СРАЗУ после принятия звонка
    // Это важно для обеспечения звука, особенно когда приложение было выгружено
    // print('[IOSCallKitHandler] 🔊 Настраиваем Audio Session (немедленно)...');
    await IOSCallKitHelper.configureAudioSession();
    // print('[IOSCallKitHandler] ✅ Audio Session настроена');

    // ⭐⭐⭐ ИСПРАВЛЕНО: НЕ вызываем reportCallConnecting() для входящих звонков
    // Это вызывает проблемы - CallKit автоматически обновит UI после accept
    // await IOSCallKitHelper.reportCallConnecting();

    // ⭐⭐⭐ КРИТИЧНО: Проверяем есть ли уже call_offer для этого звонка
    // Если приложение уже было открыто и call_offer уже получен
    // ⭐⭐⭐ ИСПРАВЛЕНО: Увеличена задержка для заблокированного экрана
    // Это важно для заблокированного экрана, когда приложение только что проснулось
    // WebSocket может еще не подключиться, поэтому даем больше времени
    // print('[IOSCallKitHandler] ⏳ Ждем стабилизации перед проверкой call_offer...');
    await Future.delayed(const Duration(milliseconds: 500));
    
    // ⭐⭐⭐ НОВОЕ: Проверяем WebSocket подключение (используем уже объявленную переменную)
    if (!wsManager.isConnected) {
      // print('[IOSCallKitHandler] ⚠️ WebSocket не подключен, ждем подключения...');
      // Ждем до 3 секунд для подключения WebSocket
      int wsAttempts = 0;
      const maxWSAttempts = 30; // 30 попыток по 100мс = 3 секунды
      while (!wsManager.isConnected && wsAttempts < maxWSAttempts) {
        await Future.delayed(const Duration(milliseconds: 100));
        wsAttempts++;
        if (wsAttempts % 10 == 0) {
          // print('[IOSCallKitHandler] Проверка WebSocket (попытка $wsAttempts/$maxWSAttempts)...');
        }
      }
      if (wsManager.isConnected) {
        // print('[IOSCallKitHandler] ✅ WebSocket подключен после ожидания');
      } else {
        // print('[IOSCallKitHandler] ⚠️ WebSocket все еще не подключен, продолжаем...');
      }
    }
    
    final currentCall = _webrtcService.currentCall;
    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] 🔍 Проверка текущего звонка:');
    // print('[IOSCallKitHandler]   - currentCall: ${currentCall != null ? currentCall.id : "null"}');
    // print('[IOSCallKitHandler]   - currentCall?.id: ${currentCall?.id}');
    // print('[IOSCallKitHandler]   - callId: $callId');
    // print('[IOSCallKitHandler]   - currentCall?.status: ${currentCall?.status}');
    // print('[IOSCallKitHandler]   - CallStatus.incoming: ${CallStatus.incoming}');
    // print('[IOSCallKitHandler]   - WebSocket подключен: ${wsManager.isConnected}');
    // print('[IOSCallKitHandler] ========================================');
    
    // ⭐⭐⭐ ИСПРАВЛЕНО: Принимаем звонок если он есть, независимо от статуса
    // Это важно для случая, когда call_offer пришел, но статус еще не обновлен
    if (currentCall != null && currentCall.id == callId) {
      // Проверяем статус - если incoming или connecting, принимаем
      if (currentCall.status == CallStatus.incoming || currentCall.status == CallStatus.connecting) {
        // print('[IOSCallKitHandler] ========================================');
        // print('[IOSCallKitHandler] ✅ Call_offer уже получен!');
        // print('[IOSCallKitHandler] Статус: ${currentCall.status}');
        // print('[IOSCallKitHandler] 🎯 Сразу принимаем звонок');
        // print('[IOSCallKitHandler] ========================================');
        
        // Отменяем таймер если он был запущен
        _waitForOfferTimer?.cancel();
        _waitForOfferTimer = null;
        
        // ⭐⭐⭐ КРИТИЧНО: Принимаем звонок сразу
        await _acceptCallSafely(callId);
      } else {
        // ⭐⭐⭐ НОВОЕ: Если звонок уже есть, но статус не incoming/connecting, все равно принимаем
        // print('[IOSCallKitHandler] ========================================');
        // print('[IOSCallKitHandler] ⚠️ Звонок найден, но статус: ${currentCall.status}');
        // print('[IOSCallKitHandler] 🎯 Принимаем звонок в любом случае');
        // print('[IOSCallKitHandler] ========================================');
        
        // Отменяем таймер если он был запущен
        _waitForOfferTimer?.cancel();
        _waitForOfferTimer = null;
        
        await _acceptCallSafely(callId);
      }
    } else {
      // print('[IOSCallKitHandler] ⏳ Call_offer еще не получен, запускаем таймер ожидания...');
      // print('[IOSCallKitHandler]   - currentCall == null: ${currentCall == null}');
      // print('[IOSCallKitHandler]   - currentCall?.id != callId: ${currentCall?.id != callId}');
      
      // ⭐⭐⭐ НОВОЕ: Запускаем таймер ожидания call_offer
      // Это критично для выгруженного приложения - WebSocket может еще не подключиться
      _startWaitingForOffer(callId);
    }
  }

  /// ⭐⭐⭐ НОВОЕ: Ожидание call_offer с таймаутом
  void _startWaitingForOffer(String callId) {
    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] ⏳ Запускаем ожидание call_offer...');
    // print('[IOSCallKitHandler] Call ID: $callId');
    // print('[IOSCallKitHandler] WebSocket подключен: ${WebSocketManager.instance.isConnected}');
    // print('[IOSCallKitHandler] ========================================');
    // Отменяем предыдущий таймер если есть
    _waitForOfferTimer?.cancel();
    
    int attempts = 0;
    // ⭐⭐⭐ ОПТИМИЗИРОВАНО: 60 попыток по 200мс = 12 секунд (было 30 секунд)
    // Уменьшен интервал проверки для более быстрого обнаружения offer
    const maxAttempts = 60; // Осталось 60 попыток
    const checkInterval = Duration(milliseconds: 200); // Было 500ms
    
    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] ⏳ Запускаем ожидание call_offer');
    // print('[IOSCallKitHandler] Call ID: $callId');
    // print('[IOSCallKitHandler] Таймаут: ${maxAttempts * checkInterval.inMilliseconds / 1000} секунд');
    // print('[IOSCallKitHandler] ⚠️ ВАЖНО: Для заблокированного экрана нужно больше времени');
    // print('[IOSCallKitHandler] ========================================');
    
    _waitForOfferTimer = Timer.periodic(checkInterval, (timer) {
      attempts++;
      
      // ⭐⭐⭐ НОВОЕ: Проверяем готовность WebSocket
      final wsManager = WebSocketManager.instance;
      final isWSConnected = wsManager.isConnected;
      
      // print('[IOSCallKitHandler] Проверка call_offer (попытка $attempts/$maxAttempts)...');
      // print('[IOSCallKitHandler] WebSocket подключен: $isWSConnected');
      
      // ⭐⭐⭐ ИСПРАВЛЕНО: Проверяем пришел ли call_offer (независимо от статуса)
      // Звонок может быть уже в статусе connecting или active, если был автоматически принят
      final currentCall = _webrtcService.currentCall;
      final hasCallOffer = currentCall != null && currentCall.id == callId;
      
      // print('[IOSCallKitHandler] Call найден: ${currentCall != null}');
      if (currentCall != null) {
        // print('[IOSCallKitHandler] Call ID: ${currentCall.id}, Status: ${currentCall.status}');
      }
      
      // ⭐⭐⭐ ИСПРАВЛЕНО: Принимаем звонок если он найден, независимо от статуса
      // Это важно для случая, когда call_offer пришел и был автоматически принят
      if (hasCallOffer) {
        // print('[IOSCallKitHandler] ========================================');
        // print('[IOSCallKitHandler] ✅ Call_offer получен!');
        // print('[IOSCallKitHandler] Статус звонка: ${currentCall.status}');
        // print('[IOSCallKitHandler] 🎯 Проверяем нужно ли принимать звонок...');
        // print('[IOSCallKitHandler] WebSocket: $isWSConnected');
        // print('[IOSCallKitHandler] ========================================');
        
        timer.cancel();
        _waitForOfferTimer = null;
        
        // ⭐⭐⭐ ИСПРАВЛЕНО: Проверяем статус звонка - если уже connecting или active, не принимаем повторно
        final callStatus = currentCall.status;
        if (callStatus == CallStatus.connecting || callStatus == CallStatus.active) {
          // print('[IOSCallKitHandler] ========================================');
          // print('[IOSCallKitHandler] ✅ Звонок уже принят или принимается!');
          // print('[IOSCallKitHandler] Статус: $callStatus');
          // print('[IOSCallKitHandler] ⚠️ Пропускаем повторное принятие');
          // print('[IOSCallKitHandler] ========================================');
          return; // Не принимаем повторно
        }
        
        // ⭐⭐⭐ ОПТИМИЗИРОВАНО: Ждем подключения WebSocket перед принятием звонка
        if (!isWSConnected) {
          // print('[IOSCallKitHandler] ⚠️ WebSocket не подключен, ждем подключения...');
          // ⭐⭐⭐ ОПТИМИЗИРОВАНО: Уменьшено с 2 секунд до 1 секунды для ускорения
          Future.delayed(Duration(milliseconds: 1000), () async {
            if (wsManager.isConnected) {
              // print('[IOSCallKitHandler] ✅ WebSocket подключен, принимаем звонок');
              await _acceptCallSafely(callId);
            } else {
              // print('[IOSCallKitHandler] ❌ WebSocket все еще не подключен, но принимаем звонок');
              await _acceptCallSafely(callId);
            }
          });
        } else {
          // ⭐⭐⭐ ОПТИМИЗИРОВАНО: Уменьшено с 300ms до 100ms для ускорения
          Future.delayed(Duration(milliseconds: 100), () async {
            await _acceptCallSafely(callId);
          });
        }
      } else if (attempts >= maxAttempts) {
        // print('[IOSCallKitHandler] ========================================');
        // print('[IOSCallKitHandler] ❌ ТАЙМАУТ: call_offer не получен за ${maxAttempts * 500 / 1000} секунд');
        // print('[IOSCallKitHandler] Call ID: $callId');
        // print('[IOSCallKitHandler] WebSocket подключен: $isWSConnected');
        // print('[IOSCallKitHandler] Current Call: ${currentCall?.id ?? "null"}');
        // print('[IOSCallKitHandler] ========================================');
        
        timer.cancel();
        _waitForOfferTimer = null;
        
        // Сбрасываем флаг
        resetCallAcceptedFlag();
      }
    });
  }

  /// ⭐⭐⭐ НОВОЕ: Безопасное принятие звонка с обработкой ошибок
  Future<void> _acceptCallSafely(String callId) async {
    try {
      // print('[IOSCallKitHandler] ========================================');
      // print('[IOSCallKitHandler] 🎯 Принимаем звонок через WebRTC...');
      // print('[IOSCallKitHandler] ⚠️ ВАЖНО: Для заблокированного экрана нужна особая обработка');
      // print('[IOSCallKitHandler] Call ID: $callId');
      // print('[IOSCallKitHandler] ========================================');
      
      // ⭐⭐⭐ КРИТИЧНО ДЛЯ ПЕРВОГО ЗВОНКА: Убеждаемся что WebRTC и WebSocket готовы
      // print('[IOSCallKitHandler] 🔍 Проверка готовности перед принятием звонка...');
      await _ensureWebRTCReady(callId);
      
      // ⭐⭐⭐ КРИТИЧНО: Активируем аудио сессию ПЕРЕД принятием звонка
      // Это гарантирует, что сессия активна для воспроизведения звука
      // Особенно важно для заблокированного экрана
      // print('[IOSCallKitHandler] 🔊 Активируем Audio Session (критично для заблокированного экрана)...');
      await IOSCallKitHelper.configureAudioSession();
      // print('[IOSCallKitHandler] ✅ Audio Session активирована перед acceptCall');
      
      // ⭐⭐⭐ НОВОЕ: Небольшая задержка для стабилизации аудио сессии
      // Это важно для заблокированного экрана, когда приложение только что проснулось
      await Future.delayed(const Duration(milliseconds: 200));
      
      // print('[IOSCallKitHandler] 📞 Вызываем acceptCall...');
      await _webrtcService.acceptCall(callId);
      // print('[IOSCallKitHandler] ✅ Звонок принят через WebRTC');
      
      // ⭐⭐⭐ НОВОЕ: Повторно активируем аудио сессию после acceptCall
      // Это гарантирует, что сессия остается активной после создания PeerConnection
      // print('[IOSCallKitHandler] 🔊 Повторно активируем Audio Session после acceptCall...');
      await Future.delayed(const Duration(milliseconds: 300));
      await IOSCallKitHelper.configureAudioSession();
      // print('[IOSCallKitHandler] ✅ Audio Session повторно активирована');
      // print('[IOSCallKitHandler] ========================================');
    } catch (e, stackTrace) {
      // print('[IOSCallKitHandler] ========================================');
      // print('[IOSCallKitHandler] ❌ ОШИБКА acceptCall: $e');
      // print('[IOSCallKitHandler] Stack trace: $stackTrace');
      // print('[IOSCallKitHandler] ========================================');
    }
  }

  /// Проверить, был ли звонок принят через CallKit
  bool wasCallAcceptedViaCallKit(String callId) {
    return _callAcceptedViaCallKit && _acceptedCallId == callId;
  }

  /// Проверить, был ли CallKit уже показан для данного звонка
  /// (через VoIP push или FCM уведомление)
  bool wasCallKitShownForCall(String callId) {
    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] 🔍 Проверка: был ли CallKit показан для $callId');
    // print('[IOSCallKitHandler] _callKitShownCallIds: $_callKitShownCallIds');
    // print('[IOSCallKitHandler] _pendingVoIPCallData: ${_pendingVoIPCallData != null ? _pendingVoIPCallData : "null"}');
    // print('[IOSCallKitHandler] _callAcceptedViaCallKit: $_callAcceptedViaCallKit');
    // print('[IOSCallKitHandler] _acceptedCallId: $_acceptedCallId');
    // print('[IOSCallKitHandler] ========================================');
    
    // ⭐⭐⭐ КРИТИЧНО: Проверяем Set - это основной способ отслеживания
    if (_callKitShownCallIds.contains(callId)) {
      // print('[IOSCallKitHandler] ✅ CallKit уже был показан для $callId (найдено в _callKitShownCallIds)');
      return true;
    }
    
    // Если есть pending VoIP данные с таким же callId, значит CallKit уже был показан
    if (_pendingVoIPCallData != null) {
      final pendingCallId = _pendingVoIPCallData!['callId'] as String?;
      if (pendingCallId == callId) {
        // print('[IOSCallKitHandler] ✅ CallKit уже был показан для $callId (через VoIP push/FCM)');
        // ⭐⭐⭐ НОВОЕ: Добавляем в Set для будущих проверок
        _callKitShownCallIds.add(callId);
        return true;
      } else {
        // print('[IOSCallKitHandler] ⚠️ Pending VoIP данные есть, но callId не совпадает: $pendingCallId != $callId');
        // ⭐⭐⭐ КРИТИЧНО: Если pending VoIP данные для другого звонка, очищаем их
        // Это может произойти при повторном звонке, когда старые данные еще не очищены
        if (pendingCallId != null && pendingCallId != callId) {
          // print('[IOSCallKitHandler] 🧹 Очищаем старые pending VoIP данные для звонка: $pendingCallId');
          _pendingVoIPCallData = null;
        }
      }
    } else {
      // print('[IOSCallKitHandler] ℹ️ _pendingVoIPCallData = null (VoIP push не был получен)');
    }
    
    // ⭐⭐⭐ ИСПРАВЛЕНО: НЕ проверяем _callAcceptedViaCallKit здесь
    // Это флаг принятия звонка, а не показа CallKit
    // CallKit может быть показан, но звонок еще не принят
    // Или звонок может быть принят, но CallKit не был показан (если call_offer пришел раньше)
    
    // print('[IOSCallKitHandler] ❌ CallKit НЕ был показан для $callId');
    // print('[IOSCallKitHandler] ========================================');
    return false;
  }

  /// ⭐⭐⭐ НОВОЕ: Явно пометить, что CallKit был показан для этого звонка
  void markCallKitShownForCall(String callId) {
    _callKitShownCallIds.add(callId);
    // print('[IOSCallKitHandler] ✅ CallId явно добавлен в _callKitShownCallIds: $callId');
    // print('[IOSCallKitHandler] Текущий Set: $_callKitShownCallIds');
  }

  /// Сбросить флаг принятия через CallKit
  void resetCallAcceptedFlag() {
    _callAcceptedViaCallKit = false;
    _acceptedCallId = null;
    _callAcceptedTime = null; // ⭐⭐⭐ НОВОЕ: Сбрасываем время
    _waitForOfferTimer?.cancel(); // ⭐⭐⭐ НОВОЕ: Отменяем таймер
    _waitForOfferTimer = null;
    // print('[IOSCallKitHandler] 🚩 Флаг _callAcceptedViaCallKit сброшен');
  }

  /// Очистить pending VoIP данные
  /// Вызывается после того, как call_offer получен и CallKit был проверен
  void clearPendingVoIPCallData() {
    if (_pendingVoIPCallData != null) {
      // print('[IOSCallKitHandler] 🧹 Очищаем pending VoIP данные');
      _pendingVoIPCallData = null;
    }
  }
  
  /// Очистить данные для завершенного звонка
  /// Вызывается при завершении звонка
  void clearCallData(String callId) {
    // print('[IOSCallKitHandler] 🧹 Очищаем данные для звонка: $callId');
    _callKitShownCallIds.remove(callId);
    
    // Если это был pending VoIP звонок, очищаем и его
    if (_pendingVoIPCallData != null && _pendingVoIPCallData!['callId'] == callId) {
      _pendingVoIPCallData = null;
    }
    
    // print('[IOSCallKitHandler] ✅ Данные очищены. Осталось в Set: ${_callKitShownCallIds.length}');
  }

  /// Пользователь завершил звонок через CallKit UI
  Future<void> _onCallEnded(dynamic arguments) async {
    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] 🔴 Пользователь ЗАВЕРШИЛ звонок');
    // print('[IOSCallKitHandler] ========================================');

    final data = arguments as Map<Object?, Object?>;
    final callId = data['callId'] as String?;
    final uuid = data['uuid'] as String?;

    if (callId != null) {
      // print('[IOSCallKitHandler] Call ID: $callId');
    }
    if (uuid != null) {
      // print('[IOSCallKitHandler] UUID: $uuid');
    }

    // ⭐⭐⭐ КРИТИЧНО: Получаем текущий звонок для проверки
    final currentCall = _webrtcService.currentCall;
    final actualCallId = callId ?? currentCall?.id;
    
    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] 🔍 Проверка звонка:');
    // print('[IOSCallKitHandler]   - callId из CallKit: $callId');
    // print('[IOSCallKitHandler]   - UUID из CallKit: $uuid');
    // print('[IOSCallKitHandler]   - currentCall?.id: ${currentCall?.id}');
    // print('[IOSCallKitHandler]   - actualCallId: $actualCallId');
    // print('[IOSCallKitHandler]   - currentCall?.status: ${currentCall?.status}');
    // print('[IOSCallKitHandler] ========================================');

    // ⭐⭐⭐ КРИТИЧНО: Игнорируем повторные события callEnded после завершения звонка
    // Если звонок уже завершен (currentCall == null) и callId не передан, это может быть
    // отложенное событие от CallKit для другого UUID
    if (currentCall == null && callId == null) {
      // print('[IOSCallKitHandler] ========================================');
      // print('[IOSCallKitHandler] ⚠️ ИГНОРИРУЕМ callEnded - звонок уже завершен');
      // print('[IOSCallKitHandler] currentCall == null и callId == null');
      // print('[IOSCallKitHandler] Это может быть отложенное событие от CallKit');
      // print('[IOSCallKitHandler] UUID: $uuid');
      // print('[IOSCallKitHandler] ========================================');
      return;
    }

    // ⭐⭐⭐ ИСПРАВЛЕНО: Защищаем ТОЛЬКО от завершения во время установки соединения (первые 1 секунда)
    // ВСЕГДА завершаем активные звонки - если пользователь явно завершает через CallKit, завершаем
    if (_callAcceptedViaCallKit && actualCallId != null && _acceptedCallId == actualCallId) {
      final timeSinceAccept = _callAcceptedTime != null 
          ? DateTime.now().difference(_callAcceptedTime!).inSeconds 
          : 999;
      
      // ⭐⭐⭐ КРИТИЧНО: Игнорируем callEnded ТОЛЬКО если звонок еще устанавливается соединение (менее 1 секунды)
      // НЕ блокируем завершение активных звонков - пользователь может завершить в любой момент
      if (currentCall != null && 
          currentCall.id == actualCallId && 
          (currentCall.status == CallStatus.incoming || 
           (currentCall.status == CallStatus.connecting && timeSinceAccept < 1))) {
        // print('[IOSCallKitHandler] ========================================');
        // print('[IOSCallKitHandler] ⚠️ ИГНОРИРУЕМ callEnded - звонок еще устанавливается соединение');
        // print('[IOSCallKitHandler] Статус: ${currentCall.status}');
        // print('[IOSCallKitHandler] Время с момента accept: ${timeSinceAccept} сек');
        // print('[IOSCallKitHandler] Это может быть ложное срабатывание CallKit при установке соединения');
        // print('[IOSCallKitHandler] ========================================');
        return;
      }
      
      // ⭐⭐⭐ КРИТИЧНО: Для всех остальных статусов (active, calling, connecting > 1 сек) - завершаем
      // print('[IOSCallKitHandler] ========================================');
      // print('[IOSCallKitHandler] ✅ Завершаем звонок по запросу пользователя через CallKit');
      // print('[IOSCallKitHandler] Статус: ${currentCall?.status ?? "null"}');
      // print('[IOSCallKitHandler] Время с момента accept: ${timeSinceAccept} сек');
      // print('[IOSCallKitHandler] ========================================');
    }

    // ⭐⭐⭐ КРИТИЧНО: Завершаем звонок в WebRTC с правильным callId
    // Если callId не передан, используем текущий звонок
    try {
      if (actualCallId != null) {
        // print('[IOSCallKitHandler] ========================================');
        // print('[IOSCallKitHandler] 📤 Отправляем call_ended на сервер');
        // print('[IOSCallKitHandler] Call ID: $actualCallId');
        // print('[IOSCallKitHandler] ========================================');
        
        // ⭐⭐⭐ КРИТИЧНО: Всегда завершаем звонок, независимо от статуса
        // print('[IOSCallKitHandler] 🔍 Проверка текущего звонка перед завершением...');
        // print('[IOSCallKitHandler] currentCall?.id: ${currentCall?.id}');
        // print('[IOSCallKitHandler] actualCallId: $actualCallId');
        // print('[IOSCallKitHandler] currentCall?.status: ${currentCall?.status}');
        
        // ⭐⭐⭐ КРИТИЧНО: НЕ вызываем IOSCallKitHelper.endCall() здесь!
        // Когда пользователь завершает звонок через CallKit UI, CallKit уже сам обработал завершение
        // через provider(_:perform:) для CXEndCallAction, который уже вызвал action.fulfill()
        // Нам нужно только уведомить WebRTC и сервер о завершении
        
        // ⭐⭐⭐ КРИТИЧНО: Завершаем звонок через WebRTC, если он существует
        // ⚠️ НЕ вызываем WebSocketManager.instance.endCall() здесь, так как
        // _webrtcService.endCall() уже отправляет call_end на сервер
        if (currentCall != null && currentCall.id == actualCallId) {
          // print('[IOSCallKitHandler] ✅ Завершаем звонок через WebRTCService');
          // ⭐⭐⭐ КРИТИЧНО: Завершаем звонок в WebRTC
          // WebRTCService.endCall() сам отправит call_end на сервер
          await _webrtcService.endCall('user_ended');
        } else {
          // ⭐⭐⭐ КРИТИЧНО: Если текущий звонок не найден или не совпадает, отправляем сообщение напрямую
          // print('[IOSCallKitHandler] ⚠️ Текущий звонок не найден или не совпадает');
          // print('[IOSCallKitHandler] 📤 Отправляем call_ended напрямую через WebSocket');
          try {
            WebSocketManager.instance.endCall(actualCallId, 'user_ended');
            // print('[IOSCallKitHandler] ✅ call_ended отправлен через WebSocket');
          } catch (e) {
            // print('[IOSCallKitHandler] ❌ Ошибка отправки call_ended: $e');
          }
        }
        
        // print('[IOSCallKitHandler] ✅ Звонок завершён');
        
        // ⭐⭐⭐ НОВОЕ: Очищаем данные звонка из Set
        clearCallData(actualCallId);
      } else {
        // print('[IOSCallKitHandler] ❌ Не удалось определить callId для завершения');
      }
    } catch (e) {
      // print('[IOSCallKitHandler] ❌ Ошибка endCall: $e');
    }

    // Деактивируем аудио сессию
    await IOSCallKitHelper.deactivateAudioSession();
    
    // Сбрасываем флаг принятия
    resetCallAcceptedFlag();
  }

  /// Начат исходящий звонок
  Future<void> _onCallStarted(dynamic arguments) async {
    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] 📞 Исходящий звонок начат');
    // print('[IOSCallKitHandler] ========================================');

    // Настраиваем аудио сессию
    await IOSCallKitHelper.configureAudioSession();
  }

  /// Audio Session активирована - можно начинать звонок
  Future<void> _onAudioSessionActivated() async {
    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] 🔊 Audio Session активирована');
    // print('[IOSCallKitHandler] ========================================');

    // Здесь можно начинать реальный звонок
  }

  /// Получен VoIP Push токен
  Future<void> _onVoipTokenReceived(dynamic arguments) async {
    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] 📱 VoIP Push Token получен');
    // print('[IOSCallKitHandler] ========================================');

    final data = arguments as Map<Object?, Object?>;
    final token = data['token'] as String?;

    if (token != null) {
      // print('[IOSCallKitHandler] Token: $token');

      // Сохраняем токен для последующей отправки на backend
      _voipToken = token;

      // Если callback установлен - вызываем его
      if (_onVoipTokenCallback != null) {
        _onVoipTokenCallback!(token);
      }
    }
  }

  String? _voipToken;
  Function(String token)? _onVoipTokenCallback;

  /// Установить callback для получения VoIP токена
  void setVoipTokenCallback(Function(String token) callback) {
    _onVoipTokenCallback = callback;

    // Если токен уже получен - сразу вызываем callback
    if (_voipToken != null) {
      callback(_voipToken!);
    }
  }

  /// Получить текущий VoIP токен
  String? get voipToken => _voipToken;

  /// Получен входящий звонок через VoIP Push
  Future<void> _onIncomingCallReceived(dynamic arguments) async {
    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] 📥 Входящий звонок через VoIP Push');
    // print('[IOSCallKitHandler] ========================================');

    final data = arguments as Map<Object?, Object?>;
    final callId = data['callId'] as String?;
    final callerName = data['callerName'] as String?;
    final callType = data['callType'] as String? ?? 'audio';
    final chatId = data['chatId'] as String?;
    final callerId = data['callerId'] as String?;

    // print('[IOSCallKitHandler] Call ID: $callId');
    // print('[IOSCallKitHandler] Caller: $callerName');
    // print('[IOSCallKitHandler] Type: $callType');
    // print('[IOSCallKitHandler] Chat ID: $chatId');
    // print('[IOSCallKitHandler] Caller ID: $callerId');

    // ⭐⭐⭐ КРИТИЧНО: Проверяем, не звоним ли мы сами себе
    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] 🔍 ПРОВЕРКА: Не звоним ли мы сами себе?');
    
    // Пробуем получить userId из разных источников
    final wsManager = WebSocketManager.instance;
    final wsUserId = wsManager.userId;
    final webrtcUserId = _webrtcService.userId;
    
    // print('[IOSCallKitHandler] WebSocketManager.userId: $wsUserId');
    // print('[IOSCallKitHandler] WebRTCService.userId: $webrtcUserId');
    // print('[IOSCallKitHandler] callerId: $callerId');
    
    // Используем первый доступный userId
    final currentUserId = wsUserId ?? webrtcUserId;
    
    if (callerId != null && currentUserId != null) {
      final cleanCallerId = callerId.trim();
      final cleanCurrentUserId = currentUserId.trim();
      // print('[IOSCallKitHandler] ========================================');
      // print('[IOSCallKitHandler] 🔍 ПРОВЕРКА: Не звоним ли мы сами себе?');
      // print('[IOSCallKitHandler] callerId: "$cleanCallerId"');
      // print('[IOSCallKitHandler] currentUserId: "$cleanCurrentUserId"');
      // print('[IOSCallKitHandler] Сравнение: "$cleanCallerId" == "$cleanCurrentUserId" = ${cleanCallerId == cleanCurrentUserId}');
      // print('[IOSCallKitHandler] ========================================');
      
      if (cleanCallerId == cleanCurrentUserId) {
        // print('[IOSCallKitHandler] ❌❌❌ ОШИБКА: VoIP push от самого себя!');
        // print('[IOSCallKitHandler] ⚠️ Игнорируем этот VoIP push');
        // print('[IOSCallKitHandler] ⚠️ Это может быть ошибка на бэкенде - push отправлен не тому пользователю');
        return; // ⭐⭐⭐ КРИТИЧНО: Не обрабатываем звонок от самого себя
      }
    } else {
      // print('[IOSCallKitHandler] ⚠️ Не удалось получить currentUserId для проверки');
      // print('[IOSCallKitHandler] callerId: $callerId');
      // print('[IOSCallKitHandler] currentUserId: $currentUserId');
      // print('[IOSCallKitHandler] ⚠️ Продолжаем обработку VoIP push (проверка пропущена)');
    }
    // print('[IOSCallKitHandler] ========================================');

    // ⭐⭐⭐ КРИТИЧНО: Сохраняем данные VoIP звонка
    // Это нужно для случая когда приложение запускается из закрытого состояния
    if (callId != null) {
      _pendingVoIPCallData = {
        'callId': callId,
        'callerName': callerName ?? 'Неизвестный',
        'callType': callType,
        'chatId': chatId,
        'callerId': callerId,
      };
      // ⭐⭐⭐ НОВОЕ: Добавляем callId в Set для отслеживания показанных CallKit
      _callKitShownCallIds.add(callId);
      // print('[IOSCallKitHandler] 💾 Данные VoIP звонка сохранены');
      // print('[IOSCallKitHandler] ✅ CallId добавлен в _callKitShownCallIds: $callId');
    }

    // ⭐⭐⭐ НОВОЕ: Проверяем, был ли CallKit показан
    // Если CallKit НЕ был показан, значит приложение открыто (foreground)
    // В этом случае не нужно автоматически принимать звонок - пользователь сам решит
    final wasCallKitShown = wasCallKitShownForCall(callId ?? '');
    
    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] 🔍 Проверка: был ли CallKit показан?');
    // print('[IOSCallKitHandler] Call ID: $callId');
    // print('[IOSCallKitHandler] CallKit показан: $wasCallKitShown');
    // print('[IOSCallKitHandler] ========================================');
    
    // ⭐⭐⭐ КРИТИЧНО: Убеждаемся что WebRTC инициализирован и WebSocket подключен
    _ensureWebRTCReady(callId).then((_) {
      // ⭐⭐⭐ ИСПРАВЛЕНО: Автоматически принимаем звонок ТОЛЬКО если CallKit был показан
      // Если CallKit НЕ был показан (приложение открыто), НЕ принимаем автоматически
      // Пользователь должен сам принять звонок через UI приложения
      if (callId != null && wasCallKitShown) {
        Future.delayed(const Duration(seconds: 2), () {
          final currentCall = _webrtcService.currentCall;
          if (currentCall != null && 
              currentCall.id == callId && 
              currentCall.status == CallStatus.incoming &&
              !_callAcceptedViaCallKit) {
            // print('[IOSCallKitHandler] ========================================');
            // print('[IOSCallKitHandler] ⚠️ CallKit был показан, но звонок не принят через CallKit UI');
            // print('[IOSCallKitHandler] 🎯 Автоматически принимаем звонок...');
            // print('[IOSCallKitHandler] Call ID: $callId');
            // print('[IOSCallKitHandler] ========================================');
            _acceptCallSafely(callId);
          }
        });
      } else if (callId != null && !wasCallKitShown) {
        // print('[IOSCallKitHandler] ========================================');
        // print('[IOSCallKitHandler] 📱 Приложение открыто (CallKit не был показан)');
        // print('[IOSCallKitHandler] ⏭️ НЕ принимаем звонок автоматически');
        // print('[IOSCallKitHandler] ✅ Пользователь сам примет звонок через UI');
        // print('[IOSCallKitHandler] Call ID: $callId');
        // print('[IOSCallKitHandler] ========================================');
      }
    });
  }
  
  /// ⭐⭐⭐ НОВОЕ: Убеждаемся что WebRTC готов для обработки звонка
  Future<void> _ensureWebRTCReady(String? callId) async {
    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] 🔍 Проверка готовности WebRTC и WebSocket');
    // print('[IOSCallKitHandler] Call ID: $callId');
    // print('[IOSCallKitHandler] ========================================');
    
    // ⭐⭐⭐ КРИТИЧНО ДЛЯ ПЕРВОГО ЗВОНКА: Проверяем инициализацию WebRTC
    if (!_webrtcService.isInitialized) {
      // print('[IOSCallKitHandler] ⚠️ WebRTC не инициализирован, ждем...');
      
      // Ждем до 10 секунд пока WebRTC инициализируется
      int attempts = 0;
      const maxAttempts = 20; // 20 попыток по 500мс = 10 секунд
      
      while (!_webrtcService.isInitialized && attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
        // print('[IOSCallKitHandler] Проверка WebRTC (попытка $attempts/$maxAttempts)...');
      }
      
      if (!_webrtcService.isInitialized) {
        // print('[IOSCallKitHandler] ❌ WebRTC не инициализирован после ожидания');
        return;
      }
    }
    
    // ⭐⭐⭐ КРИТИЧНО ДЛЯ ПЕРВОГО ЗВОНКА: Проверяем подключение WebSocket
    final wsManager = WebSocketManager.instance;
    if (!wsManager.isConnected) {
      // print('[IOSCallKitHandler] ⚠️ WebSocket не подключен, пытаемся подключиться...');
      
      try {
        await wsManager.connect();
        // print('[IOSCallKitHandler] ✅ Попытка подключения WebSocket инициирована');
      } catch (e) {
        // print('[IOSCallKitHandler] ⚠️ Ошибка при попытке подключения WebSocket: $e');
      }
      
      // ⭐⭐⭐ УВЕЛИЧЕНО ДЛЯ ПЕРВОГО ЗВОНКА: Ждем подключения до 8 секунд (было 5)
      // Для заблокированного экрана нужно больше времени
      int attempts = 0;
      const maxAttempts = 80; // 80 попыток по 100мс = 8 секунд (было 50 = 5 сек)
      
      while (!wsManager.isConnected && attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
        if (attempts % 10 == 0) {
          // print('[IOSCallKitHandler] Проверка WebSocket (попытка $attempts/$maxAttempts)...');
          // print('[IOSCallKitHandler] WebSocket подключен: ${wsManager.isConnected}');
        }
      }
      
      if (!wsManager.isConnected) {
        // print('[IOSCallKitHandler] ⚠️ WebSocket не подключен после ожидания (8 секунд), но продолжаем...');
        // print('[IOSCallKitHandler] ⚠️ Это может быть проблемой для первого звонка');
      } else {
        // print('[IOSCallKitHandler] ✅ WebSocket подключен после ожидания');
        // print('[IOSCallKitHandler] Время ожидания: ${attempts * 100}мс');
      }
    } else {
      // print('[IOSCallKitHandler] ✅ WebSocket уже подключен');
    }
    
    // print('[IOSCallKitHandler] ✅ WebRTC и WebSocket готовы');
    // print('[IOSCallKitHandler] ========================================');
  }

  /// Показать CallKit UI для входящего звонка
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    bool hasVideo = false,
  }) async {
    if (!Platform.isIOS) return;

    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] 📞 Показываем CallKit UI');
    // print('[IOSCallKitHandler] Call ID: $callId');
    // print('[IOSCallKitHandler] Caller: $callerName');
    // print('[IOSCallKitHandler] ========================================');

    await IOSCallKitHelper.reportIncomingCall(
      callId: callId,
      callerName: callerName,
      hasVideo: hasVideo,
    );
  }

  /// Начать исходящий звонок через CallKit
  Future<void> startOutgoingCall({
    required String callId,
    required String handle,
    bool hasVideo = false,
  }) async {
    if (!Platform.isIOS) return;

    // print('[IOSCallKitHandler] ========================================');
    // print('[IOSCallKitHandler] 📞 Начинаем исходящий звонок');
    // print('[IOSCallKitHandler] Call ID: $callId');
    // print('[IOSCallKitHandler] Handle: $handle');
    // print('[IOSCallKitHandler] ========================================');

    await IOSCallKitHelper.startOutgoingCall(
      callId: callId,
      handle: handle,
      hasVideo: hasVideo,
    );
  }

  /// Завершить текущий звонок
  Future<void> endCall(String? callId) async {
    if (!Platform.isIOS) return;

    // print('[IOSCallKitHandler] 🔴 Завершаем звонок: $callId');
    await IOSCallKitHelper.endCall(callId);
  }

  /// Уведомить CallKit что звонок соединился
  Future<void> reportCallConnected() async {
    if (!Platform.isIOS) return;

    // print('[IOSCallKitHandler] ✅ Уведомляем: звонок соединён');
    await IOSCallKitHelper.reportCallConnected();
  }

  /// Уведомить CallKit что звонок соединяется
  Future<void> reportCallConnecting() async {
    if (!Platform.isIOS) return;

    // print('[IOSCallKitHandler] ⏳ Уведомляем: звонок соединяется');
    await IOSCallKitHelper.reportCallConnecting();
  }
}
