import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/colors.dart';
import '../theme/typography.dart';

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
      {'icon': Icons.movie_outlined, 'label': 'Videos'},
      {'icon': Icons.music_note_outlined, 'label': 'Music'},
      {'icon': Icons.folder_open_outlined, 'label': 'Folders'},
      {'icon': Icons.playlist_play_rounded, 'label': 'Playlists'},
      {'icon': Icons.settings_outlined, 'label': 'Settings'},
    ];

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: bottomPadding > 0 ? bottomPadding : 16,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF12121E).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFF1E1E30).withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(tabs.length, (index) {
                final isSelected = currentIndex == index;
                final tab = tabs[index];

                return GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: isSelected
                          ? PulseColors.accentPrimary.withValues(alpha: 0.15)
                          : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated gradient icon for active tab
                        isSelected
                            ? ShaderMask(
                                shaderCallback: (bounds) => PulseColors.accentGradient.createShader(bounds),
                                child: Icon(
                                  tab['icon'] as IconData,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              )
                            : Icon(
                                tab['icon'] as IconData,
                                color: PulseColors.textSecondary,
                                size: 24,
                              ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: Text(
                              tab['label'] as String,
                              style: PulseTypography.bodySmall.copyWith(
                                color: PulseColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
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
    );
  }
}
