import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  static bool get isDark => themeMode.value == ThemeMode.dark;

  static void toggle() {
    themeMode.value = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}
