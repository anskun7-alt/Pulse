import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'rename_dialog.dart';
import 'tag_editor_sheet.dart';
import 'add_to_playlist_sheet.dart';
import '../services/media_scanner.dart';
import '../services/playback_service.dart';
import '../services/playlist_service.dart';
import 'package:hive/hive.dart';

class ContextBottomSheet extends StatelessWidget {
  final MediaFile file;

  const ContextBottomSheet({
    Key? key,
    required this.file,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: PulseColors.surfaceHigh.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: const Color(0xFF2C2C42).withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PulseColors.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Track Header Information
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: file.albumArtPath != null && File(file.albumArtPath!).existsSync()
                          ? Image.file(
                              File(file.albumArtPath!),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              color: PulseColors.surface,
                              child: Icon(
                                file.isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
                                color: file.isVideo ? PulseColors.accentSecondary : PulseColors.accentPrimary,
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PulseTypography.displaySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            file.isVideo
                                ? '${file.resolution ?? "1080p"} · ${file.sizeString}'
                                : '${file.artist} · ${file.album} · ${file.sizeString}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PulseTypography.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF2C2C42), height: 1),
              
              // Actions list
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildActionTile(
                      icon: Icons.play_arrow_rounded,
                      title: "Play now",
                      onTap: () {
                        Navigator.pop(context);
                        if (file.isVideo) {
                          // Trigger video player
                        } else {
                          PlaybackService.instance.playTrack(file);
                        }
                      },
                    ),
                    if (!file.isVideo)
                      _buildActionTile(
                        icon: Icons.queue_music_rounded,
                        title: "Play next in queue",
                        onTap: () {
                          Navigator.pop(context);
                          final currentQ = List<MediaFile>.from(PlaybackService.instance.queue.value);
                          currentQ.insert(PlaybackService.instance.queueIndex.value + 1, file);
                          PlaybackService.instance.queue.value = currentQ;
                        },
                      ),
                    _buildActionTile(
                      icon: Icons.edit_rounded,
                      title: file.isVideo ? "Rename" : "Edit tags",
                      onTap: () {
                        Navigator.pop(context);
                        if (file.isVideo) {
                          _showRenameDialog(context);
                        } else {
                          _showTagEditorSheet(context);
                        }
                      },
                    ),
                    _buildActionTile(
                      icon: Icons.add_rounded,
                      title: "Add to playlist",
                      onTap: () {
                        Navigator.pop(context);
                        _showAddToPlaylistSheet(context);
                      },
                    ),
                    _buildActionTile(
                      icon: Icons.favorite_border_rounded,
                      title: file.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                      onTap: () async {
                        Navigator.pop(context);
                        final box = await Hive.openBox('media_files_box');
                        await PlaylistService.instance.toggleFavorite(file, box);
                      },
                    ),
                    _buildActionTile(
                      icon: Icons.info_outline_rounded,
                      title: "Details",
                      onTap: () {
                        Navigator.pop(context);
                        _showDetailsDialog(context);
                      },
                    ),
                    _buildActionTile(
                      icon: Icons.delete_outline_rounded,
                      title: "Delete",
                      color: PulseColors.danger,
                      onTap: () {
                        Navigator.pop(context);
                        _confirmDelete(context);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? PulseColors.textPrimary),
      title: Text(
        title,
        style: PulseTypography.bodyLarge.copyWith(color: color ?? PulseColors.textPrimary),
      ),
      onTap: onTap,
    );
  }

  void _showRenameDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => RenameDialog(file: file),
    );
  }

  void _showTagEditorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagEditorSheet(file: file),
    );
  }

  void _showAddToPlaylistSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddToPlaylistSheet(mediaFile: file),
    );
  }

  void _showDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PulseColors.surfaceHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("File Details", style: PulseTypography.displaySmall),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow("Name", file.title),
              _detailRow("Artist", file.artist),
              _detailRow("Album", file.album),
              _detailRow("Path", file.path),
              _detailRow("Size", file.sizeString),
              _detailRow("Duration", file.durationString),
              if (file.bitrate != null) _detailRow("Bitrate", "${(file.bitrate! / 1000).round()} kbps"),
              if (file.resolution != null) _detailRow("Resolution", file.resolution!),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close", style: TextStyle(color: PulseColors.accentPrimary)),
            )
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          text: "$label: ",
          style: PulseTypography.monoLabel.copyWith(color: PulseColors.textSecondary, fontWeight: FontWeight.bold),
          children: [
            TextSpan(
              text: value,
              style: PulseTypography.monoLabel.copyWith(color: PulseColors.textPrimary),
            )
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PulseColors.surfaceHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Delete File", style: PulseTypography.displaySmall),
          content: Text(
            "Are you sure you want to permanently delete '${file.title}' from your device storage?",
            style: PulseTypography.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await MediaScanner.instance.deleteMediaFile(file);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("File deleted successfully"),
                    backgroundColor: PulseColors.danger,
                  ),
                );
              },
              child: Text("Delete", style: TextStyle(color: PulseColors.danger)),
            )
          ],
        );
      },
    );
  }
}
