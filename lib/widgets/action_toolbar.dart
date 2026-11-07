import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/media_file.dart';
import '../providers/selection_provider.dart';
import '../services/playback_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../theme/design_system.dart';
import 'interactive_elements.dart';

/// Ultra-slick, glassmorphic floating action toolbar that slides up smoothly
/// when items are selected. Adheres to Table of 4 design system tokens.
class ActionToolbar extends StatelessWidget {
  final SelectionProvider provider;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  final VoidCallback? onPlaySelected;
  final bool hasFloatingNavBar;

  const ActionToolbar({
    Key? key,
    required this.provider,
    required this.onAddToPlaylist,
    required this.onMove,
    required this.onDelete,
    this.onPlaySelected,
    this.hasFloatingNavBar = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        final visible = provider.isActive;
        return ValueListenableBuilder<MediaFile?>(
          valueListenable: PlaybackService.instance.currentTrack,
          builder: (context, currentTrack, _) {
            final bottomPadding = MediaQuery.of(context).padding.bottom;
            final isMiniPlayerVisible = currentTrack != null && !PlaybackService.instance.videoScreenOpen;
            final double bottomInset = hasFloatingNavBar
                ? (62.0 + bottomPadding + (isMiniPlayerVisible ? 76.0 : 0.0) + 12.0)
                : (12.0 + bottomPadding);

            return AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(0, 1.4),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: _ToolbarContent(
                    count: provider.count,
                    onAddToPlaylist: onAddToPlaylist,
                    onMove: onMove,
                    onDelete: onDelete,
                    onPlaySelected: onPlaySelected,
                    onCancel: () {
                      HapticFeedback.selectionClick();
                      provider.clear();
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ToolbarContent extends StatelessWidget {
  final int count;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  final VoidCallback? onPlaySelected;
  final VoidCallback onCancel;

  const _ToolbarContent({
    required this.count,
    required this.onAddToPlaylist,
    required this.onMove,
    required this.onDelete,
    this.onPlaySelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final accent = PulseColors.accentSecondary;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: PulseRadius.xxl,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 18,
                spreadRadius: -4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: PulseRadius.xxl,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: PulseColors.surfaceHigh.withValues(alpha: PulseColors.isLight ? 0.94 : 0.88),
                  borderRadius: PulseRadius.xxl,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Count indicator header strip
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        border: Border(
                          bottom: BorderSide(
                            color: accent.withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accent,
                                  boxShadow: PulseColors.glowShadow(accent),
                                ),
                                child: Center(
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$count item${count == 1 ? '' : 's'} selected',
                                style: PulseTypography.bodyMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          BouncingTap(
                            onTap: onCancel,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: PulseRadius.md,
                                border: Border.all(color: Colors.white24, width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.close_rounded, size: 14, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Cancel',
                                    style: PulseTypography.bodySmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action buttons row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (onPlaySelected != null)
                            _ActionBtn(
                              icon: Icons.play_arrow_rounded,
                              label: 'Play',
                              color: PulseColors.accentPrimary,
                              onTap: onPlaySelected!,
                            ),
                          _ActionBtn(
                            icon: Icons.playlist_add_rounded,
                            label: 'Playlist',
                            color: PulseColors.accentSecondary,
                            onTap: onAddToPlaylist,
                          ),
                          _ActionBtn(
                            icon: Icons.drive_file_move_outline,
                            label: 'Move',
                            color: Colors.white70,
                            onTap: onMove,
                          ),
                          _ActionBtn(
                            icon: Icons.delete_outline_rounded,
                            label: 'Delete',
                            color: PulseColors.danger,
                            onTap: onDelete,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncingTap(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: PulseRadius.md,
                border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: PulseTypography.bodySmall.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}