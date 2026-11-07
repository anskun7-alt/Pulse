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

  static String get themeMode => _themeMode;

  static String get effectiveTheme {
    final mode = _themeMode;
    if (mode == 'System') {
      try {
        final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.light ? 'Light' : 'Dark';
      } catch (_) {
        return 'Dark';
      }
    }
    return mode;
  }

  static bool get isSystemTheme => _themeMode == 'System';

  static bool get isLight {
    final eff = effectiveTheme;
    return eff == 'Light' || eff == 'Creme';
  }

  static void notifyPlatformBrightnessChanged() {
    if (isSystemTheme) {
      themeNotifier.value = 'System_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  static void toggleLightDark() {
    if (isLight) {
      setTheme('Dark');
    } else {
      setTheme('Light');
    }
  }

  static Color get background {
    switch (effectiveTheme) {
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
      case 'Cyberpunk':
        return CyberpunkColors.background;
      case 'Nordic':
        return NordicColors.background;
      case 'Royale':
        return RoyaleColors.background;
      default:
        return const Color(0xFF0F121C); // Deep midnight indigo-charcoal
    }
  }

  static Color get surface {
    switch (effectiveTheme) {
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
      case 'Cyberpunk':
        return CyberpunkColors.surface;
      case 'Nordic':
        return NordicColors.surface;
      case 'Royale':
        return RoyaleColors.surface;
      default:
        return const Color(0xFF171B29);
    }
  }

  static Color get surfaceHigh {
    switch (effectiveTheme) {
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
      case 'Cyberpunk':
        return CyberpunkColors.surfaceHigh;
      case 'Nordic':
        return NordicColors.surfaceHigh;
      case 'Royale':
        return RoyaleColors.surfaceHigh;
      default:
        return const Color(0xFF22273B);
    }
  }

  static Color get accentPrimary {
    switch (effectiveTheme) {
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
      case 'Cyberpunk':
        return CyberpunkColors.accentPrimary;
      case 'Nordic':
        return NordicColors.accentPrimary;
      case 'Royale':
        return RoyaleColors.accentPrimary;
      default:
        return const Color(0xFF818CF8); // Vibrant Electric Indigo
    }
  }

  static Color get accentSecondary {
    switch (effectiveTheme) {
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
      case 'Cyberpunk':
        return CyberpunkColors.accentSecondary;
      case 'Nordic':
        return NordicColors.accentSecondary;
      case 'Royale':
        return RoyaleColors.accentSecondary;
      default:
        return const Color(0xFF38BDF8); // Electric Sky Cyan
    }
  }

  static Color get success {
    switch (effectiveTheme) {
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
      case 'Cyberpunk':
        return CyberpunkColors.success;
      case 'Nordic':
        return NordicColors.success;
      case 'Royale':
        return RoyaleColors.success;
      default:
        return const Color(0xFF22C55E);
    }
  }

  static Color get danger {
    switch (effectiveTheme) {
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
      case 'Cyberpunk':
        return CyberpunkColors.danger;
      case 'Nordic':
        return NordicColors.danger;
      case 'Royale':
        return RoyaleColors.danger;
      default:
        return const Color(0xFFEF4444);
    }
  }

  static Color get textPrimary {
    switch (effectiveTheme) {
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
      case 'Cyberpunk':
        return CyberpunkColors.textPrimary;
      case 'Nordic':
        return NordicColors.textPrimary;
      case 'Royale':
        return RoyaleColors.textPrimary;
      default:
        return const Color(0xFFF8FAFC);
    }
  }

  static Color get textSecondary {
    switch (effectiveTheme) {
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
      case 'Cyberpunk':
        return CyberpunkColors.textSecondary;
      case 'Nordic':
        return NordicColors.textSecondary;
      case 'Royale':
        return RoyaleColors.textSecondary;
      default:
        return const Color(0xFF94A3B8);
    }
  }

  static Color get onAccentPrimary {
    switch (effectiveTheme) {
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
    switch (effectiveTheme) {
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
    switch (effectiveTheme) {
      case 'Light':
        return LightColors.onAccentPrimary;
      case 'Creme':
        return CremeColors.onAccentPrimary;
      default:
        return accentPrimary;
    }
  }

  static Color get activeAccentSecondary {
    switch (effectiveTheme) {
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

  static List<BoxShadow> glowShadow(Color color, {double? radius, double? spread, Offset? offset}) {
    final opacity = isLight ? 0.14 : 0.32;
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: radius ?? 18,
        spreadRadius: spread ?? 0,
        offset: offset ?? const Offset(0, 4),
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

/// 🤠 Red Dead Redemption 2 Outlaw theme - Iconic Blood Red & Silhouette Black
class Rdr2Colors {
  static const Color background = Color(0xFF0F0606); // Deep Charred Outlaw Black
  static const Color surface = Color(0xFF1B0709); // Weathered Saloon Ironwood
  static const Color surfaceHigh = Color(0xFF2C0B0F); // Deep Frontier Crimson
  
  static const Color accentPrimary = Color(0xFFD61A24); // RDR2 Iconic Poster Blood Red
  static const Color accentSecondary = Color(0xFFFF2A3B); // Vivid Outlaw Scarlet Highlight
  
  static const Color textPrimary = Color(0xFFFAF2E6); // Stencil Parchment White
  static const Color textSecondary = Color(0xFFC7AAA0); // Dusty Trail Sepia

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

/// ⚡ Cyberpunk 2077 Neon theme - Electric Cyber Yellow & Hot Magenta
class CyberpunkColors {
  static const Color background = Color(0xFF07070A); // Obsidian Void
  static const Color surface = Color(0xFF111218); // Night City Carbon
  static const Color surfaceHigh = Color(0xFF1C1E29); // Hologram Slate
  
  static const Color accentPrimary = Color(0xFFFCEE0A); // High-voltage Cyberpunk Yellow
  static const Color accentSecondary = Color(0xFFFF0055); // Neon Arasaka Magenta
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9092A8);

  static const Color success = Color(0xFF00FF9F);
  static const Color danger = Color(0xFFFF0055);
}

/// ❄️ Nordic Glacier Frost theme - Arctic Blue & Polar Ice
class NordicColors {
  static const Color background = Color(0xFF070D18); // Deep Arctic Ocean
  static const Color surface = Color(0xFF0E1A2D); // Iceberg Surface
  static const Color surfaceHigh = Color(0xFF172944); // Crystalline Fjord
  
  static const Color accentPrimary = Color(0xFF48CAE4); // Vivid Glacier Turquoise
  static const Color accentSecondary = Color(0xFF90E0EF); // Polar Aurora Blue
  
  static const Color textPrimary = Color(0xFFF0F8FF);
  static const Color textSecondary = Color(0xFF8DA4C4);

  static const Color success = Color(0xFF2DD4BF);
  static const Color danger = Color(0xFFF87171);
}

/// 👑 Royale Gold & Onyx theme - Pure Noir & 24K Imperial Brushed Gold
class RoyaleColors {
  static const Color background = Color(0xFF0A0908); // Imperial Noir
  static const Color surface = Color(0xFF161412); // Velvet Charcoal
  static const Color surfaceHigh = Color(0xFF26211C); // Burnished Gold Shadow
  
  static const Color accentPrimary = Color(0xFFD4AF37); // 24K Pure Imperial Gold
  static const Color accentSecondary = Color(0xFFFFB703); // Radiant Warm Amber Gold
  
  static const Color textPrimary = Color(0xFFFFFDF5);
  static const Color textSecondary = Color(0xFFC5BCA8);

  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFE11D48);
}

