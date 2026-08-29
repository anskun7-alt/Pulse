import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import '../theme/colors.dart';

class ColorService {
  static final ColorService instance = ColorService._internal();
  ColorService._internal();

  final ValueNotifier<Color> activeAccent = ValueNotifier<Color>(PulseColors.accentPrimary);

  void reset() {
    activeAccent.value = PulseColors.accentPrimary;
  }

  Future<void> updateFromImage(ImageProvider imageProvider) async {
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 8,
      );
      
      // We seek a dominant color that has high vibrancy
      Color? targetColor = palette.vibrantColor?.color ?? 
                          palette.dominantColor?.color;

      if (targetColor != null) {
        // Boost saturation or make sure it's bright enough for dark theme
        final hsl = HSLColor.fromColor(targetColor);
        final adjustedHsl = hsl
            .withSaturation((hsl.saturation * 1.2).clamp(0.4, 1.0))
            .withLightness((hsl.lightness).clamp(0.4, 0.75));
        activeAccent.value = adjustedHsl.toColor();
      } else {
        reset();
      }
    } catch (e) {
      debugPrint("Error extracting palette: $e");
      reset();
    }
  }
}
