// lib/services/websocket_manager.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  static WebSocketManager get instance => _instance;

  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _pingInterval = Duration(seconds: 30);

  final ApiService _api = ApiService();

  WebSocketManager._internal();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  bool get isConnected => _channel != null;

  void _log(String message) {
    if (kDebugMode) {
      print('[WebSocket] $message');
    }
  }

  Future<void> connect() async {
    if (_isConnecting || isConnected) {
      _log('Уже подключен или идет подключение');
      return;
    }

    _isConnecting = true;
    _log('Подключение к WebSocket...');

    try {
      final token = _api.token;
      if (token == null || token.isEmpty) {
        _log('Нет токена авторизации');
        _isConnecting = false;
        return;
      }

      // ИСПРАВЛЕНО: формируем wsUrl вручную, так как ApiService не имеет wsUrl
      final wsUrl = _getWebSocketUrl();
      _log('Подключение к: $wsUrl');

      final uri = Uri.parse('$wsUrl?token=$token');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      _reconnectAttempts = 0;
      _isConnecting = false;
      _startPingTimer();
      _log('✅ WebSocket подключен');
    } catch (e) {
      _log('❌ Ошибка подключения: $e');
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  // ИСПРАВЛЕНО: новый метод для определения WebSocket URL
  String _getWebSocketUrl() {
    if (kIsWeb) {
      // Для веб-версии определяем из текущего URL
      final protocol = Uri.base.scheme == 'https' ? 'wss' : 'ws';
      final host = Uri.base.host;
      final port = Uri.base.hasPort ? ':${Uri.base.port}' : '';
      return '$protocol://$host$port/backend/ws';
    } else {
      // Для нативных приложений
      return 'wss://securewave.sbk-19.ru/backend/ws';
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data.toString()) as Map<String, dynamic>;
      _log('📨 Получено: ${message['type']}');
      _messageController.add(message);
    } catch (e) {
      _log('Ошибка парсинга сообщения: $e');
    }
  }

  void _handleError(error) {
    _log('❌ Ошибка WebSocket: $error');
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    _log('🔌 WebSocket отключен');
    _channel = null;
    _pingTimer?.cancel();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log('⛔ Достигнуто максимальное число попыток переподключения');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    _log(
        '🔄 Переподключение через ${_reconnectDelay.inSeconds}с (попытка $_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(_reconnectDelay, () {
      connect();
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (isConnected) {
        send({'type': 'ping'});
      }
    });
  }

  void send(Map<String, dynamic> message) {
    if (!isConnected) {
      _log('⚠️ Не подключен к WebSocket');
      return;
    }

    try {
      final json = jsonEncode(message);
      _channel!.sink.add(json);
      _log('📤 Отправлено: ${message['type']}');
    } catch (e) {
      _log('Ошибка отправки: $e');
    }
  }

  void disconnect() {
    _log('Отключение WebSocket');
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _reconnectAttempts = 0;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
