import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:hive/hive.dart';
import '../models/media_file.dart';
import '../providers/selection_provider.dart';
import '../services/media_scanner.dart';
import '../services/playlist_service.dart';
import 'video_folder_screen.dart';
import '../widgets/media_card.dart';
import '../widgets/context_bottom_sheet.dart';
import '../widgets/action_toolbar.dart';
import '../players/video_player_screen.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class VideoFolder {
  final String path;
  final String name;
  final List<MediaFile> videos;

  VideoFolder({required this.path, required this.name, required this.videos});
}

class VideosTab extends StatefulWidget {
  const VideosTab({Key? key}) : super(key: key);

  @override
  State<VideosTab> createState() => _VideosTabState();
}

class _VideosTabState extends State<VideosTab> {
  bool _isGrid = false;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Multi-select
  final SelectionProvider _selection = SelectionProvider();

  @override
  void dispose() {
    _searchController.dispose();
    _selection.dispose();
    super.dispose();
  }

  final Set<String> _probingPaths = {};

  void _lazyProbeVideoDuration(MediaFile video) {
    if (video.duration > Duration.zero || _probingPaths.contains(video.path)) {
      return;
    }
    _probingPaths.add(video.path);

    Future(() async {
      try {
        final file = File(video.path);
        if (await file.exists()) {
          final metadata = await MetadataRetriever.fromFile(file);
          final durationMs = metadata.trackDuration;
          if (durationMs != null && durationMs > 0) {
            final dur = Duration(milliseconds: durationMs);
            final updatedVideo = video.copyWith(duration: dur);

            // Update in Hive box
            final box = Hive.box('media_files_box');
            if (box.isOpen) {
              await box.put(video.path, updatedVideo.toMap());
            }

            // Update in MediaScanner.instance.allFiles
            final scannerFiles = List<MediaFile>.from(MediaScanner.instance.allFiles.value);
            final idx = scannerFiles.indexWhere((f) => f.path == video.path);
            if (idx != -1) {
              scannerFiles[idx] = updatedVideo;
              MediaScanner.instance.allFiles.value = scannerFiles;
            }
          }
        }
      } catch (e) {
        debugPrint('Lazy video duration probe failed for ${video.path}: $e');
      } finally {
        _probingPaths.remove(video.path);
      }
    });
  }

  List<VideoFolder> _getFolders(List<MediaFile> files) {
    var videos = files.where((f) => f.isVideo).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      videos = videos
          .where((f) => f.title.toLowerCase().contains(query))
          .toList();
    }

    final Map<String, List<MediaFile>> folderMap = {};
    for (final v in videos) {
      final path = v.path;
      final separator = path.contains('/') ? '/' : '\\';
      final parts = path.split(separator);
      final parentPath = parts.length > 1
          ? parts.sublist(0, parts.length - 1).join(separator)
          : 'Videos';
      folderMap.putIfAbsent(parentPath, () => []).add(v);
    }

    final folders = folderMap.entries.map((e) {
      final name = e.key.split(e.key.contains('/') ? '/' : '\\').last;
      return VideoFolder(path: e.key, name: name, videos: e.value);
    }).toList();

    folders.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return folders;
  }



  void _showContextSheet(BuildContext context, MediaFile file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ContextBottomSheet(file: file),
    );
  }

  // ── Bulk action handlers ─────────────────────────────────────────────────

  void _handleAddToPlaylist(List<MediaFile> allVideos) async {
    final selectedFiles = allVideos
        .where((f) => _selection.isSelected(f.path))
        .toList();
    if (selectedFiles.isEmpty) return;

    final playlists = PlaylistService.instance.playlists.value;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddToPlaylistSheet(
        playlists: playlists,
        onChosen: (playlistId) async {
          for (final file in selectedFiles) {
            await PlaylistService.instance
                .addToPlaylist(playlistId, file.path);
          }
          _selection.clear();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${selectedFiles.length} video${selectedFiles.length == 1 ? '' : 's'} added to playlist'),
              backgroundColor: PulseColors.success,
            ));
          }
        },
        onCreateNew: (name) async {
          final pl =
              await PlaylistService.instance.createPlaylist(name);
          for (final file in selectedFiles) {
            await PlaylistService.instance
                .addToPlaylist(pl.id, file.path);
          }
          _selection.clear();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${selectedFiles.length} video${selectedFiles.length == 1 ? '' : 's'} added to "$name"'),
              backgroundColor: PulseColors.success,
            ));
          }
        },
      ),
    );
  }

  void _handleMove() {
    // Placeholder – wire up to a folder-picker screen as needed.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Move: coming soon'),
    ));
  }

  void _handleDelete(List<MediaFile> allVideos) async {
    final selectedFiles = allVideos
        .where((f) => _selection.isSelected(f.path))
        .toList();
    if (selectedFiles.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PulseColors.surface,
        title: Text('Delete ${selectedFiles.length} file${selectedFiles.length == 1 ? '' : 's'}?',
            style: PulseTypography.displayMedium),
        content: Text(
          'This will permanently remove the selected files from your device.',
          style:
              PulseTypography.bodyLarge.copyWith(color: PulseColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: PulseTypography.bodyLarge)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: PulseColors.danger),
            child: Text('Delete',
                style: PulseTypography.bodyLarge
                    .copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final file in selectedFiles) {
      try {
        await File(file.path).delete();
      } catch (_) {}
    }
    // Trigger a re-scan so the deleted files disappear from the list.
    await MediaScanner.instance.scan();
    _selection.clear();
  }

  // ────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scanner = MediaScanner.instance;

    return Scaffold(
      backgroundColor: PulseColors.background,
      body: SafeArea(
        child: ValueListenableBuilder<List<MediaFile>>(
          valueListenable: scanner.allFiles,
          builder: (context, files, child) {
            final folders = _getFolders(files);
            var allVideos = files.where((f) => f.isVideo).toList();
            if (_searchQuery.trim().isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              allVideos = allVideos
                  .where((v) => v.title.toLowerCase().contains(query))
                  .toList();
            }
            allVideos.sort((a, b) => b.addedDate.compareTo(a.addedDate));

            return AnimatedBuilder(
              animation: _selection,
              builder: (context, _) {
                final isSelectionMode = _selection.isActive;

                return Stack(
                  children: [
                    RefreshIndicator(
                      color: PulseColors.accentSecondary,
                      backgroundColor: PulseColors.surface,
                      onRefresh: () => scanner.scan(),
                      child: CustomScrollView(
                        slivers: [
                          // ── Header ──────────────────────────────────────
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  left: 20,
                                  right: 20,
                                  top: 20,
                                  bottom: 10),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Title / search field
                                      if (!_isSearching)
                                        Text('Videos',
                                            style:
                                                PulseTypography.displayLarge)
                                      else
                                        Expanded(
                                          child: TextField(
                                            controller: _searchController,
                                            autofocus: true,
                                            style:
                                                PulseTypography.bodyLarge,
                                            onChanged: (val) => setState(
                                                () => _searchQuery = val),
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Search video files...',
                                              hintStyle: PulseTypography
                                                  .bodyMedium,
                                              prefixIcon: Icon(
                                                  Icons.search,
                                                  color: PulseColors
                                                      .textSecondary),
                                              suffixIcon: IconButton(
                                                icon: Icon(Icons.clear,
                                                    color: PulseColors
                                                        .textSecondary),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  setState(() {
                                                    _searchQuery = '';
                                                    _isSearching = false;
                                                  });
                                                },
                                              ),
                                              border: InputBorder.none,
                                            ),
                                          ),
                                        ),

                                      Row(
                                        children: [
                                          // Select All button (visible in selection mode)
                                          if (isSelectionMode)
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.select_all_rounded,
                                                  color: Colors.white),
                                              tooltip: 'Select all',
                                              onPressed: () =>
                                                  _selection.selectAll(
                                                      allVideos.map(
                                                          (f) => f.path)),
                                            ),
                                          if (!_isSearching && !isSelectionMode)
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.search_rounded,
                                                  color: Colors.white),
                                              onPressed: () => setState(
                                                  () => _isSearching =
                                                      true),
                                            ),
                                          IconButton(
                                            icon: Icon(
                                              _isGrid
                                                  ? Icons
                                                      .format_list_bulleted_rounded
                                                  : Icons.grid_view_rounded,
                                              color: Colors.white,
                                            ),
                                            onPressed: () => setState(
                                                () => _isGrid = !_isGrid),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (!_isSearching) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${folders.length} folders · ${allVideos.length} videos',
                                      style: PulseTypography.bodyMedium,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // ── Empty state ─────────────────────────────────
                          if (folders.isEmpty && allVideos.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No matching videos.'
                                      : 'No videos discovered.',
                                  style: PulseTypography.bodyLarge,
                                ),
                              ),
                            )
                          else if (_isGrid) ...[
                            // ── Grid: folders ──────────────────────────────
                            if (folders.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  child: Text('Folders',
                                      style:
                                          PulseTypography.displayMedium),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 1.4,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final folder = folders[index];
                                      return GestureDetector(
                                        onTap: () => Navigator.of(context)
                                            .push(MaterialPageRoute(
                                          builder: (_) =>
                                              VideoFolderScreen(
                                            folderName: folder.name,
                                            videos: folder.videos,
                                            selectionProvider: _selection,
                                          ),
                                        )),
                                        child: _FolderCard(
                                            folder: folder),
                                      );
                                    },
                                    childCount: folders.length,
                                  ),
                                ),
                              ),
                            ],

                            // ── Grid: videos ───────────────────────────────
                            if (allVideos.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      left: 20,
                                      right: 20,
                                      top: 30,
                                      bottom: 15),
                                  child: Text('Videos',
                                      style:
                                          PulseTypography.displayMedium),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.82,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final video = allVideos[index];
                                      if (video.duration == Duration.zero) {
                                        _lazyProbeVideoDuration(video);
                                      }
                                      return MediaCard(
                                        file: video,
                                        isGrid: true,
                                        isSelectionMode: isSelectionMode,
                                        isSelected: _selection
                                            .isSelected(video.path),
                                        onTap: () {
                                          if (isSelectionMode) {
                                            _selection.toggle(video.path);
                                          } else {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    VideoPlayerScreen(
                                                  file: video,
                                                  playlist: allVideos,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        onLongPress: () =>
                                            _selection.toggle(video.path),
                                      );
                                    },
                                    childCount: allVideos.length,
                                  ),
                                ),
                              ),
                            ],
                          ] else ...[
                            // ── List: folders ──────────────────────────────
                            if (folders.isNotEmpty)
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final folder = folders[index];
                                    return InkWell(
                                      onTap: () =>
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  VideoFolderScreen(
                                                folderName: folder.name,
                                                videos: folder.videos,
                                                selectionProvider: _selection,
                                              ),
                                            ),
                                          ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 10),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                        0xFFE5E5EF)
                                                    .withOpacity(0.08),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        10),
                                              ),
                                              child: const Icon(
                                                  Icons.folder_rounded,
                                                  size: 28,
                                                  color: Colors.grey),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  Text(folder.name,
                                                      style: PulseTypography
                                                          .bodyLarge
                                                          .copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                      '${folder.videos.length} Items',
                                                      style: PulseTypography
                                                          .bodyMedium),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  childCount: folders.length,
                                ),
                              ),

                            // ── List: videos header ─────────────────────────
                            if (allVideos.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      left: 20,
                                      right: 20,
                                      top: 25,
                                      bottom: 10),
                                  child: Text('Videos',
                                      style:
                                          PulseTypography.displayMedium),
                                ),
                              ),

                            // ── List: videos ────────────────────────────────
                            if (allVideos.isNotEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final video = allVideos[index];
                                      if (video.duration == Duration.zero) {
                                        _lazyProbeVideoDuration(video);
                                      }
                                      return MediaCard(
                                        file: video,
                                        isGrid: false,
                                        isSelectionMode: isSelectionMode,
                                        isSelected: _selection
                                            .isSelected(video.path),
                                        onTap: () {
                                          if (isSelectionMode) {
                                            _selection.toggle(video.path);
                                          } else {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    VideoPlayerScreen(
                                                  file: video,
                                                  playlist: allVideos,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        onLongPress: () =>
                                            _selection.toggle(video.path),
                                      );
                                    },
                                    childCount: allVideos.length,
                                  ),
                                ),
                              ),
                          ],

                          // Bottom padding
                          SliverToBoxAdapter(
                            child: SizedBox(
                                height: isSelectionMode ? 200 : 160),
                          ),
                        ],
                      ),
                    ),

                    // ── Floating action toolbar ──────────────────────────
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ActionToolbar(
                        provider: _selection,
                        onAddToPlaylist: () =>
                            _handleAddToPlaylist(allVideos),
                        onMove: _handleMove,
                        onDelete: () => _handleDelete(allVideos),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─── Folder card widget ───────────────────────────────────────────────────────
class _FolderCard extends StatelessWidget {
  final VideoFolder folder;
  const _FolderCard({required this.folder});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PulseColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E30), width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_rounded, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            folder.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PulseTypography.bodyLarge
                .copyWith(fontWeight: FontWeight.bold),
          ),
          Text('${folder.videos.length} Items',
              style: PulseTypography.bodySmall),
        ],
      ),
    );
  }
}

// ─── Add-to-playlist bottom sheet ────────────────────────────────────────────
class _AddToPlaylistSheet extends StatelessWidget {
  final List<dynamic> playlists; // List<Playlist>
  final Future<void> Function(String playlistId) onChosen;
  final Future<void> Function(String name) onCreateNew;

  const _AddToPlaylistSheet({
    required this.playlists,
    required this.onChosen,
    required this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PulseColors.surface.withOpacity(0.97),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Add to Playlist', style: PulseTypography.displayMedium),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          ...playlists.map((p) => ListTile(
                leading: const Icon(Icons.queue_music_rounded,
                    color: Colors.white70),
                title: Text(p.name, style: PulseTypography.bodyLarge),
                onTap: () async {
                  Navigator.pop(context);
                  await onChosen(p.id);
                },
              )),
          ListTile(
            leading: Icon(Icons.add_circle_outline_rounded,
                color: PulseColors.accentSecondary),
            title: Text('New playlist',
                style: PulseTypography.bodyLarge
                    .copyWith(color: PulseColors.accentSecondary)),
            onTap: () async {
              Navigator.pop(context);
              final ctrl = TextEditingController();
              final name = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: PulseColors.surface,
                  title: Text('New Playlist',
                      style: PulseTypography.displayMedium),
                  content: TextField(
                    controller: ctrl,
                    autofocus: true,
                    style: PulseTypography.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Playlist name',
                      hintStyle: PulseTypography.bodyMedium,
                    ),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Cancel',
                            style: PulseTypography.bodyLarge)),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(ctx, ctrl.text.trim()),
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              PulseColors.accentSecondary),
                      child: const Text('Create'),
                    ),
                  ],
                ),
              );
              if (name != null && name.isNotEmpty) {
                await onCreateNew(name);
              }
            },
          ),
        ],
      ),
    );
  }
}