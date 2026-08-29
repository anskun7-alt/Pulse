import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

class PulseTheme {
  static ThemeData get theme {
    final isLight = PulseColors.isLight;

    return ThemeData(
      useMaterial3: true,
      brightness: isLight ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: PulseColors.background,
      colorScheme: isLight
          ? ColorScheme.light(
              primary: PulseColors.accentPrimary,
              secondary: PulseColors.accentSecondary,
              surface: PulseColors.surface,
              onSurface: PulseColors.textPrimary,
              error: PulseColors.danger,
            )
          : ColorScheme.dark(
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
          side: BorderSide(
            color: isLight 
                ? PulseColors.surfaceHigh.withValues(alpha: 0.8) 
                : const Color(0xFF1E1E30),
            width: 1,
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: PulseColors.accentPrimary,
        inactiveTrackColor: PulseColors.surfaceHigh,
        thumbColor: PulseColors.accentPrimary,
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

  // Backwards compatibility getters
  static ThemeData get darkTheme => theme;
  static ThemeData get amoledTheme => theme;
  static ThemeData get lightTheme => theme;
  static ThemeData get cremeTheme => theme;
}
