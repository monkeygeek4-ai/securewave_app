// lib/services/websocket_manager.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'api_service.dart';

enum ConnectionStatus { connecting, connected, disconnected, error }

class WebSocketManager {
  static WebSocketManager? _instance;
  static WebSocketManager get instance {
    _instance ??= WebSocketManager._internal();
    return _instance!;
  }

  WebSocketManager._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  Timer? _connectionTimeoutTimer;

  String? _token;
  String? _userId;
  bool _isConnecting = false;
  bool _isAuthenticated = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _connectionTimeout = Duration(seconds: 10);

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  final List<Map<String, dynamic>> _messageQueue = [];

  Stream<ConnectionStatus> get connectionStatus => _statusController.stream;
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected =>
      _channel != null && _channel!.closeCode == null && _isAuthenticated;

  void _log(String message) {
    if (kDebugMode) {
      print('[WS Manager] $message');
    }
  }

  Future<void> connect({String? token, String? userId}) async {
    if (_channel != null && _channel!.closeCode == null) {
      _log('Соединение уже существует и активно, не создаем новое');
      if (!_isAuthenticated && _token != null) {
        _log('Отправляем повторную авторизацию');
        await _authenticate();
      }
      return;
    }

    if (_isConnecting) {
      _log('Уже идет процесс подключения, ждем...');
      return;
    }

    _isConnecting = true;
    _isAuthenticated = false;
    _token = token ?? _token;
    _userId = userId ?? _userId;

    if (_token == null) {
      _log('Нет токена для подключения');
      _isConnecting = false;
      _statusController.add(ConnectionStatus.error);
      return;
    }

    try {
      _statusController.add(ConnectionStatus.connecting);
      _log('Создаем НОВОЕ WebSocket соединение...');

      if (_channel != null) {
        try {
          _channel!.sink.close();
        } catch (e) {
          _log('Ошибка закрытия старого канала: $e');
        }
        _channel = null;
      }

      _connectionTimeoutTimer?.cancel();
      _connectionTimeoutTimer = Timer(_connectionTimeout, () {
        if (!isConnected) {
          _log('Таймаут подключения');
          _handleConnectionError('Connection timeout');
        }
      });

      final wsUrl = ApiService.wsUrl;
      _log('WebSocket URL: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription?.cancel();
      _subscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          _log('Ошибка WebSocket: $error');
          _handleConnectionError(error.toString());
        },
        onDone: () {
          _log('WebSocket соединение закрыто');
          _handleDisconnection();
        },
      );

      await Future.delayed(Duration(milliseconds: 100));

      _log('Отправляем авторизацию...');
      final authMessage = {
        'type': 'auth',
        'token': _token!.replaceAll('"', ''),
        'userId': _userId,
      };

      _channel!.sink.add(json.encode(authMessage));
      _log('Авторизация отправлена, ждем подтверждения...');
    } catch (e) {
      _log('Ошибка подключения: $e');
      _isConnecting = false;
      _handleConnectionError(e.toString());
    }
  }

  Future<void> _authenticate() async {
    if (_token == null) return;

    final authMessage = {
      'type': 'auth',
      'token': _token!.replaceAll('"', ''),
      'userId': _userId,
    };

    send(authMessage);
    _log('Отправлена авторизация');

    Timer(Duration(seconds: 5), () {
      if (!_isAuthenticated && _isConnecting) {
        _log('Таймаут авторизации');
        _handleConnectionError('Authentication timeout');
      }
    });
  }

  void _handleMessage(dynamic message) {
    try {
      final data = json.decode(message.toString());
      _log('Получено сообщение типа: ${data['type']}');

      switch (data['type']) {
        case 'auth_success':
        case 'авторизация_успешна':
          _handleAuthSuccess(data);
          break;

        case 'auth_error':
        case 'ошибка_авторизации':
          _handleAuthError(data);
          break;

        case 'message':
        case 'new_message':
        case 'новое_сообщение':
          _log('💬 Новое сообщение получено');
          _messageController.add({
            'type': 'message',
            'message': data['message'] ?? data,
          });
          break;

        case 'message_sent':
          _log('✅ Сообщение отправлено');
          _messageController.add({
            'type': 'message_sent',
            'tempId': data['tempId'],
            'message': data['message'],
          });
          break;

        case 'typing':
        case 'пользователь_печатает':
          _log('⌨️ Пользователь печатает');
          _messageController.add({
            'type': 'typing',
            'chatId': data['chatId'],
            'userId': data['userId'],
            'userName': data['userName'],
            'isTyping': true
          });
          break;

        case 'stopped_typing':
        case 'пользователь_перестал_печатать':
          _messageController.add({
            'type': 'stopped_typing',
            'chatId': data['chatId'],
            'userId': data['userId'],
            'isTyping': false
          });
          break;

        case 'user_online':
        case 'пользователь_онлайн':
          _log('👤 Пользователь ${data['userId']} онлайн');
          _messageController.add({
            'type': 'user_online',
            'userId': data['userId'],
            'isOnline': true
          });
          break;

        case 'user_offline':
        case 'пользователь_офлайн':
          _log('👤 Пользователь ${data['userId']} офлайн');
          _messageController.add({
            'type': 'user_offline',
            'userId': data['userId'],
            'isOnline': false
          });
          break;

        case 'message_read':
        case 'сообщение_прочитано':
          _messageController.add({
            'type': 'message_read',
            'chatId': data['chatId'],
            'messageId': data['messageId'],
            'userId': data['userId']
          });
          break;

        case 'chat_created':
          _messageController.add({
            'type': 'chat_created',
            'chat': data['chat'] ?? data,
          });
          break;

        case 'chat_deleted':
          _messageController.add({
            'type': 'chat_deleted',
            'chatId': data['chatId'],
          });
          break;

        // === ОБРАБОТКА ЗВОНКОВ ===
        case 'call_offer':
          _log('📞 Входящий звонок');
          _messageController.add({
            'type': 'call_offer',
            'callId': data['callId'],
            'chatId': data['chatId'],
            'callerId': data['callerId'],
            'callerName': data['callerName'],
            'callerAvatar': data['callerAvatar'],
            'callType': data['callType'],
            'offer': data['offer'],
          });
          break;

        case 'call_answer':
          _log('📞 Ответ на звонок получен');
          _messageController.add({
            'type': 'call_answer',
            'callId': data['callId'],
            'answer': data['answer'],
          });
          break;

        case 'call_ice_candidate':
          _log('🧊 ICE кандидат получен');
          _messageController.add({
            'type': 'call_ice_candidate',
            'callId': data['callId'],
            'candidate': data['candidate'],
          });
          break;

        case 'call_ended':
          _log('📞 Звонок завершен');
          _messageController.add({
            'type': 'call_ended',
            'callId': data['callId'],
            'reason': data['reason'],
            'duration': data['duration'],
          });
          break;

        case 'call_declined':
          _log('📞 Звонок отклонен');
          _messageController.add({
            'type': 'call_declined',
            'callId': data['callId'],
          });
          break;

        case 'call_error':
          _log('📞 Ошибка звонка: ${data['error']}');
          _messageController.add({
            'type': 'call_error',
            'callId': data['callId'],
            'error': data['error'],
            'message': data['message'],
          });
          break;

        case 'call_offer_sent':
          _log('📞 Предложение звонка отправлено');
          _messageController.add({
            'type': 'call_offer_sent',
            'callId': data['callId'],
            'status': data['status'],
          });
          break;

        case 'ping':
          send({'type': 'pong'});
          break;

        case 'pong':
          _log('Получен pong');
          break;

        case 'error':
          _log('Ошибка от сервера: ${data['message']}');
          break;

        default:
          _log('Неизвестный тип сообщения: ${data['type']}');
      }
    } catch (e) {
      _log('Ошибка обработки сообщения: $e');
    }
  }

  void _handleAuthSuccess(Map<String, dynamic> data) {
    _userId = data['userId']?.toString();
    _isAuthenticated = true;
    _isConnecting = false;
    _connectionTimeoutTimer?.cancel();
    _reconnectAttempts = 0;

    _log('Авторизация успешна. User ID: $_userId');

    _statusController.add(ConnectionStatus.connected);

    _sendQueuedMessages();
    _startPingTimer();

    _messageController.add({
      'type': 'auth_success',
      'userId': _userId,
    });
  }

  void _handleAuthError(Map<String, dynamic> data) {
    _log('Ошибка авторизации: ${data['error']}');
    _isAuthenticated = false;
    _isConnecting = false;
    _connectionTimeoutTimer?.cancel();

    _messageController.add({
      'type': 'auth_error',
      'error': data['error'],
    });

    _statusController.add(ConnectionStatus.error);
    disconnect();
  }

  void _handleConnectionError(String error) {
    _log('Ошибка соединения: $error');
    _isConnecting = false;
    _isAuthenticated = false;
    _connectionTimeoutTimer?.cancel();
    _statusController.add(ConnectionStatus.error);
    _scheduleReconnect();
  }

  void _handleDisconnection() {
    _log('Отключение');
    _isConnecting = false;
    _isAuthenticated = false;
    _connectionTimeoutTimer?.cancel();
    _statusController.add(ConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  void send(Map<String, dynamic> data) {
    if (_channel == null) {
      _log(
          'WebSocket канал не существует, добавляем в очередь: ${data['type']}');
      _messageQueue.add(data);
      return;
    }

    if (_channel!.closeCode != null) {
      _log(
          'WebSocket канал закрыт (код: ${_channel!.closeCode}), добавляем в очередь: ${data['type']}');
      _messageQueue.add(data);
      return;
    }

    if (data['type'] != 'auth' && data['type'] != 'ping' && !_isAuthenticated) {
      _log('Не авторизован, добавляем в очередь: ${data['type']}');
      _messageQueue.add(data);
      return;
    }

    try {
      final message = json.encode(data);
      _channel!.sink.add(message);
      _log('↑ Отправлено: ${data['type']}');
    } catch (e) {
      _log('Ошибка отправки: $e');
      if (data['type'] != 'auth') {
        _messageQueue.add(data);
      }
      if (!_isConnecting) {
        _handleConnectionError('Send failed: $e');
      }
    }
  }

  void _sendQueuedMessages() {
    if (_messageQueue.isEmpty) return;

    _log('Отправка ${_messageQueue.length} сообщений из очереди');
    final queue = List<Map<String, dynamic>>.from(_messageQueue);
    _messageQueue.clear();

    for (final message in queue) {
      send(message);
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    final data = {
      'type': 'send_message',
      'chatId': message['chatId'],
      'content': message['content'],
      'messageType': message['messageType'] ?? 'text',
      'tempId': message['tempId'],
      'replyToId': message['replyToId'],
    };

    send(data);
  }

  void sendTyping(String chatId, bool isTyping) {
    send({
      'type': isTyping ? 'typing' : 'stopped_typing',
      'chatId': chatId,
      'userId': _userId,
    });
  }

  void joinChat(String chatId) {
    send({
      'type': 'join_chat',
      'chatId': chatId,
    });
  }

  void leaveChat(String chatId) {
    send({
      'type': 'leave_chat',
      'chatId': chatId,
    });
  }

  void markAsRead(String chatId, String? messageId) {
    send({
      'type': 'mark_read',
      'chatId': chatId,
      'messageId': messageId,
    });
  }

  // === МЕТОДЫ ДЛЯ ЗВОНКОВ ===
  void sendCallOffer(String callId, String chatId, String callType,
      Map<String, dynamic> offer, String receiverId) {
    send({
      'type': 'call_offer',
      'callId': callId,
      'chatId': chatId,
      'receiverId': receiverId, // ✅ ДОБАВЛЕНО
      'callType': callType,
      'offer': offer,
    });
  }

  void sendCallAnswer(String callId, Map<String, dynamic> answer) {
    send({
      'type': 'call_answer',
      'callId': callId,
      'answer': answer,
    });
  }

  void sendIceCandidate(String callId, Map<String, dynamic> candidate) {
    send({
      'type': 'call_ice_candidate',
      'callId': callId,
      'candidate': candidate,
    });
  }

  void endCall(String callId, String reason) {
    send({
      'type': 'call_end',
      'callId': callId,
      'reason': reason,
    });
  }

  void declineCall(String callId) {
    send({
      'type': 'call_decline',
      'callId': callId,
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isConnected) {
        send({
          'type': 'ping',
          'timestamp': DateTime.now().toIso8601String(),
        });
        _log('↑ Ping отправлен');
      }
    });
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null ||
        _reconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);

    _log(
        'Переподключение через ${delay.inSeconds} сек (попытка $_reconnectAttempts)');

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (!isConnected && _token != null) {
        connect(token: _token, userId: _userId);
      }
    });
  }

  void disconnect() {
    _log('Отключение от WebSocket');

    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _connectionTimeoutTimer?.cancel();
    _subscription?.cancel();

    try {
      _channel?.sink.close(status.normalClosure);
    } catch (e) {
      _log('Ошибка при закрытии канала: $e');
    }

    _channel = null;
    _isConnecting = false;
    _isAuthenticated = false;
    _reconnectAttempts = 0;
    _messageQueue.clear();

    _statusController.add(ConnectionStatus.disconnected);
  }

  void reconnect() {
    disconnect();
    if (_token != null) {
      connect(token: _token, userId: _userId);
    }
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _messageController.close();
  }
}
