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
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'playlist_detail_screen.dart';
import '../widgets/interactive_elements.dart';
import '../widgets/media_picker_sheet.dart';

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

  String _typeFilter = 'All'; // 'All' | 'Permanent' | 'Temporary'

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    bool isTemp = false;
    String? selectedCoverPath;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: PulseColors.surfaceHigh,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("New Playlist", style: PulseTypography.displaySmall),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
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
                    const SizedBox(height: 12),
                    // Optional cover image picker
                    GestureDetector(
                      onTap: () async {
                        try {
                          final result = await FilePicker.pickFiles(type: FileType.image);
                          if (result != null && result.files.single.path != null) {
                            setDialogState(() {
                              selectedCoverPath = result.files.single.path;
                            });
                          }
                        } catch (_) {}
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: PulseColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            if (selectedCoverPath != null && File(selectedCoverPath!).existsSync())
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(File(selectedCoverPath!), width: 32, height: 32, fit: BoxFit.cover),
                              )
                            else
                              Icon(Icons.image_outlined, size: 20, color: PulseColors.accentSecondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedCoverPath != null ? "Cover Image Selected" : "Add Cover Image (Optional)",
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                            if (selectedCoverPath != null)
                              GestureDetector(
                                onTap: () => setDialogState(() => selectedCoverPath = null),
                                child: const Icon(Icons.close, size: 16, color: Colors.white54),
                              )
                            else
                              const Icon(Icons.add_photo_alternate_outlined, size: 18, color: Colors.white54),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => isTemp = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !isTemp
                                    ? PulseColors.accentPrimary.withValues(alpha: 0.22)
                                    : PulseColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !isTemp ? PulseColors.accentPrimary : Colors.white12,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.save_rounded,
                                    size: 15,
                                    color: !isTemp ? PulseColors.accentPrimary : Colors.white60,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Permanent",
                                    style: TextStyle(
                                      color: !isTemp ? Colors.white : Colors.white60,
                                      fontWeight: !isTemp ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => isTemp = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isTemp
                                    ? Colors.amber.withValues(alpha: 0.22)
                                    : PulseColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isTemp ? Colors.amber : Colors.white12,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 15,
                                    color: isTemp ? Colors.amber : Colors.white60,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Temporary",
                                    style: TextStyle(
                                      color: isTemp ? Colors.amber : Colors.white60,
                                      fontWeight: isTemp ? FontWeight.bold : FontWeight.normal,
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
                    const SizedBox(height: 6),
                    Text(
                      isTemp
                          ? "Temporary playlists stay only while the app is open and vanish when closed."
                          : "Permanent playlists are stored safely on device until deleted.",
                      style: TextStyle(
                        color: isTemp ? Colors.amber.withValues(alpha: 0.8) : PulseColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
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
                      final playlist = await _playlistService.createPlaylist(
                        name,
                        isTemporary: isTemp,
                        coverImagePath: selectedCoverPath,
                      );
                      _navigateToPlaylist(playlist, isSmart: false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTemp ? Colors.amber : PulseColors.accentPrimary,
                    foregroundColor: isTemp ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Create", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _importM3U() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8', 'pls'],
        dialogTitle: 'Select M3U / PLS Playlist to Import',
      );
      if (result != null && result.files.single.path != null) {
        final imported = await _playlistService.importPlaylistFromM3U(result.files.single.path!);
        if (imported != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Imported '${imported.name}' with ${imported.mediaIds.length} tracks"),
              backgroundColor: PulseColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error importing playlist: $e"), backgroundColor: PulseColors.danger),
        );
      }
    }
  }

  Future<void> _exportM3U(Playlist playlist) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final exported = await _playlistService.exportPlaylistToM3U(playlist, dir.path);
      if (exported != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Exported to ${exported.path}"),
            backgroundColor: PulseColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error exporting playlist: $e"), backgroundColor: PulseColors.danger),
        );
      }
    }
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
      PlaybackService.instance.playTrack(playlistFiles.first, newQueue: playlistFiles);
    }
  }

  Widget _buildSmartPlaylistCard({
    required IconData icon,
    required String title,
    required int count,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    bool isDesktop = false,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: isDesktop
                  ? Row(
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
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PulseTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "$count tracks",
                                style: TextStyle(
                                  color: gradientColors.first,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3), size: 20),
                      ],
                    )
                  : Column(
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

  Widget _buildMosaicThumbnail(List<String> paths, {String? coverImagePath}) {
    if (coverImagePath != null && File(coverImagePath).existsSync()) {
      return Image.file(
        File(coverImagePath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

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

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 700;

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
                            child: Icon(Icons.file_upload_outlined, color: PulseColors.accentSecondary, size: 20),
                          ),
                          onPressed: _importM3U,
                          tooltip: "Import M3U / PLS",
                        ),
                        const SizedBox(width: 6),
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

            // ── Smart Collections Grid ──────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid.count(
                crossAxisCount: isDesktop ? 4 : 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: isDesktop ? 2.4 : 1.45,
                children: [
                  _buildSmartPlaylistCard(
                    icon: Icons.favorite_rounded,
                    title: "Favorites",
                    count: favCount,
                    gradientColors: [const Color(0xFFFF2E63), const Color(0xFFFF5376)],
                    isDesktop: isDesktop,
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
                    isDesktop: isDesktop,
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
                    isDesktop: isDesktop,
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
                    isDesktop: isDesktop,
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
                padding: const EdgeInsets.only(left: 20, right: 20, top: 28, bottom: 8),
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

            // ── Filter Pills: All / Permanent / Temporary ────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
                child: Row(
                  children: ['All', 'Permanent', 'Temporary'].map((filter) {
                    final isSelected = _typeFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _typeFilter = filter),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (filter == 'Temporary'
                                    ? Colors.amber.withValues(alpha: 0.22)
                                    : PulseColors.accentPrimary.withValues(alpha: 0.22))
                                : PulseColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? (filter == 'Temporary' ? Colors.amber : PulseColors.accentPrimary)
                                  : Colors.white12,
                            ),
                          ),
                          child: Text(
                            filter == 'Temporary' ? '⏳ Temporary' : (filter == 'Permanent' ? '📌 Permanent' : '✨ All'),
                            style: TextStyle(
                              color: isSelected
                                  ? (filter == 'Temporary' ? Colors.amber : PulseColors.accentPrimary)
                                  : PulseColors.textSecondary,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // ── User Custom Playlists ───────────────────────────────
            ValueListenableBuilder<List<Playlist>>(
              valueListenable: _playlistService.playlists,
              builder: (context, userPlaylists, child) {
                final filtered = userPlaylists.where((p) {
                  if (_typeFilter == 'Permanent') return !p.isTemporary;
                  if (_typeFilter == 'Temporary') return p.isTemporary;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
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
                            Icon(
                              _typeFilter == 'Temporary' ? Icons.timer_outlined : Icons.playlist_add_rounded,
                              size: 48,
                              color: _typeFilter == 'Temporary' ? Colors.amber : PulseColors.accentPrimary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _typeFilter == 'Temporary'
                                  ? "No temporary session playlists"
                                  : (_typeFilter == 'Permanent' ? "No permanent playlists" : "No playlists yet"),
                              style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _typeFilter == 'Temporary'
                                  ? "Create a temporary playlist to queue songs for this session only."
                                  : "Create playlists to organize your favorite tracks & videos.",
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

                final crossCount = isDesktop ? 4 : 2;
                final aspectRatio = isDesktop ? 0.95 : 0.82;

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: aspectRatio,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final playlist = filtered[index];
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
                                          child: _buildMosaicThumbnail(
                                            playlist.mediaIds,
                                            coverImagePath: playlist.coverImagePath,
                                          ),
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
                                                gradient: PulseColors.accentGradient,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: PulseColors.accentPrimary.withValues(alpha: 0.5),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  )
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.play_arrow_rounded,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Title & Track Info
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    playlist.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: PulseTypography.bodyLarge.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                if (playlist.isTemporary) ...[
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber.withValues(alpha: 0.18),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 0.8),
                                                    ),
                                                    child: const Text(
                                                      '⏳ Temp',
                                                      style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "${playlist.mediaIds.length} items${durationString.isNotEmpty ? ' • $durationString' : ''}",
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.5),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_vert_rounded,
                                          color: Colors.white.withValues(alpha: 0.5),
                                          size: 18,
                                        ),
                                        color: PulseColors.surfaceHigh,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        onSelected: (val) {
                                          if (val == 'add') {
                                            showModalBottomSheet(
                                              context: context,
                                              backgroundColor: Colors.transparent,
                                              isScrollControlled: true,
                                              builder: (context) => MediaPickerSheet(playlist: playlist),
                                            );
                                          } else if (val == 'export') {
                                            _exportM3U(playlist);
                                          } else if (val == 'delete') {
                                            _playlistService.deletePlaylist(playlist.id);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'add',
                                            child: Row(
                                              children: [
                                                Icon(Icons.playlist_add_rounded, size: 18),
                                                SizedBox(width: 8),
                                                Text('Add Media'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'export',
                                            child: Row(
                                              children: [
                                                Icon(Icons.file_download_outlined, size: 18),
                                                SizedBox(width: 8),
                                                Text('Export M3U'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete_outline, color: PulseColors.danger, size: 18),
                                                const SizedBox(width: 8),
                                                Text('Delete', style: TextStyle(color: PulseColors.danger)),
                                              ],
                                            ),
                                          ),
                                        ],
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
