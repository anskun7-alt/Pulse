import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/avatar_service.dart';
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
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: PulseColors.surfaceHigh.withValues(alpha: PulseColors.isLight ? 0.96 : 0.88),
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
                color: Colors.black.withValues(alpha: PulseColors.isLight ? 0.06 : 0.45),
                blurRadius: 20,
                offset: const Offset(0, -4),
              )
            ],
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SizedBox(
              height: 62,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(tabs.length, (index) {
                      final isSelected = currentIndex == index;
                      final tab = tabs[index];

                      return BouncingTap(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onTap(index);
                        },
                        scaleFactor: 0.90,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSelected ? 16 : 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      primary.withValues(alpha: PulseColors.isLight ? 0.22 : 0.28),
                                      PulseColors.accentSecondary.withValues(alpha: PulseColors.isLight ? 0.12 : 0.18),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            border: isSelected
                                ? Border.all(
                                    color: primary.withValues(alpha: PulseColors.isLight ? 0.45 : 0.55),
                                    width: 1.2,
                                  )
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: primary.withValues(alpha: PulseColors.isLight ? 0.18 : 0.32),
                                      blurRadius: 14,
                                      spreadRadius: -2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (index == 4)
                                ValueListenableBuilder<AvatarItem>(
                                  valueListenable: AvatarService.instance.currentAvatar,
                                  builder: (context, avatar, _) {
                                    if (avatar.assetPath.isNotEmpty) {
                                      return Container(
                                        width: isSelected ? 24 : 22,
                                        height: isSelected ? 24 : 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? primary : Colors.white38,
                                            width: isSelected ? 1.5 : 1.0,
                                          ),
                                          image: DecorationImage(
                                            image: AssetImage(avatar.assetPath),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    }
                                    return Icon(
                                      tab['icon'] as IconData,
                                      color: isSelected ? primary : PulseColors.textSecondary,
                                      size: isSelected ? 23 : 21,
                                    );
                                  },
                                )
                              else
                                Icon(
                                  tab['icon'] as IconData,
                                  color: isSelected ? primary : PulseColors.textSecondary,
                                  size: isSelected ? 23 : 21,
                                ),
                              AnimatedCrossFade(
                                duration: const Duration(milliseconds: 240),
                                firstCurve: Curves.easeOutCubic,
                                secondCurve: Curves.easeInCubic,
                                crossFadeState: isSelected ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                                firstChild: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(width: 8),
                                    Text(
                                      tab['label'] as String,
                                      style: PulseTypography.bodySmall.copyWith(
                                        color: PulseColors.isLight ? primary : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                                secondChild: const SizedBox.shrink(),
                              ),
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
