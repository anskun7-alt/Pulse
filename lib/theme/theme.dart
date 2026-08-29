import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

class PulseTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: PulseColors.background,
      colorScheme: ColorScheme.dark(
        primary: PulseColors.accentPrimary,
        secondary: PulseColors.accentSecondary,
        surface: PulseColors.surface,
        onSurface: PulseColors.textPrimary,
        error: PulseColors.danger,
      ),
      cardTheme: CardThemeData(
        color: PulseColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E1E30), width: 1),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: PulseColors.accentPrimary,
        inactiveTrackColor: PulseColors.surfaceHigh,
        thumbColor: PulseColors.textPrimary,
        overlayColor: PulseColors.accentPrimary.withValues(alpha: 0.15),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      textTheme: TextTheme(
        displayLarge: PulseTypography.displayLarge,
        titleLarge: PulseTypography.displayMedium,
        titleMedium: PulseTypography.displaySmall,
        bodyLarge: PulseTypography.bodyLarge,
        bodyMedium: PulseTypography.bodyMedium,
        bodySmall: PulseTypography.bodySmall,
      ),
    );
  }

  static ThemeData get amoledTheme {
    return darkTheme.copyWith(
      scaffoldBackgroundColor: Colors.black,
      colorScheme: darkTheme.colorScheme.copyWith(
        surface: const Color(0xFF0C0C0C),
        onSurface: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF0C0C0C),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF222222), width: 1),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF6F6FA),
      colorScheme: ColorScheme.light(
        primary: PulseColors.accentPrimary,
        secondary: PulseColors.accentSecondary,
        surface: Colors.white,
        onSurface: PulseColors.textPrimary,
        error: PulseColors.danger,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E5EF), width: 1),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: PulseColors.accentPrimary,
        inactiveTrackColor: const Color(0xFFE5E5EF),
        thumbColor: PulseColors.accentPrimary,
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      textTheme: TextTheme(
        displayLarge: PulseTypography.displayLarge,
        titleLarge: PulseTypography.displayMedium,
        titleMedium: PulseTypography.displaySmall,
        bodyLarge: PulseTypography.bodyLarge,
        bodyMedium: PulseTypography.bodyMedium,
        bodySmall: PulseTypography.bodySmall,
      ),
    );
  }

  static ThemeData get cremeTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFAF5EC),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFB57C58), // warm cinnamon/caramel
        secondary: Color(0xFF6B8068), // soft sage
        surface: Color(0xFFFFFDF9), // ivory
        onSurface: Color(0xFF2E251B), // espresso
        error: Color(0xFFC62828),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFDF9),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF3EAD8), width: 1),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: Color(0xFFB57C58),
        inactiveTrackColor: Color(0xFFF3EAD8),
        thumbColor: Color(0xFFB57C58),
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Syne',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2E251B),
        ),
        titleLarge: TextStyle(
          fontFamily: 'Syne',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2E251B),
        ),
        titleMedium: TextStyle(
          fontFamily: 'Syne',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2E251B),
        ),
        bodyLarge: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 16,
          color: Color(0xFF2E251B),
        ),
        bodyMedium: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 14,
          color: Color(0xFF7A6F62),
        ),
        bodySmall: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 12,
          color: Color(0xFF7A6F62),
        ),
      ),
    );
  }
}
