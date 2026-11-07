import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../models/playlist.dart';
import '../services/media_scanner.dart';
import '../services/playlist_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'video_thumbnail_widget.dart';

class MediaPickerSheet extends StatefulWidget {
  final Playlist playlist;
  final VoidCallback? onAdded;

  const MediaPickerSheet({
    Key? key,
    required this.playlist,
    this.onAdded,
  }) : super(key: key);

  @override
  State<MediaPickerSheet> createState() => _MediaPickerSheetState();
}

class _MediaPickerSheetState extends State<MediaPickerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<Set<String>> _selectedNotifier = ValueNotifier<Set<String>>({});
  String _searchQuery = '';

  List<MediaFile> _cachedAllFiles = [];
  List<MediaFile> _cachedFilteredFiles = [];
  Set<String> _existingNormalizedPaths = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabOrSearchChanged);
    _existingNormalizedPaths = widget.playlist.mediaIds.map(_normalize).toSet();
    _cachedAllFiles = MediaScanner.instance.allFiles.value;
    _updateFilteredList();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabOrSearchChanged);
    _tabController.dispose();
    _searchController.dispose();
    _selectedNotifier.dispose();
    super.dispose();
  }

  String _normalize(String path) => path.replaceAll('\\', '/').toLowerCase();

  void _onTabOrSearchChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _updateFilteredList();
    });
  }

  void _updateFilteredList() {
    var list = _cachedAllFiles;
    final tabIndex = _tabController.index;

    if (tabIndex == 1) {
      list = list.where((f) => !f.isVideo).toList();
    } else if (tabIndex == 2) {
      list = list.where((f) => f.isVideo).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((f) {
        return f.title.toLowerCase().contains(q) ||
            f.artist.toLowerCase().contains(q) ||
            f.album.toLowerCase().contains(q);
      }).toList();
    }

    _cachedFilteredFiles = list;
  }

  void _toggleSelect(String path) {
    final current = Set<String>.from(_selectedNotifier.value);
    if (current.contains(path)) {
      current.remove(path);
    } else {
      current.add(path);
    }
    _selectedNotifier.value = current;
  }

  void _toggleSelectAll(List<MediaFile> availableFiles) {
    final current = Set<String>.from(_selectedNotifier.value);
    final availablePaths = availableFiles.map((f) => f.path).toSet();
    final allSelected = availablePaths.every(current.contains);

    if (allSelected) {
      current.removeAll(availablePaths);
    } else {
      current.addAll(availablePaths);
    }
    _selectedNotifier.value = current;
  }

  void _handleAddSelected() async {
    final selected = _selectedNotifier.value;
    if (selected.isEmpty) return;

    await PlaylistService.instance.addMultipleToPlaylist(
      widget.playlist.id,
      selected.toList(),
    );

    if (mounted) {
      Navigator.pop(context);
      widget.onAdded?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${selected.length} item(s) to "${widget.playlist.name}"'),
          backgroundColor: PulseColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: PulseColors.surfaceHigh.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: const Color(0xFF2C2C42).withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Column(
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
              const SizedBox(height: 14),

              // Title and Done Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add to "${widget.playlist.name}"',
                          style: PulseTypography.displaySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        ValueListenableBuilder<Set<String>>(
                          valueListenable: _selectedNotifier,
                          builder: (context, selected, _) {
                            return Text(
                              '${selected.length} selected',
                              style: PulseTypography.bodySmall.copyWith(
                                color: PulseColors.accentSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Search Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: PulseColors.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) {
                      _searchQuery = v;
                      setState(() {
                        _updateFilteredList();
                      });
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search songs or videos...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.white60, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.white60, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _searchQuery = '';
                                setState(() {
                                  _updateFilteredList();
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Tab Bar: All | Songs | Videos
              TabBar(
                controller: _tabController,
                indicatorColor: PulseColors.accentSecondary,
                indicatorWeight: 3,
                labelColor: PulseColors.accentSecondary,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'All Media'),
                  Tab(text: 'Songs'),
                  Tab(text: 'Videos'),
                ],
              ),

              const Divider(color: Color(0xFF2C2C42), height: 1),

              // Media List
              Expanded(
                child: _cachedFilteredFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.video_library_rounded,
                              size: 48,
                              color: Colors.white24,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No matching files found'
                                  : 'No media files in library',
                              style: const TextStyle(color: Colors.white60, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Select All Bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_cachedFilteredFiles.length} items',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                                ValueListenableBuilder<Set<String>>(
                                  valueListenable: _selectedNotifier,
                                  builder: (context, selected, _) {
                                    final available = _cachedFilteredFiles
                                        .where((f) => !_existingNormalizedPaths.contains(_normalize(f.path)))
                                        .toList();
                                    final allSelected = available.isNotEmpty &&
                                        available.every((f) => selected.contains(f.path));

                                    return TextButton.icon(
                                      onPressed: available.isEmpty ? null : () => _toggleSelectAll(available),
                                      icon: Icon(
                                        allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                                        size: 16,
                                        color: PulseColors.accentSecondary,
                                      ),
                                      label: Text(
                                        allSelected ? 'Deselect All' : 'Select All',
                                        style: TextStyle(color: PulseColors.accentSecondary, fontSize: 12),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              itemCount: _cachedFilteredFiles.length,
                              itemBuilder: (context, index) {
                                final file = _cachedFilteredFiles[index];
                                final isAlreadyIn = _existingNormalizedPaths.contains(_normalize(file.path));

                                return _PickerMediaTile(
                                  file: file,
                                  isAlreadyIn: isAlreadyIn,
                                  selectedNotifier: _selectedNotifier,
                                  onTap: () => _toggleSelect(file.path),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),

              // Bottom Action Button
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF10101C),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: _selectedNotifier,
                  builder: (context, selected, _) {
                    final hasSelection = selected.isNotEmpty;
                    return SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: hasSelection ? _handleAddSelected : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PulseColors.accentSecondary,
                          disabledBackgroundColor: Colors.white12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: hasSelection ? 4 : 0,
                        ),
                        child: Text(
                          !hasSelection
                              ? 'Select items to add'
                              : 'Add ${selected.length} item(s) to Playlist',
                          style: TextStyle(
                            color: hasSelection ? Colors.black : Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerMediaTile extends StatelessWidget {
  final MediaFile file;
  final bool isAlreadyIn;
  final ValueNotifier<Set<String>> selectedNotifier;
  final VoidCallback onTap;

  const _PickerMediaTile({
    Key? key,
    required this.file,
    required this.isAlreadyIn,
    required this.selectedNotifier,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final accentColor = file.isVideo ? const Color(0xFF00E5FF) : const Color(0xFFFF9100);

    return ValueListenableBuilder<Set<String>>(
      valueListenable: selectedNotifier,
      builder: (context, selectedSet, _) {
        final isSelected = selectedSet.contains(file.path);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: isAlreadyIn ? null : onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? PulseColors.accentSecondary.withValues(alpha: 0.12)
                      : (isAlreadyIn ? Colors.white.withValues(alpha: 0.03) : Colors.transparent),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? PulseColors.accentSecondary.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: file.isVideo
                            ? VideoThumbnailWidget(
                                videoPath: file.path,
                                width: 44,
                                height: 44,
                              )
                            : (file.albumArtPath != null && File(file.albumArtPath!).existsSync()
                                ? Image.file(
                                    File(file.albumArtPath!),
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: PulseColors.surface,
                                    child: Icon(
                                      Icons.music_note_rounded,
                                      color: accentColor,
                                      size: 22,
                                    ),
                                  )),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isAlreadyIn ? Colors.white38 : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                file.isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
                                size: 12,
                                color: isAlreadyIn ? Colors.white24 : accentColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                file.isVideo
                                    ? (file.duration > Duration.zero ? file.durationString : 'Video')
                                    : '${file.artist} · ${file.durationString}',
                                style: TextStyle(
                                  color: isAlreadyIn ? Colors.white24 : Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Trailing Status Checkbox
                    if (isAlreadyIn)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Added',
                          style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      )
                    else
                      Checkbox(
                        value: isSelected,
                        activeColor: PulseColors.accentSecondary,
                        checkColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        side: const BorderSide(color: Colors.white38, width: 1.5),
                        onChanged: (_) => onTap(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
