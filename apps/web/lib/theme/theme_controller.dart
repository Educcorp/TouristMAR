import 'package:flutter/material.dart';

import '../platform/platform_services.dart';

const _themeStorageKey = 'touristmar_theme_mode';

/// Controla el modo claro/oscuro de toda la app. Es un [ValueNotifier] que
/// envuelve el `MaterialApp` (ver `main.dart`): cambiar [mode] reconstruye
/// toda la app desde la raíz, así los getters de [AppColors] (que leen
/// [isDark] directamente, sin pasar por `context`) siempre reflejan el modo
/// actual sin necesitar Provider/InheritedWidget.
class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> mode = ValueNotifier(_readSaved());

  static bool get isDark => mode.value == ThemeMode.dark;

  static void toggle() => set(isDark ? ThemeMode.light : ThemeMode.dark);

  static void set(ThemeMode value) {
    mode.value = value;
    PlatformServices.store.write(_themeStorageKey, value == ThemeMode.dark ? 'dark' : 'light');
  }

  static ThemeMode _readSaved() {
    final saved = PlatformServices.store.read(_themeStorageKey);
    return saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }
}
