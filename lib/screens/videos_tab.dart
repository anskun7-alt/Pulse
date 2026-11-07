import 'dart:io';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:hive/hive.dart';
import '../models/media_file.dart';
import '../providers/selection_provider.dart';
import '../services/media_scanner.dart';
import '../services/playback_service.dart';
import '../theme/logo.dart';
import 'video_folder_screen.dart';
import '../widgets/media_card.dart';
import '../widgets/context_bottom_sheet.dart';
import '../widgets/action_toolbar.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/continue_playing_card.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/network_stream_dialog.dart';
import 'downloads_screen.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/view_mode_service.dart';

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
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Multi-select
  final SelectionProvider _selection = SelectionProvider();

  @override
  void initState() {
    super.initState();
    ViewModeService.instance.init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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

  Future<void> _requestPermissionsAndScan() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.videos,
        Permission.audio,
        Permission.storage,
        Permission.photos,
      ].request();
      if (statuses.values.any((s) => s.isGranted)) {
        await MediaScanner.instance.scan();
      } else {
        await openAppSettings();
      }
    } else {
      await MediaScanner.instance.scan();
    }
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
              content: Text(
                  '${selectedFiles.length} video${selectedFiles.length == 1 ? '' : 's'} added to playlist'),
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
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerSignal: (pointerSignal) {
                          if (pointerSignal is PointerScrollEvent && _scrollController.hasClients) {
                            final delta = pointerSignal.scrollDelta.dy * 2.5;
                            final newOffset = (_scrollController.offset + delta).clamp(
                              0.0,
                              _scrollController.position.maxScrollExtent,
                            );
                            _scrollController.jumpTo(newOffset);
                          }
                        },
                        child: ValueListenableBuilder<bool>(
                          valueListenable: ViewModeService.instance.isGrid,
                          builder: (context, isGrid, _) {
                            return CustomScrollView(
                              controller: _scrollController,
                              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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
                                              Row(
                                                children: [
                                                  PulseLogo.buildLogo(size: 32, borderRadius: BorderRadius.circular(16)),
                                                  const SizedBox(width: 10),
                                                  Text('Videos', style: PulseTypography.displayLarge),
                                                ],
                                              )
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
                                                        Icons.cloud_download_rounded,
                                                        color: Colors.white),
                                                    tooltip: 'Downloads & Link Downloader',
                                                    onPressed: () => Navigator.push(
                                                      context,
                                                      MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                                                    ),
                                                  ),
                                                if (!_isSearching && !isSelectionMode)
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.stream_rounded,
                                                        color: Colors.white),
                                                    tooltip: 'Open Network Stream (Ctrl+N)',
                                                    onPressed: () => NetworkStreamDialog.show(context),
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
                                                    isGrid
                                                        ? Icons.format_list_bulleted_rounded
                                                        : Icons.grid_view_rounded,
                                                    color: Colors.white,
                                                  ),
                                                  tooltip: isGrid ? 'Switch to List View' : 'Switch to Grid View',
                                                  onPressed: () => ViewModeService.instance.toggleViewMode(),
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

                                // ── Continue watching hero card ────────────────
                                const SliverToBoxAdapter(
                                  child: ContinuePlayingCard(),
                                ),

                                // ── Empty state ─────────────────────────────────
                                if (folders.isEmpty && allVideos.isEmpty)
                                  SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(32.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.video_library_rounded,
                                              size: 64,
                                              color: PulseColors.accentPrimary.withValues(alpha: 0.5),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              _searchQuery.isNotEmpty
                                                  ? 'No matching videos.'
                                                  : 'No videos found.',
                                              style: PulseTypography.displayMedium,
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              _searchQuery.isNotEmpty
                                                  ? 'Try searching with a different keyword.'
                                                  : 'Tap scan below or add custom folders.',
                                              style: PulseTypography.bodyMedium,
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 24),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 12,
                                              alignment: WrapAlignment.center,
                                              children: [
                                                ElevatedButton.icon(
                                                  onPressed: () => scanner.scan(),
                                                  icon: const Icon(Icons.refresh_rounded),
                                                  label: const Text('Scan Device'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: PulseColors.accentPrimary,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                  ),
                                                ),
                                                OutlinedButton.icon(
                                                  onPressed: () => MediaScanner.instance.pickAndAddCustomFolder(),
                                                  icon: const Icon(Icons.folder_open_rounded),
                                                  label: const Text('Add Video Folder'),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.white,
                                                    side: const BorderSide(color: Colors.white24),
                                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                else if (isGrid) ...[
                            // ── Grid: folders ──────────────────────────────
                            if (folders.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Folders',
                                          style: PulseTypography.displayMedium),
                                      Text(
                                        'View all',
                                        style: TextStyle(
                                          color: PulseColors.accentPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: MediaQuery.of(context).size.width >= 1400
                                        ? 4
                                        : (MediaQuery.of(context).size.width >= 900
                                            ? 3
                                            : (MediaQuery.of(context).size.width >= 600 ? 2 : 2)),
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 1.5,
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
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: MediaQuery.of(context).size.width >= 1600
                                        ? 6
                                        : (MediaQuery.of(context).size.width >= 1200
                                            ? 5
                                            : (MediaQuery.of(context).size.width >= 900
                                                ? 4
                                                : (MediaQuery.of(context).size.width >= 600 ? 3 : 2))),
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.84,
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
                                            PlaybackService.instance.navigateToVideo(allVideos, video);
                                          }
                                        },
                                        onLongPress: () =>
                                            _selection.toggle(video.path),
                                      )
                                          .animate()
                                          .fadeIn(duration: 220.ms, delay: (min(index, 8) * 30).ms)
                                          .slideY(begin: 0.08, end: 0, duration: 220.ms, curve: Curves.easeOutCubic);
                                    },
                                    childCount: allVideos.length,
                                  ),
                                ),
                              ),
                            ],
                          ] else ...[
                            // ── List: folders ──────────────────────────────
                            if (folders.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Folders', style: PulseTypography.displayMedium),
                                      Text(
                                        '${folders.length} Folders',
                                        style: TextStyle(
                                          color: PulseColors.accentPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        14),
                                              ),
                                              child: const Icon(
                                                  Icons.folder_rounded,
                                                  color: Colors.white,
                                                  size: 24),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  Text(folder.name,
                                                      style: PulseTypography
                                                          .bodyLarge),
                                                  const SizedBox(height: 2),
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
                            ],

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
                                            PlaybackService.instance.navigateToVideo(allVideos, video);
                                          }
                                        },
                                        onLongPress: () =>
                                            _selection.toggle(video.path),
                                      )
                                          .animate()
                                          .fadeIn(duration: 220.ms, delay: (min(index, 8) * 30).ms)
                                          .slideY(begin: 0.08, end: 0, duration: 220.ms, curve: Curves.easeOutCubic);
                                    },
                                    childCount: allVideos.length,
                                  ),
                                ),
                              ),
                          ],

                          // Empty state if nothing found
                          if (allVideos.isEmpty && folders.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: PulseEmptyState(
                                icon: Icons.video_library_rounded,
                                title: _searchQuery.isNotEmpty
                                    ? 'No videos match "$_searchQuery"'
                                    : 'No Videos Found',
                                subtitle: _searchQuery.isNotEmpty
                                    ? 'Try searching with a different keyword'
                                    : 'Scan your device or add videos to start watching.',
                                action: _searchQuery.isEmpty
                                    ? ElevatedButton.icon(
                                        onPressed: () => scanner.scan(),
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: const Text('Scan Media'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: PulseColors.accentPrimary,
                                          foregroundColor: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                            ),

                          // Bottom padding
                          SliverToBoxAdapter(
                            child: SizedBox(
                                height: isSelectionMode ? 200 : 160),
                          ),
                        ],
                      );
                    },
                  ),
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
                        onPlaySelected: () {
                          final selectedVideos = allVideos.where((v) => _selection.isSelected(v.path)).toList();
                          if (selectedVideos.isNotEmpty) {
                            _selection.clear();
                            PlaybackService.instance.navigateToVideo(allVideos, selectedVideos.first);
                          }
                        },
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
  final VoidCallback? onMore;
  const _FolderCard({required this.folder, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PulseColors.surfaceHigh.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.folder_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              if (onMore != null)
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.white54),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onMore,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${folder.videos.length}',
                    style: const TextStyle(
                      color: Color(0xFFA78BFA),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PulseTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${folder.videos.length} ${folder.videos.length == 1 ? "video" : "videos"}',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: PulseColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}