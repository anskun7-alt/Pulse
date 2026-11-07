import 'dart:ui';
import 'package:flutter/material.dart';
import 'colors.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PULSE DESIGN SYSTEM (Table-of-4 Rule)
/// ═══════════════════════════════════════════════════════════════════════════
/// Standardised design tokens built strictly upon the 4-point base grid:
/// every space, padding, margin, radius, and dimension is a multiple of 4.
/// ═══════════════════════════════════════════════════════════════════════════

class PulseSpacing {
  PulseSpacing._();

  static const double none = 0.0;
  static const double xxxs = 4.0;
  static const double xxs = 8.0;
  static const double xs = 12.0;
  static const double sm = 16.0;
  static const double md = 20.0;
  static const double lg = 24.0;
  static const double xl = 28.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double huge = 48.0;
  static const double massive = 64.0;

  // Box spacers for convenience
  static const Widget empty = SizedBox.shrink();
  static const Widget h4 = SizedBox(width: xxxs);
  static const Widget h8 = SizedBox(width: xxs);
  static const Widget h12 = SizedBox(width: xs);
  static const Widget h16 = SizedBox(width: sm);
  static const Widget h20 = SizedBox(width: md);
  static const Widget h24 = SizedBox(width: lg);
  static const Widget h32 = SizedBox(width: xxl);
  static const Widget h48 = SizedBox(width: huge);

  static const Widget v4 = SizedBox(height: xxxs);
  static const Widget v8 = SizedBox(height: xxs);
  static const Widget v12 = SizedBox(height: xs);
  static const Widget v16 = SizedBox(height: sm);
  static const Widget v20 = SizedBox(height: md);
  static const Widget v24 = SizedBox(height: lg);
  static const Widget v32 = SizedBox(height: xxl);
  static const Widget v40 = SizedBox(height: xxxl);
  static const Widget v48 = SizedBox(height: huge);
  static const Widget v64 = SizedBox(height: massive);
}

class PulseInsets {
  PulseInsets._();

  static const EdgeInsets zero = EdgeInsets.zero;

  // All sides
  static const EdgeInsets all4 = EdgeInsets.all(PulseSpacing.xxxs);
  static const EdgeInsets all8 = EdgeInsets.all(PulseSpacing.xxs);
  static const EdgeInsets all12 = EdgeInsets.all(PulseSpacing.xs);
  static const EdgeInsets all16 = EdgeInsets.all(PulseSpacing.sm);
  static const EdgeInsets all20 = EdgeInsets.all(PulseSpacing.md);
  static const EdgeInsets all24 = EdgeInsets.all(PulseSpacing.lg);
  static const EdgeInsets all32 = EdgeInsets.all(PulseSpacing.xxl);

  // Horizontal only
  static const EdgeInsets h4 = EdgeInsets.symmetric(horizontal: PulseSpacing.xxxs);
  static const EdgeInsets h8 = EdgeInsets.symmetric(horizontal: PulseSpacing.xxs);
  static const EdgeInsets h12 = EdgeInsets.symmetric(horizontal: PulseSpacing.xs);
  static const EdgeInsets h16 = EdgeInsets.symmetric(horizontal: PulseSpacing.sm);
  static const EdgeInsets h20 = EdgeInsets.symmetric(horizontal: PulseSpacing.md);
  static const EdgeInsets h24 = EdgeInsets.symmetric(horizontal: PulseSpacing.lg);
  static const EdgeInsets h32 = EdgeInsets.symmetric(horizontal: PulseSpacing.xxl);

  // Vertical only
  static const EdgeInsets v4 = EdgeInsets.symmetric(vertical: PulseSpacing.xxxs);
  static const EdgeInsets v8 = EdgeInsets.symmetric(vertical: PulseSpacing.xxs);
  static const EdgeInsets v12 = EdgeInsets.symmetric(vertical: PulseSpacing.xs);
  static const EdgeInsets v16 = EdgeInsets.symmetric(vertical: PulseSpacing.sm);
  static const EdgeInsets v20 = EdgeInsets.symmetric(vertical: PulseSpacing.md);
  static const EdgeInsets v24 = EdgeInsets.symmetric(vertical: PulseSpacing.lg);
  static const EdgeInsets v32 = EdgeInsets.symmetric(vertical: PulseSpacing.xxl);

  // Semantic Presets (Table of 4 aligned)
  static const EdgeInsets screen = EdgeInsets.symmetric(
    horizontal: PulseSpacing.sm, // 16
    vertical: PulseSpacing.xs,   // 12
  );

  static const EdgeInsets screenLoose = EdgeInsets.symmetric(
    horizontal: PulseSpacing.md, // 20
    vertical: PulseSpacing.sm,   // 16
  );

  static const EdgeInsets card = EdgeInsets.all(PulseSpacing.sm); // 16
  static const EdgeInsets cardCompact = EdgeInsets.all(PulseSpacing.xs); // 12
  static const EdgeInsets dialog = EdgeInsets.all(PulseSpacing.lg); // 24
  static const EdgeInsets bottomSheet = EdgeInsets.fromLTRB(
    PulseSpacing.lg, // 24
    PulseSpacing.md, // 20
    PulseSpacing.lg, // 24
    PulseSpacing.xxl, // 32
  );

  static const EdgeInsets button = EdgeInsets.symmetric(
    horizontal: PulseSpacing.md, // 20
    vertical: PulseSpacing.xs,   // 12
  );

  static const EdgeInsets buttonSm = EdgeInsets.symmetric(
    horizontal: PulseSpacing.xs, // 12
    vertical: PulseSpacing.xxs,  // 8
  );

  static const EdgeInsets chip = EdgeInsets.symmetric(
    horizontal: PulseSpacing.xs, // 12
    vertical: PulseSpacing.xxxs, // 4
  );
}

class PulseRadius {
  PulseRadius._();

  static const double r0 = 0.0;
  static const double r4 = 4.0;
  static const double r8 = 8.0;
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r20 = 20.0;
  static const double r24 = 24.0;
  static const double r32 = 32.0;
  static const double rFull = 9999.0;

  static const Radius rad4 = Radius.circular(r4);
  static const Radius rad8 = Radius.circular(r8);
  static const Radius rad12 = Radius.circular(r12);
  static const Radius rad16 = Radius.circular(r16);
  static const Radius rad20 = Radius.circular(r20);
  static const Radius rad24 = Radius.circular(r24);
  static const Radius rad32 = Radius.circular(r32);
  static const Radius radFull = Radius.circular(rFull);

  static const BorderRadius none = BorderRadius.zero;
  static const BorderRadius xs = BorderRadius.all(rad4);
  static const BorderRadius sm = BorderRadius.all(rad8);
  static const BorderRadius md = BorderRadius.all(rad12);
  static const BorderRadius lg = BorderRadius.all(rad16);
  static const BorderRadius xl = BorderRadius.all(rad20);
  static const BorderRadius xxl = BorderRadius.all(rad24);
  static const BorderRadius xxxl = BorderRadius.all(rad32);
  static const BorderRadius full = BorderRadius.all(radFull);
}

class PulseSizes {
  PulseSizes._();

  // Icons
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 40.0;
  static const double iconHero = 48.0;

  // Touch targets (WCAG accessibility standard)
  static const double minTouch = 48.0;

  // Buttons
  static const double buttonHeightSm = 32.0;
  static const double buttonHeightMd = 40.0;
  static const double buttonHeightLg = 48.0;
  static const double buttonHeightXl = 56.0;

  // Avatars / Profile Pictures
  static const double avatarXs = 24.0;
  static const double avatarSm = 32.0;
  static const double avatarMd = 44.0;
  static const double avatarLg = 56.0;
  static const double avatarXl = 72.0;
  static const double avatarHero = 96.0;

  // Component heights
  static const double topBarHeight = 64.0;
  static const double miniPlayerHeight = 68.0;
  static const double bottomNavHeight = 72.0;
  static const double inputHeight = 48.0;
  static const double inputHeightSm = 40.0;
}

class PulseShadows {
  PulseShadows._();

  static List<BoxShadow> subtle(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.08),
      blurRadius: PulseSpacing.xxs, // 8
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> card(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.12),
      blurRadius: PulseSpacing.sm, // 16
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> floating(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.20),
      blurRadius: PulseSpacing.lg, // 24
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: color.withValues(alpha: 0.10),
      blurRadius: PulseSpacing.xxs, // 8
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> glow(Color color, {double opacity = 0.35, double blur = 24.0}) => [
    BoxShadow(
      color: color.withValues(alpha: opacity),
      blurRadius: blur,
      spreadRadius: 2,
    ),
  ];
}

/// A reusable glassmorphic container styled in harmony with the 4-point design system
class PulseGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double blurAmount;

  const PulseGlassCard({
    Key? key,
    required this.child,
    this.padding = PulseInsets.card,
    this.margin = EdgeInsets.zero,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    this.blurAmount = 12.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? PulseRadius.lg;
    final surfaceColor = backgroundColor ?? PulseColors.surface.withValues(alpha: 0.75);
    final outlineColor = borderColor ?? PulseColors.surfaceHigh.withValues(alpha: 0.6);

    Widget content = ClipRRect(
      borderRadius: effectiveRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: effectiveRadius,
            border: Border.all(color: outlineColor, width: 1.0),
            boxShadow: PulseShadows.subtle(Colors.black),
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        child: InkWell(
          borderRadius: effectiveRadius,
          onTap: onTap,
          child: content,
        ),
      );
    }

    if (margin != EdgeInsets.zero) {
      content = Padding(padding: margin, child: content);
    }

    return content;
  }
}
