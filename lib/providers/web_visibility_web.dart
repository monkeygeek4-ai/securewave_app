// lib/providers/web_visibility_web.dart
// Для Web платформы - использует dart:html

import 'dart:html' as html;

void setupWebVisibilityListener({
  Function()? onFocus,
  Function()? onBlur,
  Function(bool)? onVisibilityChange,
}) {
  print('[WebVisibility] Настройка для Web платформы');

  if (onFocus != null) {
    html.window.onFocus.listen((_) {
      print('[WebVisibility] 🟢 Window Focus');
      onFocus();
    });
  }

  if (onBlur != null) {
    html.window.onBlur.listen((_) {
      print('[WebVisibility] 🔴 Window Blur');
      onBlur();
    });
  }

  if (onVisibilityChange != null) {
    html.document.onVisibilityChange.listen((_) {
      final isVisible = !html.document.hidden!;
      print('[WebVisibility] 👁️ Visibility changed: $isVisible');
      onVisibilityChange(isVisible);
    });
  }
}
