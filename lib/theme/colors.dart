import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// Dark theme colours (default)
class PulseColors {
  static final ValueNotifier<String> themeNotifier = ValueNotifier<String>(_themeMode);

  static String get _themeMode {
    try {
      final box = Hive.box('settings_box');
      return box.get('theme_mode', defaultValue: 'Dark') as String;
    } catch (_) {
      return 'Dark';
    }
  }

  static void setTheme(String mode) {
    try {
      final box = Hive.box('settings_box');
      box.put('theme_mode', mode);
      themeNotifier.value = mode;
    } catch (_) {
      themeNotifier.value = mode;
    }
  }

  static bool get isLight => _themeMode == 'Light' || _themeMode == 'Creme';

  static Color get background {
    switch (_themeMode) {
      case 'AMOLED':
        return AmoledColors.background;
      case 'Light':
        return LightColors.background;
      case 'Creme':
        return CremeColors.background;
      case 'RDR2':
      case 'Red Dead':
        return Rdr2Colors.background;
      case 'Manga':
        return MangaColors.background;
      case 'Anime':
        return AnimeColors.background;
      case 'Gamer':
        return GamerColors.background;
      case 'Turkish':
        return TurkishColors.background;
      default:
        return const Color(0xFF0F121C); // Deep midnight indigo-charcoal
    }
  }

  static Color get surface {
    switch (_themeMode) {
      case 'AMOLED':
        return AmoledColors.surface;
      case 'Light':
        return LightColors.surface;
      case 'Creme':
        return CremeColors.surface;
      case 'RDR2':
      case 'Red Dead':
        return Rdr2Colors.surface;
      case 'Manga':
        return MangaColors.surface;
      case 'Anime':
        return AnimeColors.surface;
      case 'Gamer':
        return GamerColors.surface;
      case 'Turkish':
        return TurkishColors.surface;
      default:
        return const Color(0xFF171B29);
    }
  }

  static Color get surfaceHigh {
    switch (_themeMode) {
      case 'AMOLED':
        return AmoledColors.surfaceHigh;
      case 'Light':
        return LightColors.surfaceHigh;
      case 'Creme':
        return CremeColors.surfaceHigh;
      case 'RDR2':
      case 'Red Dead':
        return Rdr2Colors.surfaceHigh;
      case 'Manga':
        return MangaColors.surfaceHigh;
      case 'Anime':
        return AnimeColors.surfaceHigh;
      case 'Gamer':
        return GamerColors.surfaceHigh;
      case 'Turkish':
        return TurkishColors.surfaceHigh;
      default:
        return const Color(0xFF22273B);
    }
  }

  static Color get accentPrimary {
    switch (_themeMode) {
      case 'AMOLED':
        return AmoledColors.accentPrimary;
      case 'Light':
        return LightColors.accentPrimary;
      case 'Creme':
        return CremeColors.accentPrimary;
      case 'RDR2':
      case 'Red Dead':
        return Rdr2Colors.accentPrimary;
      case 'Manga':
        return MangaColors.accentPrimary;
      case 'Anime':
        return AnimeColors.accentPrimary;
      case 'Gamer':
        return GamerColors.accentPrimary;
      case 'Turkish':
        return TurkishColors.accentPrimary;
      default:
        return const Color(0xFF818CF8); // Vibrant Electric Indigo
    }
  }

  static Color get accentSecondary {
    switch (_themeMode) {
      case 'AMOLED':
        return AmoledColors.accentSecondary;
      case 'Light':
        return LightColors.accentSecondary;
      case 'Creme':
        return CremeColors.accentSecondary;
      case 'RDR2':
      case 'Red Dead':
        return Rdr2Colors.accentSecondary;
      case 'Manga':
        return MangaColors.accentSecondary;
      case 'Anime':
        return AnimeColors.accentSecondary;
      case 'Gamer':
        return GamerColors.accentSecondary;
      case 'Turkish':
        return TurkishColors.accentSecondary;
      default:
        return const Color(0xFF38BDF8); // Electric Sky Cyan
    }
  }

  static Color get success {
    switch (_themeMode) {
      case 'AMOLED':
        return AmoledColors.success;
      case 'Light':
        return LightColors.success;
      case 'Creme':
        return CremeColors.success;
      case 'RDR2':
      case 'Red Dead':
        return Rdr2Colors.success;
      case 'Manga':
        return MangaColors.success;
      case 'Anime':
        return AnimeColors.success;
      case 'Gamer':
        return GamerColors.success;
      case 'Turkish':
        return TurkishColors.success;
      default:
        return const Color(0xFF22C55E);
    }
  }

  static Color get danger {
    switch (_themeMode) {
      case 'AMOLED':
        return AmoledColors.danger;
      case 'Light':
        return LightColors.danger;
      case 'Creme':
        return CremeColors.danger;
      case 'RDR2':
      case 'Red Dead':
        return Rdr2Colors.danger;
      case 'Manga':
        return MangaColors.danger;
      case 'Anime':
        return AnimeColors.danger;
      case 'Gamer':
        return GamerColors.danger;
      case 'Turkish':
        return TurkishColors.danger;
      default:
        return const Color(0xFFEF4444);
    }
  }

  static Color get textPrimary {
    switch (_themeMode) {
      case 'Light':
        return LightColors.textPrimary;
      case 'Creme':
        return CremeColors.textPrimary;
      case 'RDR2':
      case 'Red Dead':
        return Rdr2Colors.textPrimary;
      case 'Manga':
        return MangaColors.textPrimary;
      case 'Anime':
        return AnimeColors.textPrimary;
      case 'Gamer':
        return GamerColors.textPrimary;
      case 'Turkish':
        return TurkishColors.textPrimary;
      default:
        return const Color(0xFFF8FAFC);
    }
  }

  static Color get textSecondary {
    switch (_themeMode) {
      case 'Light':
        return LightColors.textSecondary;
      case 'Creme':
        return CremeColors.textSecondary;
      case 'RDR2':
      case 'Red Dead':
        return Rdr2Colors.textSecondary;
      case 'Manga':
        return MangaColors.textSecondary;
      case 'Anime':
        return AnimeColors.textSecondary;
      case 'Gamer':
        return GamerColors.textSecondary;
      case 'Turkish':
        return TurkishColors.textSecondary;
      default:
        return const Color(0xFF94A3B8);
    }
  }

  static Color get onAccentPrimary {
    switch (_themeMode) {
      case 'AMOLED':
        return AmoledColors.onAccentPrimary;
      case 'Light':
        return LightColors.onAccentPrimary;
      case 'Creme':
        return CremeColors.onAccentPrimary;
      default:
        return accentPrimary;
    }
  }

  static Color get onAccentSecondary {
    switch (_themeMode) {
      case 'AMOLED':
        return AmoledColors.onAccentSecondary;
      case 'Light':
        return LightColors.onAccentSecondary;
      case 'Creme':
        return CremeColors.onAccentSecondary;
      default:
        return accentSecondary;
    }
  }

  static Color get activeAccentPrimary {
    switch (_themeMode) {
      case 'Light':
        return LightColors.onAccentPrimary;
      case 'Creme':
        return CremeColors.onAccentPrimary;
      default:
        return accentPrimary;
    }
  }

  static Color get activeAccentSecondary {
    switch (_themeMode) {
      case 'Light':
        return LightColors.onAccentSecondary;
      case 'Creme':
        return CremeColors.onAccentSecondary;
      default:
        return accentSecondary;
    }
  }

  static Gradient get accentGradient {
    return LinearGradient(
      colors: [accentPrimary, accentSecondary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static List<BoxShadow> glowShadow(Color color) {
    final opacity = isLight ? 0.12 : 0.28;
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: 16,
        spreadRadius: -4,
        offset: const Offset(0, 8),
      ),
    ];
  }
}

/// AMOLED (100% Pitch Pure Black) theme colours
class AmoledColors {
  static const Color background = Color(0xFF000000); // 100% Pitch Black
  static const Color surface = Color(0xFF080808);
  static const Color surfaceHigh = Color(0xFF141414);

  static const Color accentPrimary = Color(0xFFA855F7); // High-luminance Neon Violet
  static const Color accentSecondary = Color(0xFF06B6D4); // High-contrast Neon Cyan

  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFF43F5E);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF71717A);

  static const Color onAccentPrimary = Color(0xFFC084FC);
  static const Color onAccentSecondary = Color(0xFF22D3EE);
}

/// Light theme colours (High contrast, crisp slate)
class LightColors {
  static const Color background = Color(0xFFF8FAFC); // Clean crisp light background
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceHigh = Color(0xFFE2E8F0);

  static const Color accentPrimary = Color(0xFF6D28D9); // Deep Royal Violet
  static const Color accentSecondary = Color(0xFF0284C7); // Deep Ocean Azure

  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);

  static const Color textPrimary = Color(0xFF0F172A); // High-contrast Deep Slate
  static const Color textSecondary = Color(0xFF475569); // Slate Gray

  static const Color onAccentPrimary = Color(0xFF6D28D9);
  static const Color onAccentSecondary = Color(0xFF0284C7);
}

/// Creme (warm, rich ivory/espresso) theme colours
class CremeColors {
  static const Color background = Color(0xFFFAF5EC); // Warm ivory background
  static const Color surface = Color(0xFFFFFDF9); // Clean ivory card
  static const Color surfaceHigh = Color(0xFFEDE4D3); // Warm cream highlight
  
  static const Color accentPrimary = Color(0xFF92400E); // Deep roasted amber-bronze
  static const Color accentSecondary = Color(0xFF15803D); // Deep forest emerald
  
  static const Color textPrimary = Color(0xFF1C1917); // Deep Stone Espresso (100% readable!)
  static const Color textSecondary = Color(0xFF57534E); // Warm Stone Taupe

  static const Color success = Color(0xFF15803D);
  static const Color danger = Color(0xFFB91C1C);

  static const Color onAccentPrimary = Color(0xFF78350F); // High-contrast text bronze
  static const Color onAccentSecondary = Color(0xFF14532D); // High-contrast text emerald
}

/// 🤠 Red Dead Redemption 2 Outlaw theme
class Rdr2Colors {
  static const Color background = Color(0xFF100707); // Dark Frontier Mahogany
  static const Color surface = Color(0xFF1D0B0D); // Weathered Saloon Ironwood
  static const Color surfaceHigh = Color(0xFF2C1215); // Outlaw Saddle Leather
  
  static const Color accentPrimary = Color(0xFFDC2626); // RDR Blood Crimson
  static const Color accentSecondary = Color(0xFFD97706); // Amber Sunset Gold
  
  static const Color textPrimary = Color(0xFFFDF2F0); // Parchment White
  static const Color textSecondary = Color(0xFFBCA3A3); // Dusty Trail Brown

  static const Color success = Color(0xFF15803D);
  static const Color danger = Color(0xFF991B1B);
}

/// 📖 Manga Shonen Monochrome & Scarlet theme
class MangaColors {
  static const Color background = Color(0xFF0A0A0C); // Deep Sumi Ink
  static const Color surface = Color(0xFF141418); // Screentone Charcoal
  static const Color surfaceHigh = Color(0xFF22222A); // Halftone Gray
  
  static const Color accentPrimary = Color(0xFFFF2E63); // Shonen Manga Scarlet
  static const Color accentSecondary = Color(0xFFF8FAFC); // Pure Manga Paper White
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8);

  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
}

/// 🌸 Anime Neo-Tokyo & Sakura theme
class AnimeColors {
  static const Color background = Color(0xFF0C0714); // Cyber Tokyo Night Sky
  static const Color surface = Color(0xFF180E29); // Deep Neon Violet
  static const Color surfaceHigh = Color(0xFF271540); // Radiant Lavender Surface
  
  static const Color accentPrimary = Color(0xFFFF2E93); // Vibrant Sakura Neon Pink
  static const Color accentSecondary = Color(0xFF00F0FF); // Electric Cyber Cyan
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFC4B5FD);

  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFFF0055);
}

/// 🎮 Gamer Battlestation RGB theme
class GamerColors {
  static const Color background = Color(0xFF07090E); // Matte Stealth Chassis
  static const Color surface = Color(0xFF0F141F); // Dark Carbon Surface
  static const Color surfaceHigh = Color(0xFF1A2333); // RGB Glow Border
  
  static const Color accentPrimary = Color(0xFF00FF66); // Toxic Razer Green
  static const Color accentSecondary = Color(0xFF00E5FF); // Cyber RGB Cyan
  
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF86EFAC);

  static const Color success = Color(0xFF00FF66);
  static const Color danger = Color(0xFFFF0055);
}

/// 🇹🇷 Turkish Ottoman Crimson & Aegean Turquoise theme
class TurkishColors {
  static const Color background = Color(0xFF130407); // Anatolian Midnight
  static const Color surface = Color(0xFF20070B); // Ottoman Velvet
  static const Color surfaceHigh = Color(0xFF320C12); // Imperial Crimson Silk
  
  static const Color accentPrimary = Color(0xFFE30A17); // Turkish Flag Red
  static const Color accentSecondary = Color(0xFF00A3A6); // Aegean Turquoise
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFE2B2B6); // Soft Rose Silver

  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
}
