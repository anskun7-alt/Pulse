import 'package:flutter/material.dart';
import '../providers/selection_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Animated floating toolbar that slides up from the bottom when items are
/// selected. Exposes Add to Playlist, Move, Delete, and Cancel actions.
class ActionToolbar extends StatelessWidget {
  final SelectionProvider provider;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  const ActionToolbar({
    Key? key,
    required this.provider,
    required this.onAddToPlaylist,
    required this.onMove,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        final visible = provider.isActive;
        return AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: _ToolbarContent(
              count: provider.count,
              onAddToPlaylist: onAddToPlaylist,
              onMove: onMove,
              onDelete: onDelete,
              onCancel: provider.clear,
            ),
          ),
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
  final VoidCallback onCancel;

  const _ToolbarContent({
    required this.count,
    required this.onAddToPlaylist,
    required this.onMove,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: PulseColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E1E30), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Count indicator strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: PulseColors.accentSecondary.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Text(
              '$count item${count == 1 ? '' : 's'} selected',
              textAlign: TextAlign.center,
              style: PulseTypography.bodyMedium.copyWith(
                color: PulseColors.accentSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
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
                const Spacer(),
                // Cancel pill
                GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      'Cancel',
                      style: PulseTypography.bodyMedium.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: PulseTypography.bodySmall.copyWith(color: color, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}