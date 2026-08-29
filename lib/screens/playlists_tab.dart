import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/media_file.dart';
import '../models/playlist.dart';
import '../services/media_scanner.dart';
import '../services/playlist_service.dart';
import '../services/playback_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'playlist_detail_screen.dart';
import '../widgets/interactive_elements.dart';

class PlaylistsTab extends StatefulWidget {
  const PlaylistsTab({Key? key}) : super(key: key);

  @override
  State<PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<PlaylistsTab> {
  final _playlistService = PlaylistService.instance;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PulseColors.surfaceHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("New Playlist", style: PulseTypography.displaySmall),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: PulseTypography.bodyLarge,
            decoration: InputDecoration(
              hintText: "Playlist Name",
              hintStyle: PulseTypography.bodyMedium,
              filled: true,
              fillColor: PulseColors.surface,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: PulseColors.accentPrimary, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: PulseColors.isLight ? Colors.black12 : Colors.white12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: PulseColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context);
                  final playlist = await _playlistService.createPlaylist(name);
                  _navigateToPlaylist(playlist, isSmart: false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PulseColors.accentPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Create", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _navigateToPlaylist(dynamic playlist, {required bool isSmart, String? smartType}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlaylistDetailScreen(
          playlist: playlist,
          isSmart: isSmart,
          smartType: smartType,
        ),
      ),
    );
  }

  void _playPlaylistDirectly(Playlist playlist) {
    final allFiles = MediaScanner.instance.allFiles.value;
    final pathMap = {for (var f in allFiles) f.path: f};
    final playlistFiles = playlist.mediaIds
        .map((p) => pathMap[p])
        .whereType<MediaFile>()
        .toList();

    if (playlistFiles.isNotEmpty) {
      PlaybackService.instance.play(playlistFiles.first, queue: playlistFiles);
    }
  }

  Widget _buildSmartPlaylistCard({
    required IconData icon,
    required String title,
    required int count,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return BouncingTap(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: PulseColors.isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: PulseColors.isLight ? 0.15 : 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              color: PulseColors.surfaceHigh.withValues(alpha: PulseColors.isLight ? 0.90 : 0.70),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: gradientColors.first.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: gradientColors.first.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "$count tracks",
                          style: TextStyle(
                            color: gradientColors.first,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PulseTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMosaicThumbnail(List<String> paths) {
    final List<String> validArtPaths = [];
    final allFiles = MediaScanner.instance.allFiles.value;
    final pathMap = {for (var f in allFiles) f.path: f};

    for (var path in paths) {
      final file = pathMap[path];
      if (file != null && file.albumArtPath != null && File(file.albumArtPath!).existsSync()) {
        validArtPaths.add(file.albumArtPath!);
      }
      if (validArtPaths.length >= 4) break;
    }

    if (validArtPaths.isEmpty) {
      return Container(
        color: PulseColors.surfaceHigh,
        child: Center(
          child: Icon(
            Icons.playlist_play_rounded,
            size: 42,
            color: PulseColors.accentPrimary,
          ),
        ),
      );
    }

    if (validArtPaths.length < 4) {
      return Image.file(
        File(validArtPaths.first),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
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

  String _getPlaylistTotalDuration(List<String> mediaPaths) {
    final allFiles = MediaScanner.instance.allFiles.value;
    final pathMap = {for (var f in allFiles) f.path: f};

    Duration total = Duration.zero;
    for (var path in mediaPaths) {
      final file = pathMap[path];
      if (file != null) {
        total += file.duration;
      }
    }

    if (total == Duration.zero) return '';
    final hrs = total.inHours;
    final mins = total.inMinutes.remainder(60);
    if (hrs > 0) {
      return '$hrs hr $mins min';
    }
    return '$mins min';
  }

  @override
  Widget build(BuildContext context) {
    final allFiles = MediaScanner.instance.allFiles.value;
    final favCount = _playlistService.favorites.value.length;
    final recentCount = _playlistService.getRecentlyPlayed(allFiles).length;
    final mostCount = _playlistService.getMostPlayed(allFiles).length;
    final addedCount = _playlistService.getJustAdded(allFiles).length;

    return Scaffold(
      backgroundColor: PulseColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Top Header ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Playlists", style: PulseTypography.displayLarge),
                        const SizedBox(height: 4),
                        ValueListenableBuilder<List<Playlist>>(
                          valueListenable: _playlistService.playlists,
                          builder: (context, pl, _) => Text(
                            "${pl.length} Custom • 4 Smart Collections",
                            style: PulseTypography.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: PulseColors.surfaceHigh,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.add_rounded, color: PulseColors.accentPrimary, size: 22),
                          ),
                          onPressed: _showCreatePlaylistDialog,
                          tooltip: "Create Playlist",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Smart Collections Header ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 12),
                child: Text("Collections", style: PulseTypography.displaySmall),
              ),
            ),

            // ── Smart Collections 2x2 Grid ──────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.45,
                children: [
                  _buildSmartPlaylistCard(
                    icon: Icons.favorite_rounded,
                    title: "Favorites",
                    count: favCount,
                    gradientColors: [const Color(0xFFFF2E63), const Color(0xFFFF5376)],
                    onTap: () => _navigateToPlaylist(
                      Playlist(id: 'fav', name: 'Favorites', mediaIds: [], createdDate: DateTime.now()),
                      isSmart: true,
                      smartType: 'Favorites',
                    ),
                  ),
                  _buildSmartPlaylistCard(
                    icon: Icons.history_rounded,
                    title: "Recently Played",
                    count: recentCount,
                    gradientColors: [const Color(0xFF00F0FF), const Color(0xFF0072FF)],
                    onTap: () => _navigateToPlaylist(
                      Playlist(id: 'recent', name: 'Recently Played', mediaIds: [], createdDate: DateTime.now()),
                      isSmart: true,
                      smartType: 'Recently Played',
                    ),
                  ),
                  _buildSmartPlaylistCard(
                    icon: Icons.local_fire_department_rounded,
                    title: "Most Played",
                    count: mostCount,
                    gradientColors: [const Color(0xFFFF8800), const Color(0xFFFF3300)],
                    onTap: () => _navigateToPlaylist(
                      Playlist(id: 'most', name: 'Most Played', mediaIds: [], createdDate: DateTime.now()),
                      isSmart: true,
                      smartType: 'Most Played',
                    ),
                  ),
                  _buildSmartPlaylistCard(
                    icon: Icons.auto_awesome_rounded,
                    title: "Just Added",
                    count: addedCount,
                    gradientColors: [const Color(0xFFA855F7), const Color(0xFFEC4899)],
                    onTap: () => _navigateToPlaylist(
                      Playlist(id: 'added', name: 'Just Added', mediaIds: [], createdDate: DateTime.now()),
                      isSmart: true,
                      smartType: 'Just Added',
                    ),
                  ),
                ],
              ),
            ),

            // ── Your Playlists Section Header ───────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 28, bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Your Playlists", style: PulseTypography.displaySmall),
                    TextButton.icon(
                      onPressed: _showCreatePlaylistDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("New"),
                      style: TextButton.styleFrom(
                        foregroundColor: PulseColors.accentPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── User Custom Playlists ───────────────────────────────
            ValueListenableBuilder<List<Playlist>>(
              valueListenable: _playlistService.playlists,
              builder: (context, userPlaylists, child) {
                if (userPlaylists.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: PulseColors.surfaceHigh.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: PulseColors.isLight ? Colors.black12 : Colors.white10,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.playlist_add_rounded, size: 48, color: PulseColors.accentPrimary),
                            const SizedBox(height: 12),
                            Text("No playlists yet", style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              "Create playlists to organize your favorite tracks & videos.",
                              textAlign: TextAlign.center,
                              style: PulseTypography.bodySmall,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showCreatePlaylistDialog,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text("Create Playlist"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PulseColors.accentPrimary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.82,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final playlist = userPlaylists[index];
                        final durationString = _getPlaylistTotalDuration(playlist.mediaIds);

                        return BouncingTap(
                          onTap: () => _navigateToPlaylist(playlist, isSmart: false),
                          child: Container(
                            decoration: BoxDecoration(
                              color: PulseColors.surfaceHigh.withValues(alpha: PulseColors.isLight ? 0.90 : 0.65),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: PulseColors.isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Thumbnail Container with Play button badge
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                                          child: _buildMosaicThumbnail(playlist.mediaIds),
                                        ),
                                      ),
                                      if (playlist.mediaIds.isNotEmpty)
                                        Positioned(
                                          right: 8,
                                          bottom: 8,
                                          child: GestureDetector(
                                            onTap: () => _playPlaylistDirectly(playlist),
                                            child: Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: PulseColors.accentPrimary,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: PulseColors.accentPrimary.withValues(alpha: 0.4),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  )
                                                ],
                                              ),
                                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Title & Track Info
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              playlist.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: PulseTypography.bodyLarge.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.white54),
                                            color: PulseColors.surfaceHigh,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onSelected: (val) async {
                                              if (val == 'delete') {
                                                await _playlistService.deletePlaylist(playlist.id);
                                              }
                                            },
                                            itemBuilder: (ctx) => [
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                                    SizedBox(width: 8),
                                                    Text('Delete Playlist', style: TextStyle(color: Colors.redAccent)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        "${playlist.mediaIds.length} tracks${durationString.isNotEmpty ? ' • $durationString' : ''}",
                                        style: TextStyle(
                                          color: PulseColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(duration: 200.ms, delay: (index * 40).ms);
                      },
                      childCount: userPlaylists.length,
                    ),
                  ),
                );
              },
            ),

            // Bottom space for fixed navbar
            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
      ),
    );
  }
}
