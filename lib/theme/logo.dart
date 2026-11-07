import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'colors.dart';
import 'typography.dart';

class PulseLogo {
  static const String classic = 'classic';
  static const String rdr2 = 'rdr2';
  static const String auto = 'auto';

  static final ValueNotifier<String> logoStyleNotifier = ValueNotifier<String>(classic);

  static void init() {
    try {
      final box = Hive.box('settings_box');
      final saved = box.get('app_logo_style', defaultValue: classic) as String;
      logoStyleNotifier.value = saved;
    } catch (_) {}
  }

  static void setLogoStyle(String style) {
    logoStyleNotifier.value = style;
    try {
      final box = Hive.box('settings_box');
      box.put('app_logo_style', style);
    } catch (_) {}
  }

  static String get currentAssetPath {
    final style = logoStyleNotifier.value;
    if (style == rdr2) {
      return 'assets/rdr2_styled.webp';
    } else if (style == auto) {
      final currentTheme = PulseColors.themeNotifier.value;
      final currentFont = PulseTypography.fontStyleNotifier.value;
      if (currentTheme == 'RDR2' || currentFont == 'Western') {
        return 'assets/rdr2_styled.webp';
      }
      return 'assets/play-button.webp';
    }
    return 'assets/play-button.webp';
  }

  static String get currentTitle {
    final style = logoStyleNotifier.value;
    switch (style) {
      case rdr2:
        return '🤠 Red Dead Outlaw';
      case auto:
        return '✨ Auto (Adaptive)';
      case classic:
      default:
        return '⚡ Classic Pulse Neon';
    }
  }

  /// Builds a reactive, animated logo widget that updates dynamically when
  /// the user changes the logo preference inside the app.
  static Widget buildLogo({
    double size = 48,
    BoxFit fit = BoxFit.contain,
    BorderRadius? borderRadius,
    List<BoxShadow>? shadows,
  }) {
    return ValueListenableBuilder<String>(
      valueListenable: logoStyleNotifier,
      builder: (context, style, _) {
        final assetPath = currentAssetPath;
        Widget img = Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PulseColors.accentPrimary.withValues(alpha: 0.2),
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              size: size * 0.65,
              color: PulseColors.accentPrimary,
            ),
          ),
        );

        if (borderRadius != null) {
          img = ClipRRect(borderRadius: borderRadius, child: img);
        }

        if (shadows != null && shadows.isNotEmpty) {
          img = Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: shadows,
            ),
            child: img,
          );
        }

        return img;
      },
    );
  }
}
