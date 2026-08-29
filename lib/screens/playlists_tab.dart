import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../models/playlist.dart';
import '../services/media_scanner.dart';
import '../services/playlist_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'playlist_detail_screen.dart';

class PlaylistsTab extends StatefulWidget {
  const PlaylistsTab({Key? key}) : super(key: key);

  @override
  State<PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<PlaylistsTab> {
  final _playlistService = PlaylistService.instance;

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: PulseColors.surfaceHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  Navigator.pop(context);
                  final playlist = await _playlistService.createPlaylist(name);
                  _navigateToPlaylist(playlist, isSmart: false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PulseColors.accentSecondary,
                foregroundColor: Colors.black,
              ),
              child: const Text("Create", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

  Widget _buildSmartPlaylistCard({
    required IconData icon,
    required String title,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: PulseColors.surface.withOpacity(0.35),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          color: gradientColors.first.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PulseTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.2,
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
        child: Icon(Icons.playlist_play_rounded, size: 36, color: PulseColors.accentPrimary),
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
      return ' · $hrs hr $mins min';
    }
    return ' · $mins min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 8),
                child: Text("Playlists", style: PulseTypography.displayLarge),
              ),
            ),

            // Smart Playlists Horizontal Carousel
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 20),
                child: SizedBox(
                  height: 124,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _buildSmartPlaylistCard(
                        icon: Icons.favorite_rounded,
                        title: "Favorites",
                        gradientColors: [const Color(0xFFFF416C), const Color(0xFFFF4B2B)],
                        onTap: () => _navigateToPlaylist(
                          Playlist(id: 'fav', name: 'Favorites', mediaIds: [], createdDate: DateTime.now()),
                          isSmart: true,
                          smartType: 'Favorites',
                        ),
                      ),
                      _buildSmartPlaylistCard(
                        icon: Icons.history_rounded,
                        title: "Recently\nPlayed",
                        gradientColors: [const Color(0xFF1CB5E0), const Color(0xFF000046)],
                        onTap: () => _navigateToPlaylist(
                          Playlist(id: 'recent', name: 'Recently Played', mediaIds: [], createdDate: DateTime.now()),
                          isSmart: true,
                          smartType: 'Recently Played',
                        ),
                      ),
                      _buildSmartPlaylistCard(
                        icon: Icons.local_fire_department_rounded,
                        title: "Most\nPlayed",
                        gradientColors: [const Color(0xFFF12711), const Color(0xFFF5AF19)],
                        onTap: () => _navigateToPlaylist(
                          Playlist(id: 'most', name: 'Most Played', mediaIds: [], createdDate: DateTime.now()),
                          isSmart: true,
                          smartType: 'Most Played',
                        ),
                      ),
                      _buildSmartPlaylistCard(
                        icon: Icons.auto_awesome_rounded,
                        title: "Just Added",
                        gradientColors: [const Color(0xFF8A2387), const Color(0xFFE94057)],
                        onTap: () => _navigateToPlaylist(
                          Playlist(id: 'added', name: 'Just Added', mediaIds: [], createdDate: DateTime.now()),
                          isSmart: true,
                          smartType: 'Just Added',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // User Playlists Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 12),
                child: Text("Your Playlists", style: PulseTypography.displaySmall),
              ),
            ),

            // User Custom Playlists List
            ValueListenableBuilder<List<Playlist>>(
              valueListenable: _playlistService.playlists,
              builder: (context, userPlaylists, child) {
                if (userPlaylists.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          "No custom playlists created yet.",
                          style: TextStyle(color: PulseColors.textSecondary),
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final playlist = userPlaylists[index];
                        final durationString = _getPlaylistTotalDuration(playlist.mediaIds);
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                color: PulseColors.surface.withOpacity(0.25),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      color: PulseColors.surfaceHigh,
                                      child: _buildMosaicThumbnail(playlist.mediaIds),
                                    ),
                                  ),
                                  title: Text(
                                    playlist.name,
                                    style: PulseTypography.bodyLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: PulseColors.accentSecondary.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            "${playlist.mediaIds.length} tracks",
                                            style: PulseTypography.bodySmall.copyWith(
                                              color: PulseColors.accentSecondary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (durationString.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 6.0),
                                            child: Text(
                                              durationString,
                                              style: PulseTypography.bodySmall.copyWith(color: Colors.white54, fontSize: 11),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
                                  onTap: () => _navigateToPlaylist(playlist, isSmart: false),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: userPlaylists.length,
                    ),
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 180),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 96.0), // Above the mini player
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: PulseColors.accentGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: PulseColors.accentPrimary.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: _showCreatePlaylistDialog,
            elevation: 0,
            highlightElevation: 0,
            backgroundColor: Colors.transparent,
            icon: const Icon(Icons.add, color: Colors.black, size: 20),
            label: Text(
              "CREATE PLAYLIST",
              style: PulseTypography.bodyMedium.copyWith(
                color: Colors.black, 
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
