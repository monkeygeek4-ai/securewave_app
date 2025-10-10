// lib/providers/web_visibility_mobile.dart
// Для Mobile платформ (Android/iOS)

void setupWebVisibilityListener({
  Function()? onFocus,
  Function()? onBlur,
  Function(bool)? onVisibilityChange,
}) {
  print('[WebVisibility] Mobile платформа - Web visibility не используется');
  // На мобильных платформах используем WidgetsBindingObserver
  // Эти события обрабатываются на уровне StatefulWidget
}
