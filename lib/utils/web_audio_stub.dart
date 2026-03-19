// lib/utils/web_audio_stub.dart
// Заглушка для Mobile платформ (Android/iOS)

class AudioElement {
  AudioElement();

  bool autoplay = false;
  bool controls = false;
  dynamic srcObject;
  double volume = 1.0;
  bool muted = false;
  bool paused = true;

  void setAttribute(String name, String value) {}

  Future<void> play() async {}

  void pause() {}

  void remove() {}

  AudioElementStyle get style => AudioElementStyle();
}

class AudioElementStyle {
  String display = 'none';
}

class _Document {
  _Body? get body => _Body();
}

class _Body {
  void append(dynamic element) {}
}

// ⭐ Экспортируем document для совместимости
final document = _Document();
