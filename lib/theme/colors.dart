import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// Dark theme colours (default)
class PulseColors {
  static String get _themeMode {
    try {
      final box = Hive.box('settings_box');
      return box.get('theme_mode', defaultValue: 'Dark') as String;
    } catch (_) {
      return 'Dark';
    }
  }

  static Color get background {
    switch (_themeMode) {
      case 'AMOLED':
        return AmoledColors.background;
      case 'Light':
        return LightColors.background;
      case 'Creme':
        return CremeColors.background;
      default:
        return const Color(0xFF080810);
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
      default:
        return const Color(0xFF12121E);
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
      default:
        return const Color(0xFF1C1C2E);
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
      default:
        return const Color(0xFF7C3AED);
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
      default:
        return const Color(0xFF06B6D4);
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
      default:
        return const Color(0xFFEF4444);
    }
  }

  // Light theme text colours – higher contrast
  static Color get textPrimary {
    switch (_themeMode) {
      case 'AMOLED':
        return Colors.white;
      case 'Light':
        return Colors.black; // darker black for better readability on light background
      case 'Creme':
        return CremeColors.textPrimary;
      default:
        return const Color(0xFFFFFFFF);
    }
  }

  static Color get textSecondary {
    switch (_themeMode) {
      case 'AMOLED':
        return const Color(0xFF9E9EAF);
      case 'Light':
        return Colors.black54; // softer secondary text on light background
      case 'Creme':
        return CremeColors.textSecondary;
      default:
        return const Color(0xFF9E9EAF);
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
        return const Color(0xFF5B3AA4);
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
        return const Color(0xFF044E5E);
    }
  }

  static Color get onSuccess {
    switch (_themeMode) {
      case 'AMOLED':
        return AmoledColors.onSuccess;
      case 'Light':
        return LightColors.onSuccess;
      case 'Creme':
        return CremeColors.onSuccess;
      default:
        return const Color(0xFF0A6B24);
    }
  }

  static Color get onDanger {
    switch (_themeMode) {
      case 'AMOLED':
        return AmoledColors.onDanger;
      case 'Light':
        return LightColors.onDanger;
      case 'Creme':
        return CremeColors.onDanger;
      default:
        return const Color(0xFFB71C1C);
    }
  }

  static Color get activeAccentPrimary {
    switch (_themeMode) {
      case 'Light':
      case 'Creme':
        return onAccentPrimary;
      default:
        return accentPrimary;
    }
  }

  static Color get activeAccentSecondary {
    switch (_themeMode) {
      case 'Light':
      case 'Creme':
        return onAccentSecondary;
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
    final opacity = _themeMode == 'Creme' ? 0.15 : 0.25;
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

/// AMOLED (pure black) theme colours
class AmoledColors {
  static const Color background = Colors.black;
  static const Color surface = Color(0xFF0C0C0C);
  static const Color surfaceHigh = Color(0xFF222222);

  // Softer but vivid accents for AMOLED
  static const Color accentPrimary = Color(0xFF9D5FF5); // brighter purple
  static const Color accentSecondary = Color(0xFF22D3EE); // high‑energy cyan

  static const Color success = Color(0xFF4ADE80);
  static const Color danger = Color(0xFFF87171);

  // On‑accent text colours (use same deeper shades as dark theme for readability)
  static const Color onAccentPrimary = Color(0xFF5B3AA4);
  static const Color onAccentSecondary = Color(0xFF044E5E);
  static const Color onSuccess = Color(0xFF0A6B24);
  static const Color onDanger = Color(0xFFB71C1C);

  // Gradient for AMOLED theme
  static const Gradient accentGradient = LinearGradient(
    colors: [accentPrimary, accentSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> glowShadow(Color color) {
    return PulseColors.glowShadow(color);
  }
}

/// Light theme colours – airy, soft, pastel
class LightColors {
  static const Color background = Color(0xFFF6F6FA); // very light gray
  static const Color surface = Colors.white;
  static const Color surfaceHigh = Color(0xFFE5E5EF);

  // Pastel accent colours as requested
  static const Color accentPrimary = Color(0xFFC4B5FD); // soft lavender
  static const Color accentSecondary = Color(0xFFA5F3FC); // pale sky cyan

  static const Color success = Color(0xFFBBF7D0); // mint green
  static const Color danger = Color(0xFFFECACA); // blush red

  // Deeper text colours to use on these pastel backgrounds for contrast
  static const Color onAccentPrimary = Color(0xFF7C3AED); // original purple for text
  static const Color onAccentSecondary = Color(0xFF06B6D4); // original cyan for text
  static const Color onSuccess = Color(0xFF22C55E);
  static const Color onDanger = Color(0xFFEF4444);

  // Light theme gradient using pastel accents
  static const Gradient accentGradient = LinearGradient(
    colors: [accentPrimary, accentSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> glowShadow(Color color) {
    return PulseColors.glowShadow(color);
  }
}

/// Creme (warm, rich ivory/espresso) theme colours
class CremeColors {
  static const Color background = Color(0xFFFAF5EC); // warm cream
  static const Color surface = Color(0xFFFFFDF9); // pure warm ivory
  static const Color surfaceHigh = Color(0xFFF3EAD8); // buttery cream
  
  static const Color accentPrimary = Color(0xFFB57C58); // warm cinnamon/caramel
  static const Color accentSecondary = Color(0xFF6B8068); // soft eucalyptus/sage green
  
  static const Color textPrimary = Color(0xFF2E251B); // deep roasted espresso brown
  static const Color textSecondary = Color(0xFF7A6F62); // soft latte/taupe brown

  static const Color success = Color(0xFF2E7D32); // forest success green
  static const Color danger = Color(0xFFC62828); // deep terracotta red

  static const Color onAccentPrimary = Color(0xFFFFFFFF);
  static const Color onAccentSecondary = Color(0xFFFFFFFF);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color onDanger = Color(0xFFFFFFFF);

  static const Gradient accentGradient = LinearGradient(
    colors: [accentPrimary, accentSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> glowShadow(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.15),
        blurRadius: 16,
        spreadRadius: -4,
        offset: const Offset(0, 8),
      ),
    ];
  }
}
