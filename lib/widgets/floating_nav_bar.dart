import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'interactive_elements.dart';

class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const FloatingNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'icon': Icons.movie_rounded, 'label': 'Videos'},
      {'icon': Icons.music_note_rounded, 'label': 'Music'},
      {'icon': Icons.folder_rounded, 'label': 'Folders'},
      {'icon': Icons.playlist_play_rounded, 'label': 'Playlists'},
      {'icon': Icons.settings_rounded, 'label': 'Settings'},
    ];

    final primary = PulseColors.accentPrimary;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: PulseColors.surfaceHigh.withValues(alpha: PulseColors.isLight ? 0.98 : 0.92),
            border: Border(
              top: BorderSide(
                color: PulseColors.isLight 
                    ? Colors.black.withValues(alpha: 0.08) 
                    : Colors.white.withValues(alpha: 0.08),
                width: 1.0,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: PulseColors.isLight ? 0.06 : 0.4),
                blurRadius: 16,
                offset: const Offset(0, -4),
              )
            ],
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SizedBox(
              height: 60,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(tabs.length, (index) {
                      final isSelected = currentIndex == index;
                      final tab = tabs[index];

                      return BouncingTap(
                        onTap: () => onTap(index),
                        scaleFactor: 0.90,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSelected ? 16 : 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      primary.withValues(alpha: PulseColors.isLight ? 0.18 : 0.25),
                                      PulseColors.accentSecondary.withValues(alpha: PulseColors.isLight ? 0.10 : 0.15),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            border: isSelected
                                ? Border.all(
                                    color: primary.withValues(alpha: PulseColors.isLight ? 0.35 : 0.4),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tab['icon'] as IconData,
                                color: isSelected ? primary : PulseColors.textSecondary,
                                size: 22,
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                Text(
                                  tab['label'] as String,
                                  style: PulseTypography.bodySmall.copyWith(
                                    color: PulseColors.isLight ? primary : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
