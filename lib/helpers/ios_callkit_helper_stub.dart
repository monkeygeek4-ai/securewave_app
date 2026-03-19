// Stub for web platform - CallKit is iOS only
class IOSCallKitHelper {
  static Future<bool> reportIncomingCall({
    required String callId,
    required String callerName,
    bool hasVideo = false,
  }) async {
    return false;
  }

  static Future<void> reportCallEnded(String callId) async {}

  static Future<void> reportCallConnected(String callId) async {}
}
