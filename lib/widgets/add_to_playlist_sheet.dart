import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../models/playlist.dart';
import '../services/playlist_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class AddToPlaylistSheet extends StatefulWidget {
  final List<MediaFile> mediaFiles;
  final Function(Playlist)? onPlaylistCreated;
  final Function(String)? onAdded;

  // Single file constructor for backwards compatibility
  AddToPlaylistSheet({
    Key? key,
    required MediaFile mediaFile,
    this.onPlaylistCreated,
    this.onAdded,
  }) : mediaFiles = [mediaFile], super(key: key);

  // Multiple files constructor
  const AddToPlaylistSheet.multiple({
    Key? key,
    required this.mediaFiles,
    this.onPlaylistCreated,
    this.onAdded,
  }) : super(key: key);

  @override
  State<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<AddToPlaylistSheet> {
  final TextEditingController _playlistNameController = TextEditingController();
  bool _isCreatingNew = false;

  @override
  void dispose() {
    _playlistNameController.dispose();
    super.dispose();
  }

  void _createNewPlaylist() async {
    final name = _playlistNameController.text.trim();
    if (name.isEmpty) return;

    final newPlaylist = await PlaylistService.instance.createPlaylist(name);
    _playlistNameController.clear();
    setState(() {
      _isCreatingNew = false;
    });

    if (widget.onPlaylistCreated != null) {
      widget.onPlaylistCreated!(newPlaylist);
    } else {
      for (var file in widget.mediaFiles) {
        await PlaylistService.instance.addToPlaylist(newPlaylist.id, file.path);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.mediaFiles.length == 1
                ? "Created and added to playlist '$name'"
                : "Created and added ${widget.mediaFiles.length} songs to playlist '$name'"),
            backgroundColor: PulseColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: PulseColors.surfaceHigh.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: const Color(0xFF2C2C42).withOpacity(0.5),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PulseColors.textSecondary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Header / Mode switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isCreatingNew ? "Create Playlist" : "Add to Playlist",
                      style: PulseTypography.displayMedium,
                    ),
                    IconButton(
                      icon: Icon(
                        _isCreatingNew ? Icons.close_rounded : Icons.add_rounded,
                        color: PulseColors.accentSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _isCreatingNew = !_isCreatingNew;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: Color(0xFF2C2C42), height: 1),
                const SizedBox(height: 16),

                if (_isCreatingNew) ...[
                  // Inline Create Playlist Field
                  TextField(
                    controller: _playlistNameController,
                    autofocus: true,
                    style: PulseTypography.bodyLarge.copyWith(color: PulseColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Enter playlist name...",
                      hintStyle: PulseTypography.bodyLarge.copyWith(color: PulseColors.textSecondary.withOpacity(0.6)),
                      filled: true,
                      fillColor: PulseColors.surface.withOpacity(0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: PulseColors.accentSecondary.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: PulseColors.accentSecondary),
                      ),
                    ),
                    onSubmitted: (_) => _createNewPlaylist(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isCreatingNew = false;
                          });
                        },
                        child: Text("Cancel", style: TextStyle(color: PulseColors.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _createNewPlaylist,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PulseColors.accentSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: Text(
                          "Create",
                          style: PulseTypography.bodyLarge.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // List of existing Playlists
                  ValueListenableBuilder<List<Playlist>>(
                    valueListenable: PlaylistService.instance.playlists,
                    builder: (context, playlists, child) {
                      if (playlists.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.playlist_add_rounded,
                                size: 64,
                                color: PulseColors.textSecondary.withOpacity(0.3),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "No playlists yet",
                                style: PulseTypography.displaySmall.copyWith(color: PulseColors.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isCreatingNew = true;
                                  });
                                },
                                child: Text(
                                  "Create New Playlist",
                                  style: TextStyle(color: PulseColors.accentSecondary),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: playlists.length,
                          padding: const EdgeInsets.only(bottom: 24),
                          itemBuilder: (context, index) {
                            final playlist = playlists[index];
                            final isAlreadyIn = widget.mediaFiles.length == 1
                                ? playlist.mediaIds.contains(widget.mediaFiles.first.path)
                                : widget.mediaFiles.every((f) => playlist.mediaIds.contains(f.path));

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: PulseColors.surface.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.queue_music_rounded,
                                    color: isAlreadyIn ? PulseColors.success : PulseColors.accentPrimary,
                                  ),
                                ),
                                title: Text(
                                  playlist.name,
                                  style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  "${playlist.mediaIds.length} tracks",
                                  style: PulseTypography.bodyMedium.copyWith(color: PulseColors.textSecondary),
                                ),
                                trailing: (isAlreadyIn && widget.onAdded == null)
                                    ? Icon(Icons.check_circle_rounded, color: PulseColors.success)
                                    : Icon(Icons.add_circle_outline_rounded, color: PulseColors.textSecondary),
                                onTap: () async {
                                  if (isAlreadyIn && widget.onAdded == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(widget.mediaFiles.length == 1
                                            ? "Already in playlist ${playlist.name}"
                                            : "All selected tracks are already in playlist ${playlist.name}"),
                                        backgroundColor: PulseColors.surfaceHigh,
                                      ),
                                    );
                                  } else {
                                    if (widget.onAdded != null) {
                                      widget.onAdded!(playlist.id);
                                    } else {
                                      for (var file in widget.mediaFiles) {
                                        await PlaylistService.instance.addToPlaylist(playlist.id, file.path);
                                      }
                                      if (mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(widget.mediaFiles.length == 1
                                                ? "Added to playlist ${playlist.name}"
                                                : "Added ${widget.mediaFiles.length} songs to playlist ${playlist.name}"),
                                            backgroundColor: PulseColors.success,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
