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

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final primary = PulseColors.accentPrimary;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: bottomPadding > 0 ? bottomPadding : 16,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: PulseColors.surfaceHigh.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
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
                                    primary.withValues(alpha: 0.25),
                                    PulseColors.accentSecondary.withValues(alpha: 0.15),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          border: isSelected
                              ? Border.all(
                                  color: primary.withValues(alpha: 0.4),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tab['icon'] as IconData,
                              color: isSelected ? primary : Colors.white70,
                              size: 22,
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Text(
                                tab['label'] as String,
                                style: PulseTypography.bodySmall.copyWith(
                                  color: Colors.white,
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
    );
  }
}
