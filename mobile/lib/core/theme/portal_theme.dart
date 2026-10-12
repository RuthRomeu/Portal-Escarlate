
import 'package:flutter/material.dart';

class PortalColors {
  static const background = Color(0xFF080304);
  static const darkWine = Color(0xFF22080A);
  static const wine = Color(0xFF2F0608);
  static const crimson = Color(0xFF8F1019);
  static const ruby = Color(0xFFB91C1C);

  static const gold = Color(0xFFE7C566);
  static const goldLight = Color(0xFFFEF1B8);
  static const goldDark = Color(0xFFB98724);

  static const text = Color(0xFFF8EDD0);
  static const muted = Color(0xFFDACAA0);
  static const danger = Color(0xFFFFB8B8);
  static const onGold = Color(0xFF2C1106);

  static const field = Color(0xFF140607);
  static const border = Color(0x5575520F);
}

class PortalTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: PortalColors.background,
    colorScheme: const ColorScheme.dark(
      primary: PortalColors.gold,
      secondary: PortalColors.ruby,
      surface: PortalColors.darkWine,
      onSurface: PortalColors.text,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: PortalColors.text),
      bodyLarge: TextStyle(color: PortalColors.text),
    ),
    selectionColor: PortalColors.gold,
  );
}
