// lib/providers/web_visibility_stub.dart
// Заглушка - используется когда платформа не определена

void setupWebVisibilityListener({
  Function()? onFocus,
  Function()? onBlur,
  Function(bool)? onVisibilityChange,
}) {
  // Ничего не делает - заглушка
  print('[WebVisibility] Stub - не используется');
}
