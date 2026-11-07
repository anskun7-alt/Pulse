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
  bool _isTemporary = false;

  @override
  void dispose() {
    _playlistNameController.dispose();
    super.dispose();
  }

  void _createNewPlaylist() async {
    final name = _playlistNameController.text.trim();
    if (name.isEmpty) return;

    final newPlaylist = await PlaylistService.instance.createPlaylist(
      name,
      isTemporary: _isTemporary,
    );
    _playlistNameController.clear();
    setState(() {
      _isCreatingNew = false;
    });

    if (widget.onPlaylistCreated != null) {
      widget.onPlaylistCreated!(newPlaylist);
    } else {
      await PlaylistService.instance.addMultipleToPlaylist(
        newPlaylist.id,
        widget.mediaFiles.map((f) => f.path).toList(),
      );

      if (widget.onAdded != null) {
        widget.onAdded!(newPlaylist.id);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.mediaFiles.length == 1
                ? "${_isTemporary ? 'Temporary' : 'Permanent'} playlist '$name' created & added"
                : "${_isTemporary ? 'Temporary' : 'Permanent'} playlist '$name' created with ${widget.mediaFiles.length} item(s)"),
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
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          decoration: BoxDecoration(
            color: PulseColors.surfaceHigh.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: const Color(0xFF2C2C42).withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
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
                  style: PulseTypography.bodyLarge.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Enter playlist name...",
                    hintStyle: PulseTypography.bodyLarge.copyWith(color: Colors.white38),
                    filled: true,
                    fillColor: PulseColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: PulseColors.accentSecondary.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: PulseColors.accentSecondary),
                    ),
                  ),
                  onSubmitted: (_) => _createNewPlaylist(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isTemporary = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_isTemporary
                                ? PulseColors.accentPrimary.withValues(alpha: 0.2)
                                : PulseColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: !_isTemporary
                                  ? PulseColors.accentPrimary
                                  : Colors.white12,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.save_rounded,
                                size: 15,
                                color: !_isTemporary ? PulseColors.accentPrimary : Colors.white60,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Permanent",
                                style: TextStyle(
                                  color: !_isTemporary ? Colors.white : Colors.white60,
                                  fontWeight: !_isTemporary ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isTemporary = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _isTemporary
                                ? Colors.amber.withValues(alpha: 0.2)
                                : PulseColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isTemporary ? Colors.amber : Colors.white12,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 15,
                                color: _isTemporary ? Colors.amber : Colors.white60,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Temporary (Session)",
                                style: TextStyle(
                                  color: _isTemporary ? Colors.amber : Colors.white60,
                                  fontWeight: _isTemporary ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
                        "Create & Add",
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
                Flexible(
                  child: ValueListenableBuilder<List<Playlist>>(
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
                                color: Colors.white24,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "No playlists yet",
                                style: PulseTypography.displaySmall.copyWith(color: Colors.white60),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isCreatingNew = true;
                                  });
                                },
                                child: Text(
                                  "Create your first playlist",
                                  style: TextStyle(
                                    color: PulseColors.accentSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = playlists[index];
                          String norm(String p) => p.replaceAll('\\', '/').toLowerCase();
                          final playlistNormIds = playlist.mediaIds.map(norm).toSet();
                          final isAlreadyIn = widget.mediaFiles.length == 1
                              ? playlistNormIds.contains(norm(widget.mediaFiles.first.path))
                              : widget.mediaFiles.every((f) => playlistNormIds.contains(norm(f.path)));

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: PulseColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  playlist.isTemporary ? Icons.timer_outlined : Icons.queue_music_rounded,
                                  color: playlist.isTemporary
                                      ? Colors.amber
                                      : (isAlreadyIn ? PulseColors.success : PulseColors.accentPrimary),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      playlist.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (playlist.isTemporary) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 0.8),
                                      ),
                                      child: const Text(
                                        '⏳ Temp',
                                        style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                "${playlist.mediaIds.length} items",
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
                                          : "All selected items are already in playlist ${playlist.name}"),
                                      backgroundColor: PulseColors.surfaceHigh,
                                    ),
                                  );
                                } else {
                                  await PlaylistService.instance.addMultipleToPlaylist(
                                    playlist.id,
                                    widget.mediaFiles.map((f) => f.path).toList(),
                                  );

                                  if (widget.onAdded != null) {
                                    widget.onAdded!(playlist.id);
                                  }

                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(widget.mediaFiles.length == 1
                                            ? "Added to playlist ${playlist.name}"
                                            : "Added ${widget.mediaFiles.length} item(s) to playlist ${playlist.name}"),
                                        backgroundColor: PulseColors.success,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
