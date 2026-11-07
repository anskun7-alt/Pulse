import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/media_file.dart';
import '../models/playlist.dart';
import '../services/media_scanner.dart';
import '../services/playlist_service.dart';
import '../services/playback_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/video_thumbnail_widget.dart';
import '../widgets/action_toolbar.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/interactive_elements.dart';
import '../providers/selection_provider.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  final bool isSmart;
  final String? smartType;

  const PlaylistDetailScreen({
    Key? key,
    required this.playlist,
    required this.isSmart,
    this.smartType,
  }) : super(key: key);

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final _playlistService = PlaylistService.instance;
  final _scanner = MediaScanner.instance;
  List<MediaFile> _tracks = [];
  Playlist? _currentPlaylist;

  // Selection
  final SelectionProvider _selection = SelectionProvider();

  @override
  void initState() {
    super.initState();
    _currentPlaylist = widget.playlist;
    _loadTracks();
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _loadTracks() {
    final allFiles = _scanner.allFiles.value;
    final playlist = _currentPlaylist ?? widget.playlist;
    
    if (widget.isSmart) {
      switch (widget.smartType) {
        case 'Favorites':
          _tracks = _playlistService.getFavorites(allFiles);
          break;
        case 'Recently Played':
          _tracks = _playlistService.getRecentlyPlayed(allFiles);
          break;
        case 'Most Played':
          _tracks = _playlistService.getMostPlayed(allFiles);
          break;
        case 'Just Added':
          _tracks = _playlistService.getJustAdded(allFiles);
          break;
      }
    } else {
      final map = {for (var f in allFiles) _normalizePath(f.path): f};
      _tracks = playlist.mediaIds
          .map((id) => map[_normalizePath(id)])
          .whereType<MediaFile>()
          .toList();
    }
  }

  String _normalizePath(String path) {
    return path.replaceAll('\\', '/').toLowerCase();
  }

  Future<void> _pickCustomCover() async {
    if (widget.isSmart) return;
    final playlist = _currentPlaylist ?? widget.playlist;
    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        await _playlistService.updatePlaylistCover(playlist.id, path);
        setState(() {
          _currentPlaylist = playlist.copyWith(coverImagePath: path);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Playlist thumbnail updated!'), backgroundColor: PulseColors.success),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking playlist image: $e');
    }
  }

  void _playAll({bool shuffle = false}) {
    if (_tracks.isEmpty) return;
    final playback = PlaybackService.instance;
    final List<MediaFile> queue = List<MediaFile>.from(_tracks);
    
    // Set shuffle state
    playback.isShuffle.value = shuffle;
    if (shuffle) {
      queue.shuffle();
    }
    
    playback.playTrack(queue.first, newQueue: queue);
  }

  String _getPlaylistDuration() {
    final total = _tracks.fold<Duration>(Duration.zero, (prev, t) => prev + t.duration);
    if (total == Duration.zero) return '';
    final hrs = total.inHours;
    final mins = total.inMinutes.remainder(60);
    if (hrs > 0) {
      return ' · $hrs hr $mins min';
    }
    return ' · $mins min';
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildMosaicThumbnail(List<MediaFile> items, {String? coverImagePath}) {
    if (coverImagePath != null && File(coverImagePath).existsSync()) {
      return Image.file(
        File(coverImagePath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    final List<String> validArtPaths = [];
    for (var track in items) {
      if (track.albumArtPath != null && File(track.albumArtPath!).existsSync()) {
        validArtPaths.add(track.albumArtPath!);
      }
      if (validArtPaths.length >= 4) break;
    }

    if (validArtPaths.isEmpty) {
      return Container(
        color: PulseColors.surface,
        child: Icon(Icons.playlist_play_rounded, size: 80, color: PulseColors.accentPrimary),
      );
    }

    if (validArtPaths.length < 4) {
      return Image.file(File(validArtPaths.first), fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }

    return GridView.count(
      crossAxisCount: 2,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(4, (index) {
        return Image.file(
          File(validArtPaths[index]),
          fit: BoxFit.cover,
        );
      }),
    );
  }

  void _showMediaPickerSheet() {
    if (widget.isSmart) return;
    final playlist = _currentPlaylist ?? widget.playlist;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MediaPickerSheet(
        playlist: playlist,
        onAdded: () {
          setState(() {
            _loadTracks();
          });
        },
      ),
    );
  }

  void _showMenu(BuildContext context) {
    if (widget.isSmart) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: PulseColors.surfaceHigh.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: const Color(0xFF1E1E30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.add_circle_outline_rounded, color: PulseColors.accentSecondary),
                title: Text(
                  "Add Songs & Videos",
                  style: PulseTypography.bodyLarge.copyWith(
                    color: PulseColors.accentSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showMediaPickerSheet();
                },
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined, color: Colors.white),
                title: Text("Change Cover / Thumbnail", style: PulseTypography.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _pickCustomCover();
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Colors.white),
                title: Text("Rename Playlist", style: PulseTypography.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _showRenamePlaylistDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Colors.white),
                title: Text("Export as .m3u", style: PulseTypography.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _exportPlaylist();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: PulseColors.danger),
                title: Text("Delete Playlist", style: PulseTypography.bodyLarge.copyWith(color: PulseColors.danger)),
                onTap: () {
                  Navigator.pop(context);
                  _deletePlaylist();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showRenamePlaylistDialog() {
    final controller = TextEditingController(text: _currentPlaylist?.name ?? widget.playlist.name);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PulseColors.surfaceHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Rename Playlist", style: PulseTypography.displaySmall),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: PulseTypography.bodyLarge,
            decoration: InputDecoration(
              filled: true,
              fillColor: PulseColors.surface,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: PulseColors.accentSecondary),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E1E30)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final playlist = _currentPlaylist ?? widget.playlist;
                  await _playlistService.renamePlaylist(playlist.id, name);
                  Navigator.pop(context);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: PulseColors.accentSecondary),
              child: const Text("Save", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _exportPlaylist() async {
    final buffer = StringBuffer()..writeln("#EXTM3U");
    for (var track in _tracks) {
      buffer.writeln("#EXTINF:${track.duration.inSeconds},${track.artist} - ${track.title}");
      buffer.writeln(track.path);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Exported as .m3u successfully"),
        backgroundColor: PulseColors.success,
      ),
    );
  }

  void _deletePlaylist() async {
    final playlist = _currentPlaylist ?? widget.playlist;
    await _playlistService.deletePlaylist(playlist.id);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  // Bulk actions
  void _handleBulkAddToPlaylist() async {
    final selectedFiles = _tracks.where((t) => _selection.isSelected(t.path)).toList();
    if (selectedFiles.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddToPlaylistSheet.multiple(
        mediaFiles: selectedFiles,
        onAdded: (playlistId) {
          _selection.clear();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${selectedFiles.length} item(s) added to playlist'),
              backgroundColor: PulseColors.success,
            ));
          }
        },
      ),
    );
  }

  void _handleBulkRemove() async {
    final selectedFiles = _tracks.where((t) => _selection.isSelected(t.path)).toList();
    if (selectedFiles.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PulseColors.surface,
        title: Text('Remove from playlist?', style: PulseTypography.displayMedium),
        content: Text(
          'Remove ${selectedFiles.length} selected item(s) from this playlist?',
          style: PulseTypography.bodyLarge.copyWith(color: PulseColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: PulseTypography.bodyLarge),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: PulseColors.danger),
            child: Text('Remove', style: PulseTypography.bodyLarge.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final playlist = _currentPlaylist ?? widget.playlist;
    final remainingPaths = _tracks
        .where((t) => !_selection.isSelected(t.path))
        .map((t) => t.path)
        .toList();

    await _playlistService.updatePlaylistTracks(playlist.id, remainingPaths);
    _selection.clear();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Items removed from playlist'),
        backgroundColor: PulseColors.success,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<MediaFile>>(
      valueListenable: _scanner.allFiles,
      builder: (context, allFiles, child) {
        return ValueListenableBuilder<List<Playlist>>(
          valueListenable: _playlistService.playlists,
          builder: (context, playlists, child) {
            if (!widget.isSmart) {
              final updated = playlists.firstWhere(
                (p) => p.id == widget.playlist.id,
                orElse: () => _currentPlaylist ?? widget.playlist,
              );
              _currentPlaylist = updated;
            }
            _loadTracks();

            return AnimatedBuilder(
              animation: _selection,
              builder: (context, _) {
                final isSelectionMode = _selection.isActive;

                return Scaffold(
                  backgroundColor: PulseColors.background,
                  body: Stack(
                    children: [
                      CustomScrollView(
                        slivers: [
                          // Expanded Mosaic Header App Bar
                          SliverAppBar(
                            expandedHeight: 280,
                            pinned: true,
                            backgroundColor: PulseColors.background,
                            leading: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            actions: [
                              if (isSelectionMode)
                                IconButton(
                                  icon: const Icon(Icons.select_all_rounded, color: Colors.white),
                                  tooltip: 'Select all',
                                  onPressed: () => _selection.selectAll(_tracks.map((t) => t.path)),
                                ),
                              if (!widget.isSmart && !isSelectionMode) ...[
                                IconButton(
                                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                                  tooltip: 'Add songs & videos',
                                  onPressed: _showMediaPickerSheet,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert_rounded),
                                  onPressed: () => _showMenu(context),
                                ),
                              ],
                            ],
                            flexibleSpace: FlexibleSpaceBar(
                              background: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _buildMosaicThumbnail(
                                    _tracks,
                                    coverImagePath: _currentPlaylist?.coverImagePath ?? widget.playlist.coverImagePath,
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.transparent, PulseColors.background.withOpacity(0.95)],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              title: Text(
                                widget.isSmart ? widget.smartType! : (_currentPlaylist?.name ?? widget.playlist.name),
                                style: PulseTypography.displayMedium,
                              ),
                              centerTitle: false,
                              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                            ),
                          ),

                          // Metadata stats & Play/Shuffle Action buttons
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.isSmart
                                        ? "${_tracks.length} tracks${_getPlaylistDuration()} · Smart Playlist"
                                        : "${_tracks.length} tracks${_getPlaylistDuration()} · Custom Playlist",
                                    style: PulseTypography.bodyMedium.copyWith(color: Colors.white60),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildActionButtons(),
                                ],
                              ),
                            ),
                          ),

                          // Playlist Tracks Reorderable List
                          if (_tracks.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: PulseColors.surface,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.playlist_add_rounded,
                                          size: 40,
                                          color: PulseColors.accentSecondary.withValues(alpha: 0.8),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        "Playlist is Empty",
                                        style: PulseTypography.displaySmall,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        widget.isSmart
                                            ? "No items match this smart playlist."
                                            : "Add your favorite songs and videos to this playlist.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: PulseColors.textSecondary, fontSize: 14),
                                      ),
                                      if (!widget.isSmart) ...[
                                        const SizedBox(height: 24),
                                        ElevatedButton.icon(
                                          onPressed: _showMediaPickerSheet,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: PulseColors.accentSecondary,
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                          ),
                                          icon: const Icon(Icons.add_rounded, color: Colors.black),
                                          label: Text(
                                            "Add Songs & Videos",
                                            style: PulseTypography.bodyLarge.copyWith(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              sliver: SliverReorderableList(
                                itemCount: _tracks.length,
                                onReorder: (oldIndex, newIndex) async {
                                  if (widget.isSmart) return;
                                  setState(() {
                                    if (oldIndex < newIndex) {
                                      newIndex -= 1;
                                    }
                                    final item = _tracks.removeAt(oldIndex);
                                    _tracks.insert(newIndex, item);
                                  });
                                  
                                  // Save reordered list
                                  final playlist = _currentPlaylist ?? widget.playlist;
                                  await _playlistService.updatePlaylistTracks(
                                    playlist.id,
                                    _tracks.map((t) => t.path).toList(),
                                  );
                                },
                                itemBuilder: (context, index) {
                                  final track = _tracks[index];
                                  final isSelected = _selection.isSelected(track.path);
                                  return _buildTrackCard(
                                    context,
                                    index,
                                    track,
                                    isSelectionMode,
                                    isSelected,
                                  );
                                },
                              ),
                            ),
                          
                          // bottom margin spacer
                          SliverToBoxAdapter(
                            child: SizedBox(height: isSelectionMode ? 200 : 160),
                          )
                        ],
                      ),

                      // Bulk Action Toolbar
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ActionToolbar(
                          provider: _selection,
                          hasFloatingNavBar: false,
                          onAddToPlaylist: _handleBulkAddToPlaylist,
                          onMove: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Move: not supported for playlists'),
                            ));
                          },
                          onDelete: _handleBulkRemove,
                          onPlaySelected: () {
                            final selected = _tracks.where((t) => _selection.isSelected(t.path)).toList();
                            if (selected.isNotEmpty) {
                              _selection.clear();
                              PlaybackService.instance.playTrack(selected.first, newQueue: selected);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: PulseColors.accentGradient,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: PulseColors.accentPrimary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () => _playAll(shuffle: false),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          "Play All",
                          style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () => _playAll(shuffle: true),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shuffle_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Shuffle",
                          style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!widget.isSmart) ...[
              const SizedBox(width: 12),
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: PulseColors.accentSecondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: PulseColors.accentSecondary.withValues(alpha: 0.4), width: 1),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: _showMediaPickerSheet,
                    child: Icon(
                      Icons.add_rounded,
                      color: PulseColors.accentSecondary,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTrackCard(BuildContext context, int index, MediaFile track, bool isSelectionMode, bool isSelected) {
    final playbackService = PlaybackService.instance;
    return ValueListenableBuilder<MediaFile?>(
      key: Key('playlist_item_${track.path}'),
      valueListenable: playbackService.currentTrack,
      builder: (context, currentTrack, _) {
        final isCurrent = currentTrack != null &&
            currentTrack.path.replaceAll('\\', '/').toLowerCase() == track.path.replaceAll('\\', '/').toLowerCase();

        final card = Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrent 
                  ? PulseColors.accentSecondary.withOpacity(0.5) 
                  : (isSelected ? Colors.white38 : Colors.white.withOpacity(0.05)),
              width: isCurrent || isSelected ? 1.5 : 1,
            ),
            boxShadow: isCurrent ? [
              BoxShadow(
                color: PulseColors.accentSecondary.withOpacity(0.15),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ] : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: isSelected 
                    ? Colors.white.withOpacity(0.12)
                    : (isCurrent ? PulseColors.surfaceHigh.withOpacity(0.4) : PulseColors.surface.withOpacity(0.2)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: track.isVideo
                            ? VideoThumbnailWidget(
                                videoPath: track.path,
                                width: 52,
                                height: 52,
                              )
                            : (track.albumArtPath != null && File(track.albumArtPath!).existsSync()
                                ? Image.file(File(track.albumArtPath!), width: 52, height: 52, fit: BoxFit.cover)
                                : Container(
                                    width: 52,
                                    height: 52,
                                    color: PulseColors.surfaceHigh,
                                    child: Icon(Icons.music_note_rounded, color: PulseColors.accentPrimary, size: 24),
                                  )),
                      ),
                      if (isSelectionMode)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                              color: isSelected ? PulseColors.accentSecondary : Colors.white70,
                              size: 24,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PulseTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? PulseColors.accentSecondary : Colors.white,
                          ),
                        ),
                      ),
                      if (isCurrent)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: _PlayingIndicator(),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      track.isVideo ? 'Video' : track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PulseTypography.bodyMedium.copyWith(
                        color: isCurrent ? PulseColors.accentSecondary.withOpacity(0.8) : Colors.white60,
                      ),
                    ),
                  ),
                  trailing: widget.isSmart 
                      ? Text(
                          _formatDuration(track.duration),
                          style: PulseTypography.bodySmall.copyWith(color: Colors.white38),
                        )
                      : ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.drag_handle_rounded, color: Colors.white38),
                          ),
                        ),
                ),
              ),
            ),
          ),
        );

        return PulseQuickHold(
          onTap: () {
            if (isSelectionMode) {
              _selection.toggle(track.path);
            } else {
              if (track.isVideo) {
                final videoQueue = _tracks.where((t) => t.isVideo).toList();
                PlaybackService.instance.navigateToVideo(
                  videoQueue.isNotEmpty ? videoQueue : [track],
                  track,
                );
              } else {
                PlaybackService.instance.playTrack(track, newQueue: _tracks);
              }
            }
          },
          onHold: () {
            _selection.toggle(track.path);
          },
          child: card,
        );
      },
    );
  }
}

class _PlayingIndicator extends StatefulWidget {
  const _PlayingIndicator({Key? key}) : super(key: key);

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final double height = (sin((_controller.value * 2 * pi) + (index * 1.5)) + 1.0) / 2.0 * 12 + 4;
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: PulseColors.accentSecondary,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}

