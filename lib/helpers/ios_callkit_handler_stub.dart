// Stub для Web/Android/других платформ - CallKit есть только на iOS
//
// ⭐⭐⭐ ВАЖНО:
// Этот класс должен иметь те же методы, что и реальный `IOSCallKitHandler`,
// чтобы Flutter Web/Android спокойно компилировались, но при этом
// все методы здесь являются no-op и НИЧЕГО не делают.
//
// Никаких импортов `dart:io` и нативных каналов здесь быть не должно.

class IOSCallKitHandler {
  // Используем singleton, как и в основной реализации
  static final IOSCallKitHandler _instance = IOSCallKitHandler._internal();
  factory IOSCallKitHandler() => _instance;
  IOSCallKitHandler._internal();

  /// Инициализация обработчика CallKit (no-op на не‑iOS платформах)
  void initialize() {
    // Ничего не делаем на Web/Android
  }

  /// Проверка: был ли звонок принят через CallKit
  /// На не‑iOS платформах всегда возвращаем false
  bool wasCallAcceptedViaCallKit(String callId) {
    return false;
  }

  /// Проверка: был ли CallKit уже показан для данного звонка
  /// На не‑iOS платформах всегда false
  bool wasCallKitShownForCall(String callId) {
    return false;
  }

  /// Пометить, что CallKit был показан для звонка
  /// На не‑iOS платформах no-op
  void markCallKitShownForCall(String callId) {
    // no-op
  }

  // На Web/Android VoIP токен не используется, но методы должны существовать
  void setVoipTokenCallback(Function(String token) callback) {
    // no-op
  }

  String? get voipToken => null;
}
