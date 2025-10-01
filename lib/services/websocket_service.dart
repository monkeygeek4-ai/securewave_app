import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Message>.broadcast();

  Stream<Message> get messages => _messageController.stream;

  void connect(String chatId) {
    // For production
    // final wsUrl = Uri.parse('wss://securewave.sbk-19.ru/ws');

    // For local development
    // final wsUrl = Uri.parse('ws://localhost:8080/ws');

    // For now, skip WebSocket connection
    print('WebSocket connection would be established for chat: $chatId');
  }

  void sendMessage(Map<String, dynamic> message) {
    _channel?.sink.add(message);
  }

  void sendTypingStatus(bool isTyping) {
    // Send typing status
  }

  void disconnect() {
    _channel?.sink.close();
    _messageController.close();
  }
}
