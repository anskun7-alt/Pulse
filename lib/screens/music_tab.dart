import 'dart:io';
import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../services/media_scanner.dart';
import '../services/playlist_service.dart';
import '../widgets/media_card.dart';
import '../widgets/context_bottom_sheet.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../services/playback_service.dart';
import '../players/video_player_screen.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class MusicTab extends StatefulWidget {
  const MusicTab({Key? key}) : super(key: key);

  @override
  State<MusicTab> createState() => _MusicTabState();
}

class _MusicTabState extends State<MusicTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  // Selection mode state
  final ValueNotifier<bool> _isSelectionMode = ValueNotifier<bool>(false);
  final ValueNotifier<Set<MediaFile>> _selectedItems = ValueNotifier<Set<MediaFile>>({});
  bool _isSearching = false;

  void _handleTrackTap(MediaFile track, List<MediaFile> queue) {
    if (track.isVideo) {
      final videoQueue = queue.where((f) => f.isVideo).toList();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            file: track,
            playlist: videoQueue.isNotEmpty ? videoQueue : [track],
          ),
        ),
      );
    } else {
      PlaybackService.instance.playTrack(track, newQueue: queue);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<MediaFile> _getAudioTracks(List<MediaFile> allFiles) {
    var list = allFiles.where((f) => !f.isVideo).toList();
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((f) => f.title.toLowerCase().contains(q) || f.artist.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final scanner = MediaScanner.instance;
    final playbackService = PlaybackService.instance;

    return Scaffold(
      backgroundColor: PulseColors.background,
      body: SafeArea(
        child: ValueListenableBuilder<List<MediaFile>>(
          valueListenable: scanner.allFiles,
          builder: (context, allFiles, child) {
            final tracks = _getAudioTracks(allFiles);

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // Action bar for selection mode
                  SliverToBoxAdapter(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _isSelectionMode,
                      builder: (context, isSelectionMode, _) {
                        return isSelectionMode
                            ? Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.select_all, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        // Select all currently visible tracks
                                        _selectedItems.value = tracks.toSet();
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.playlist_add, color: Colors.white),
                                    onPressed: () {
                                      final selectedList = _selectedItems.value.toList();
                                      if (selectedList.isEmpty) return;

                                      showModalBottomSheet(
                                        context: context,
                                        backgroundColor: Colors.transparent,
                                        isScrollControlled: true,
                                        builder: (sheetCtx) => AddToPlaylistSheet.multiple(
                                          mediaFiles: selectedList,
                                          onAdded: (playlistId) async {
                                            for (var item in selectedList) {
                                              await PlaylistService.instance.addToPlaylist(playlistId, item.path);
                                            }
                                            _isSelectionMode.value = false;
                                            _selectedItems.value = {};
                                            Navigator.pop(sheetCtx);
                                            setState(() {});
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text("Added ${selectedList.length} songs to playlist"),
                                                backgroundColor: PulseColors.success,
                                              ),
                                            );
                                          },
                                          onPlaylistCreated: (newPlaylist) async {
                                            for (var item in selectedList) {
                                              await PlaylistService.instance.addToPlaylist(newPlaylist.id, item.path);
                                            }
                                            _isSelectionMode.value = false;
                                            _selectedItems.value = {};
                                            Navigator.pop(sheetCtx);
                                            setState(() {});
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text("Created playlist '${newPlaylist.name}' and added songs"),
                                                backgroundColor: PulseColors.success,
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        _isSelectionMode.value = false;
                                        _selectedItems.value = {};
                                      });
                                    },
                                  ),
                                ],
                              )
                            : const SizedBox.shrink();
                      },
                    ),
                  ),
                  // App Bar / Title Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!_isSearching)
                            Text("Music", style: PulseTypography.displayLarge)
                          else
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                style: PulseTypography.bodyLarge,
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val;
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: "Search tracks, artists...",
                                  hintStyle: PulseTypography.bodyMedium,
                                  prefixIcon: Icon(Icons.search, color: PulseColors.textSecondary),
                                  suffixIcon: IconButton(
                                    icon: Icon(Icons.clear, color: PulseColors.textSecondary),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = "";
                                        _isSearching = false;
                                      });
                                    },
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          if (!_isSearching)
                      Row(
                        children: [
                          // Play All
                          IconButton(
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                            onPressed: () {
                              playbackService.playAll(tracks, shuffle: false);
                            },
                          ),
                          // Shuffle
                          IconButton(
                            icon: const Icon(Icons.shuffle_rounded, color: Colors.white),
                            onPressed: () {
                              playbackService.playAll(tracks, shuffle: true);
                            },
                          ),
                          // Seek Backward 5s
                          IconButton(
                            icon: const Icon(Icons.replay_5_rounded, color: Colors.white),
                            onPressed: () {
                              playbackService.seekRelative(const Duration(seconds: -5));
                            },
                          ),
                          // Seek Forward 5s
                          IconButton(
                            icon: const Icon(Icons.forward_5_rounded, color: Colors.white),
                            onPressed: () {
                              playbackService.seekRelative(const Duration(seconds: 5));
                            },
                          ),
                          // Search
                          IconButton(
                            icon: const Icon(Icons.search_rounded, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _isSearching = true;
                              });
                            },
                          ),
                        ],
                      )
                        ],
                      ),
                    ),
                  ),

                  // Sub Tabs Indicator Floating Pill
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverTabHeaderDelegate(
                      tabBar: TabBar(
                        controller: _tabController,
                        indicatorColor: PulseColors.accentPrimary,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: PulseColors.textSecondary,
                        labelStyle: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                        unselectedLabelStyle: PulseTypography.bodyMedium,
                        indicatorSize: TabBarIndicatorSize.label,
                        tabs: const [
                          Tab(text: "Songs"),
                          Tab(text: "Albums"),
                          Tab(text: "Artists"),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: RefreshIndicator(
                color: PulseColors.accentPrimary,
                backgroundColor: PulseColors.surface,
                onRefresh: () => scanner.scan(),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSongsList(tracks, playbackService),
                    _buildAlbumsGrid(tracks),
                    _buildArtistsList(tracks),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSongsList(List<MediaFile> tracks, PlaybackService playbackService) {
    if (tracks.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty ? "No matching songs." : "No music files discovered.",
          style: PulseTypography.bodyLarge,
        ),
      );
    }

    return ValueListenableBuilder<MediaFile?>(
      valueListenable: playbackService.currentTrack,
      builder: (context, currentTrack, child) {
        return ListView.builder(
          itemCount: tracks.length,
          padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 168),
          itemBuilder: (context, index) {
            final track = tracks[index];
            final isPlayingThis = currentTrack?.path == track.path;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isPlayingThis 
                    ? PulseColors.accentPrimary.withValues(alpha: 0.08) 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPlayingThis 
                      ? PulseColors.accentPrimary.withValues(alpha: 0.3) 
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: MediaCard(
                file: track,
                isGrid: false,
          // Long press toggles selection mode
          onLongPress: () {
            if (!_isSelectionMode.value) {
              _isSelectionMode.value = true;
              _selectedItems.value = {track};
            } else {
              // Toggle selection
              if (_selectedItems.value.contains(track)) {
                _selectedItems.value.remove(track);
                if (_selectedItems.value.isEmpty) _isSelectionMode.value = false;
              } else {
                _selectedItems.value.add(track);
              }
              // Reassign to trigger ValueNotifier
              _selectedItems.value = Set.from(_selectedItems.value);
            }
            setState(() {});
          },
          // Tap behavior depends on selection mode
          onTap: () {
            if (_isSelectionMode.value) {
              // Toggle selection on tap
              if (_selectedItems.value.contains(track)) {
                _selectedItems.value.remove(track);
                if (_selectedItems.value.isEmpty) _isSelectionMode.value = false;
              } else {
                _selectedItems.value.add(track);
              }
              // Reassign to trigger ValueNotifier
              _selectedItems.value = Set.from(_selectedItems.value);
              setState(() {});
            } else {
              _handleTrackTap(track, tracks);
            }
          },
          // Pass selection flag to MediaCard
          isSelected: _isSelectionMode.value && _selectedItems.value.contains(track),

              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAlbumsGrid(List<MediaFile> tracks) {
    // Map tracks to albums
    final Map<String, List<MediaFile>> albumMap = {};
    for (var track in tracks) {
      final key = track.album;
      albumMap.putIfAbsent(key, () => []).add(track);
    }

    final albums = albumMap.keys.toList();

    if (albums.isEmpty) {
      return Center(child: Text("No albums available.", style: PulseTypography.bodyLarge));
    }

    return GridView.builder(
      itemCount: albums.length,
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 180),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        final albumName = albums[index];
        final albumTracks = albumMap[albumName]!;
        final firstTrack = albumTracks.first;

        return GestureDetector(
          onTap: () {
            // Filter by album and play
            PlaybackService.instance.playTrack(firstTrack, newQueue: albumTracks);
          },
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: PulseColors.glowShadow(PulseColors.accentPrimary),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: firstTrack.albumArtPath != null && firstTrack.albumArtPath!.isNotEmpty
                        ? Image.file(
                            File(firstTrack.albumArtPath!),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: PulseColors.surface,
                              width: double.infinity,
                              height: double.infinity,
                              child: Icon(Icons.album_rounded, size: 48, color: PulseColors.accentPrimary),
                            ),
                          )
                        : Container(
                            color: PulseColors.surface,
                            width: double.infinity,
                            height: double.infinity,
                            child: Icon(Icons.album_rounded, size: 48, color: PulseColors.accentPrimary),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                albumName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                "${albumTracks.length} tracks",
                style: PulseTypography.bodyMedium,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtistsList(List<MediaFile> tracks) {
    // Map tracks to artists
    final Map<String, List<MediaFile>> artistMap = {};
    for (var track in tracks) {
      final key = track.artist;
      artistMap.putIfAbsent(key, () => []).add(track);
    }

    final artists = artistMap.keys.toList();

    if (artists.isEmpty) {
      return Center(child: Text("No artists available.", style: PulseTypography.bodyLarge));
    }

    return ListView.builder(
      itemCount: artists.length,
      padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 168),
      itemBuilder: (context, index) {
        final artistName = artists[index];
        final artistTracks = artistMap[artistName]!;
        
        // Find how many unique albums this artist has
        final albumsCount = artistTracks.map((t) => t.album).toSet().length;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: PulseColors.surface,
            child: Text(
              artistName.isNotEmpty ? artistName[0].toUpperCase() : "?",
              style: PulseTypography.displaySmall.copyWith(color: PulseColors.accentPrimary),
            ),
          ),
          title: Text(
            artistName,
            style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            "$albumsCount albums · ${artistTracks.length} tracks",
            style: PulseTypography.bodyMedium,
          ),
          onTap: () {
            // Play all tracks of this artist
            PlaybackService.instance.playTrack(artistTracks.first, newQueue: artistTracks);
          },
        );
      },
    );
  }
}

class _SliverTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabHeaderDelegate({required this.tabBar});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: PulseColors.background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabHeaderDelegate oldDelegate) => false;
}
