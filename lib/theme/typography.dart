import 'package:flutter/material.dart';
import 'colors.dart';

class PulseTypography {
  // Syne for display/headings
  static TextStyle get displayLarge => TextStyle(
    fontFamily: 'Syne',
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: PulseColors.textPrimary,
  );

  static TextStyle get displayMedium => TextStyle(
    fontFamily: 'Syne',
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: PulseColors.textPrimary,
  );

  static TextStyle get displaySmall => TextStyle(
    fontFamily: 'Syne',
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: PulseColors.textPrimary,
  );

  // DM Sans for body UI
  static TextStyle get bodyLarge => TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: PulseColors.textPrimary,
  );

  static TextStyle get bodyMedium => TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: PulseColors.textSecondary,
  );

  static TextStyle get bodySmall => TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 12,
    color: PulseColors.textSecondary,
  );

  // JetBrains Mono for metadata
  static TextStyle get monoLabel => TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: PulseColors.textSecondary,
  );

  static TextStyle get monoLarge => TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: PulseColors.textPrimary,
  );
}
