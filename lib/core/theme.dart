import 'package:flutter/material.dart';

class NeuroTheme {
  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F0F12),
    primaryColor: const Color(0xFF7C4DFF),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF7C4DFF),
      secondary: Color(0xFFB39DDB),
      surface: Color(0xFF1E1E24),
    ),
  );
}