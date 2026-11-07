import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'colors.dart';

enum TypographyStyle {
  auto,
  modern,
  cyberpunk,
  western,
  comicBook,
  deathNote,
  batman,
  funky,
  anime,
}

class PulseTypography {
  static final ValueNotifier<String> fontStyleNotifier = ValueNotifier<String>(_fontStyle);

  static String get _fontStyle {
    try {
      final box = Hive.box('settings_box');
      return box.get('font_style', defaultValue: 'Auto') as String;
    } catch (_) {
      return 'Auto';
    }
  }

  static void setFontStyle(String style) {
    try {
      final box = Hive.box('settings_box');
      box.put('font_style', style);
      fontStyleNotifier.value = style;
    } catch (_) {
      fontStyleNotifier.value = style;
    }
  }

  static String get _effectiveStyle {
    final style = fontStyleNotifier.value;
    if (style != 'Auto') return style;

    // Auto-adapt based on active theme
    final theme = PulseColors.themeNotifier.value;
    switch (theme) {
      case 'Cyberpunk':
        return 'Cyberpunk';
      case 'RDR2':
      case 'Red Dead':
        return 'Western';
      case 'Manga':
        return 'Death Note';
      case 'Anime':
        return 'Anime';
      case 'Gamer':
        return 'Batman';
      case 'Royale':
        return 'Death Note'; // Uses Cinzel / Regal
      default:
        return 'Modern';
    }
  }

  // ─── Display Headings ───────────────────────────────────────────────────────
  static TextStyle get displayLarge {
    final style = _effectiveStyle;
    final color = PulseColors.textPrimary;

    switch (style) {
      case 'Cyberpunk':
        return GoogleFonts.orbitron(fontSize: 26, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.0);
      case 'Western':
        return GoogleFonts.rye(fontSize: 26, color: color, letterSpacing: 0.5);
      case 'Comic Book':
      case 'Spiderman':
        return GoogleFonts.bangers(fontSize: 32, color: color, letterSpacing: 1.5);
      case 'Death Note':
        return GoogleFonts.pirataOne(fontSize: 32, color: color, letterSpacing: 1.2);
      case 'Batman':
        return GoogleFonts.russoOne(fontSize: 26, color: color, letterSpacing: 0.5);
      case 'Funky':
        return GoogleFonts.righteous(fontSize: 28, color: color, letterSpacing: 0.8);
      case 'Anime':
        return GoogleFonts.zenDots(fontSize: 24, color: color, letterSpacing: 0.5);
      default:
        return GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: color, letterSpacing: -0.5);
    }
  }

  static TextStyle get displayMedium {
    final style = _effectiveStyle;
    final color = PulseColors.textPrimary;

    switch (style) {
      case 'Cyberpunk':
        return GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.8);
      case 'Western':
        return GoogleFonts.rye(fontSize: 20, color: color, letterSpacing: 0.4);
      case 'Comic Book':
      case 'Spiderman':
        return GoogleFonts.bangers(fontSize: 24, color: color, letterSpacing: 1.2);
      case 'Death Note':
        return GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.8);
      case 'Batman':
        return GoogleFonts.russoOne(fontSize: 20, color: color, letterSpacing: 0.4);
      case 'Funky':
        return GoogleFonts.righteous(fontSize: 22, color: color, letterSpacing: 0.6);
      case 'Anime':
        return GoogleFonts.zenDots(fontSize: 18, color: color, letterSpacing: 0.4);
      default:
        return GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: color, letterSpacing: -0.3);
    }
  }

  static TextStyle get displaySmall {
    final style = _effectiveStyle;
    final color = PulseColors.textPrimary;

    switch (style) {
      case 'Cyberpunk':
        return GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.6);
      case 'Western':
        return GoogleFonts.rye(fontSize: 16, color: color);
      case 'Comic Book':
      case 'Spiderman':
        return GoogleFonts.bangers(fontSize: 20, color: color, letterSpacing: 1.0);
      case 'Death Note':
        return GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w700, color: color);
      case 'Batman':
        return GoogleFonts.russoOne(fontSize: 16, color: color);
      case 'Funky':
        return GoogleFonts.righteous(fontSize: 17, color: color);
      case 'Anime':
        return GoogleFonts.zenDots(fontSize: 14, color: color);
      default:
        return GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: color);
    }
  }

  // ─── Body Text (High legibility with style accent) ──────────────────────────
  static TextStyle get bodyLarge {
    final style = _effectiveStyle;
    final color = PulseColors.textPrimary;

    switch (style) {
      case 'Cyberpunk':
        return GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.3);
      case 'Western':
        return GoogleFonts.alfaSlabOne(fontSize: 14, color: color, letterSpacing: 0.2);
      case 'Comic Book':
      case 'Spiderman':
        return GoogleFonts.comicNeue(fontSize: 16, fontWeight: FontWeight.bold, color: color);
      case 'Death Note':
        return GoogleFonts.cinzel(fontSize: 15, fontWeight: FontWeight.w600, color: color);
      case 'Batman':
        return GoogleFonts.russoOne(fontSize: 14, color: color);
      case 'Funky':
        return GoogleFonts.righteous(fontSize: 15, color: color);
      default:
        return GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w500, color: color);
    }
  }

  static TextStyle get bodyMedium {
    final style = _effectiveStyle;
    final color = PulseColors.textSecondary;

    switch (style) {
      case 'Cyberpunk':
        return GoogleFonts.rajdhani(fontSize: 14, fontWeight: FontWeight.w500, color: color);
      case 'Comic Book':
      case 'Spiderman':
        return GoogleFonts.comicNeue(fontSize: 14, fontWeight: FontWeight.w600, color: color);
      case 'Death Note':
        return GoogleFonts.cinzel(fontSize: 13, fontWeight: FontWeight.w500, color: color);
      default:
        return GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.normal, color: color);
    }
  }

  static TextStyle get bodySmall {
    final style = _effectiveStyle;
    final color = PulseColors.textSecondary;

    switch (style) {
      case 'Cyberpunk':
        return GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.w500, color: color);
      default:
        return GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.normal, color: color);
    }
  }

  // ─── Technical & Metadata Labels ──────────────────────────────────────────
  static TextStyle get monoLabel => GoogleFonts.jetBrainsMono(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: PulseColors.textSecondary,
  );

  static TextStyle get monoLarge => GoogleFonts.jetBrainsMono(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: PulseColors.textPrimary,
  );
}
