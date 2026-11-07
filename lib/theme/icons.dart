import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

enum IconPersonality {
  auto,
  modern,
  cyberpunk,
  western,
  comicBook,
  batman,
  deathNote,
  funky,
}

class PulseIcons {
  static IconPersonality get currentPersonality {
    final fontStyle = PulseTypography.fontStyleNotifier.value;
    if (fontStyle != 'Auto') {
      switch (fontStyle) {
        case 'Cyberpunk':
          return IconPersonality.cyberpunk;
        case 'Western':
          return IconPersonality.western;
        case 'Comic Book':
        case 'Spiderman':
          return IconPersonality.comicBook;
        case 'Batman':
          return IconPersonality.batman;
        case 'Death Note':
          return IconPersonality.deathNote;
        case 'Funky':
          return IconPersonality.funky;
        default:
          return IconPersonality.modern;
      }
    }

    final theme = PulseColors.themeNotifier.value;
    switch (theme) {
      case 'Cyberpunk':
        return IconPersonality.cyberpunk;
      case 'RDR2':
      case 'Red Dead':
        return IconPersonality.western;
      case 'Manga':
        return IconPersonality.deathNote;
      case 'Gamer':
        return IconPersonality.batman;
      case 'Anime':
        return IconPersonality.comicBook;
      default:
        return IconPersonality.modern;
    }
  }

  /// Returns a themed IconData variant tailored to the personality
  static IconData get playIcon {
    switch (currentPersonality) {
      case IconPersonality.cyberpunk:
        return Icons.play_arrow_outlined;
      case IconPersonality.western:
        return Icons.play_circle_filled_rounded;
      case IconPersonality.comicBook:
        return Icons.play_arrow_rounded;
      case IconPersonality.batman:
        return Icons.play_arrow_rounded;
      default:
        return Icons.play_arrow_rounded;
    }
  }

  static IconData get pauseIcon {
    switch (currentPersonality) {
      case IconPersonality.cyberpunk:
        return Icons.pause_outlined;
      default:
        return Icons.pause_rounded;
    }
  }

  static IconData get favoriteIcon {
    switch (currentPersonality) {
      case IconPersonality.cyberpunk:
        return Icons.bolt_rounded; // Cyber lightning heart
      case IconPersonality.western:
        return Icons.star_rounded; // Western Sheriff Star badge
      case IconPersonality.deathNote:
        return Icons.whatshot_rounded; // Gothic Flame
      case IconPersonality.batman:
        return Icons.shield_rounded; // Dark Knight Shield
      default:
        return Icons.favorite_rounded;
    }
  }

  static IconData get favoriteBorderIcon {
    switch (currentPersonality) {
      case IconPersonality.cyberpunk:
        return Icons.bolt_outlined;
      case IconPersonality.western:
        return Icons.star_border_rounded;
      case IconPersonality.deathNote:
        return Icons.whatshot_outlined;
      case IconPersonality.batman:
        return Icons.shield_outlined;
      default:
        return Icons.favorite_border_rounded;
    }
  }

  static IconData get videoIcon {
    switch (currentPersonality) {
      case IconPersonality.cyberpunk:
        return Icons.terminal_rounded;
      case IconPersonality.western:
        return Icons.movie_creation_outlined;
      default:
        return Icons.movie_rounded;
    }
  }

  static IconData get musicIcon {
    switch (currentPersonality) {
      case IconPersonality.cyberpunk:
        return Icons.graphic_eq_rounded;
      case IconPersonality.funky:
        return Icons.headphones_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }

  /// Wraps an icon with themed borders, glows, and shadow badge
  static Widget badge({
    required Widget child,
    double size = 44,
    Color? color,
  }) {
    final personality = currentPersonality;
    final accent = color ?? PulseColors.accentPrimary;

    switch (personality) {
      case IconPersonality.cyberpunk:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF14151F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.45),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(child: child),
        );

      case IconPersonality.comicBook:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.0),
            boxShadow: [
              const BoxShadow(
                color: Colors.black,
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Center(child: child),
        );

      case IconPersonality.western:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF241012),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD61A24), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD61A24).withValues(alpha: 0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(child: child),
        );

      case IconPersonality.batman:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF0F141F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF00E5FF), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                blurRadius: 8,
              ),
            ],
          ),
          child: Center(child: child),
        );

      case IconPersonality.deathNote:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF141418),
            borderRadius: BorderRadius.circular(size / 2),
            border: Border.all(color: const Color(0xFFFF2E63), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF2E63).withValues(alpha: 0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(child: child),
        );

      case IconPersonality.funky:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, PulseColors.accentSecondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(child: child),
        );

      default:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.0),
          ),
          child: Center(child: child),
        );
    }
  }
}
