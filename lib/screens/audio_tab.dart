import 'dart:io';

import 'package:flutter/material.dart';

import '../models/media_file.dart';
import '../services/media_scanner.dart';
import '../services/playback_service.dart';
import '../providers/selection_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/media_card.dart';
import '../widgets/action_toolbar.dart';
import '../widgets/add_to_playlist_sheet.dart';

/// Displays all audio files with support for:
/// - Grid / list toggle
/// - Search / sort
/// - Long-press multi-select with an [ActionToolbar]
/// - Mini-player bottom padding awareness
class AudioTab extends StatefulWidget {
  const AudioTab({Key? key}) : super(key: key);

  @override
  State<AudioTab> createState() => _AudioTabState();
}

enum _SortMode { title, artist, album, duration, dateAdded }

class _AudioTabState extends State<AudioTab>
    with AutomaticKeepAliveClientMixin {
  // ── keep alive so scroll position survives tab switches ──────────────────
  @override
  bool get wantKeepAlive => true;

  // ── state ─────────────────────────────────────────────────────────────────
  bool _isGrid = false;
  _SortMode _sortMode = _SortMode.title;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _searchVisible = false;

  // ── selection ─────────────────────────────────────────────────────────────
  final SelectionProvider _selection = SelectionProvider();

  // ── helpers ───────────────────────────────────────────────────────────────
  List<MediaFile> _buildList(List<MediaFile> allFiles) {
    // 1. Audio only
    var list = allFiles.where((f) => !f.isVideo).toList();

    // 2. Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((f) =>
              f.title.toLowerCase().contains(q) ||
              f.artist.toLowerCase().contains(q) ||
              f.album.toLowerCase().contains(q))
          .toList();
    }

    // 3. Sort
    switch (_sortMode) {
      case _SortMode.title:
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case _SortMode.artist:
        list.sort((a, b) =>
            a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case _SortMode.album:
        list.sort((a, b) =>
            a.album.toLowerCase().compareTo(b.album.toLowerCase()));
        break;
      case _SortMode.duration:
        list.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case _SortMode.dateAdded:
        list.sort((a, b) => b.addedDate.compareTo(a.addedDate));
        break;
    }

    return list;
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchQuery = '';
        _searchController.clear();
        _searchFocus.unfocus();
      } else {
        Future.delayed(
            const Duration(milliseconds: 80), _searchFocus.requestFocus);
      }
    });
  }

  void _onTap(MediaFile file, List<MediaFile> visibleList) {
    if (_selection.isActive) {
      _selection.toggle(file.path);
      setState(() {});
      return;
    }
    PlaybackService.instance.playTrack(file, newQueue: visibleList);
  }

  void _onLongPress(MediaFile file) {
    _selection.toggle(file.path);
    setState(() {});
  }

  void _handleAddToPlaylist(List<MediaFile> allFiles) async {
    final selectedFiles = allFiles
        .where((f) => _selection.isSelected(f.path))
        .toList();
    if (selectedFiles.isEmpty) return;

    // Let AddToPlaylistSheet handle its own flow (no callbacks needed).
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AddToPlaylistSheet.multiple(
        mediaFiles: selectedFiles,
      ),
    );
    // Clear selection after sheet closes, regardless of action taken.
    _selection.clear();
    setState(() {});
  }

  void _handleMove() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Move: coming soon'),
    ));
  }

  void _handleDelete(List<MediaFile> allFiles) async {
    final selectedFiles = allFiles
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
    await MediaScanner.instance.scan();
    _selection.clear();
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<List<MediaFile>>(
      valueListenable: MediaScanner.instance.allFiles,
      builder: (context, allFiles, _) {
        final list = _buildList(allFiles);

        return ValueListenableBuilder<MediaFile?>(
          valueListenable: PlaybackService.instance.currentTrack,
          builder: (context, currentTrack, _) {
            // Extra bottom padding when mini-player is showing
            final miniPlayerHeight = currentTrack != null ? 72.0 : 0.0;
            final isSelectionMode = _selection.isActive;

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  Column(
                    children: [
                      // ── top bar ─────────────────────────────────────────────
                      _TopBar(
                        isGrid: _isGrid,
                        sortMode: _sortMode,
                        searchVisible: _searchVisible,
                        searchController: _searchController,
                        searchFocus: _searchFocus,
                        totalCount: list.length,
                        isSelectionMode: isSelectionMode,
                        selectedCount: _selection.count,
                        onSelectAll: () => setState(() => _selection.selectAll(list.map((f) => f.path))),
                        onClearSelection: () {
                          _selection.clear();
                          setState(() {});
                        },
                        onToggleLayout: () =>
                            setState(() => _isGrid = !_isGrid),
                        onToggleSearch: _toggleSearch,
                        onSearchChanged: (v) =>
                            setState(() => _searchQuery = v),
                        onSortChanged: (mode) =>
                            setState(() => _sortMode = mode),
                      ),

                      // ── list / grid ─────────────────────────────────────────
                      Expanded(
                        child: list.isEmpty
                            ? _EmptyState(
                                isFiltered: _searchQuery.isNotEmpty)
                            : _isGrid
                                ? _GridView(
                                    files: list,
                                    selection: _selection,
                                    miniPlayerHeight: miniPlayerHeight + (isSelectionMode ? 80.0 : 0.0),
                                    onTap: (f) => _onTap(f, list),
                                    onLongPress: _onLongPress,
                                  )
                                : _ListView(
                                    files: list,
                                    selection: _selection,
                                    miniPlayerHeight: miniPlayerHeight + (isSelectionMode ? 80.0 : 0.0),
                                    onTap: (f) => _onTap(f, list),
                                    onLongPress: _onLongPress,
                                  ),
                      ),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ActionToolbar(
                      provider: _selection,
                      onAddToPlaylist: () => _handleAddToPlaylist(list),
                      onMove: _handleMove,
                      onDelete: () => _handleDelete(list),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _selection.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final bool isGrid;
  final _SortMode sortMode;
  final bool searchVisible;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final int totalCount;
  final bool isSelectionMode;
  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onToggleLayout;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_SortMode> onSortChanged;

  const _TopBar({
    required this.isGrid,
    required this.sortMode,
    required this.searchVisible,
    required this.searchController,
    required this.searchFocus,
    required this.totalCount,
    required this.isSelectionMode,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onToggleLayout,
    required this.onToggleSearch,
    required this.onSearchChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Title + count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Songs', style: PulseTypography.displayLarge),
                    Text(
                      isSelectionMode
                          ? '$selectedCount selected'
                          : '$totalCount tracks',
                      style: PulseTypography.monoLabel.copyWith(
                        color: isSelectionMode
                            ? PulseColors.accentSecondary
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              // Select-all button (visible in selection mode)
              if (isSelectionMode) ...[  
                IconButton(
                  icon: const Icon(Icons.select_all_rounded, color: Colors.white),
                  tooltip: 'Select all',
                  onPressed: onSelectAll,
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: PulseColors.danger),
                  tooltip: 'Clear selection',
                  onPressed: onClearSelection,
                ),
              ] else ...[
                // Search
                IconButton(
                  icon: Icon(
                    searchVisible
                        ? Icons.search_off_rounded
                        : Icons.search_rounded,
                    color: searchVisible
                        ? PulseColors.accentPrimary
                        : PulseColors.textSecondary,
                  ),
                  onPressed: onToggleSearch,
                  tooltip: 'Search',
                ),
                // Sort
                _SortButton(current: sortMode, onChanged: onSortChanged),
                // Layout toggle
                IconButton(
                  icon: Icon(
                    isGrid
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    color: PulseColors.textSecondary,
                  ),
                  onPressed: onToggleLayout,
                  tooltip: isGrid ? 'List view' : 'Grid view',
                ),
              ],
            ],
          ),
          // Search bar (animated)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: searchVisible && !isSelectionMode
                ? Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: TextField(
                      controller: searchController,
                      focusNode: searchFocus,
                      style: PulseTypography.bodyLarge
                          .copyWith(color: PulseColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search songs…',
                        hintStyle: PulseTypography.bodyMedium,
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 20),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    size: 18),
                                onPressed: () {
                                  searchController.clear();
                                  onSearchChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: PulseColors.surface,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: onSearchChanged,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SORT BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _SortButton extends StatelessWidget {
  final _SortMode current;
  final ValueChanged<_SortMode> onChanged;

  const _SortButton({required this.current, required this.onChanged});

  static const _labels = {
    _SortMode.title: 'Title',
    _SortMode.artist: 'Artist',
    _SortMode.album: 'Album',
    _SortMode.duration: 'Duration',
    _SortMode.dateAdded: 'Date added',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortMode>(
      icon: Icon(Icons.sort_rounded, color: PulseColors.textSecondary),
      tooltip: 'Sort',
      color: PulseColors.surface,
      onSelected: onChanged,
      itemBuilder: (_) => _SortMode.values
          .map(
            (mode) => PopupMenuItem<_SortMode>(
              value: mode,
              child: Row(
                children: [
                  Icon(
                    current == mode
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: current == mode
                        ? PulseColors.accentPrimary
                        : PulseColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(_labels[mode]!,
                      style: PulseTypography.bodyMedium.copyWith(
                        color: current == mode
                            ? PulseColors.accentPrimary
                            : PulseColors.textPrimary,
                      )),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIST VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _ListView extends StatelessWidget {
  final List<MediaFile> files;
  final SelectionProvider selection;
  final double miniPlayerHeight;
  final ValueChanged<MediaFile> onTap;
  final ValueChanged<MediaFile> onLongPress;

  const _ListView({
    required this.files,
    required this.selection,
    required this.miniPlayerHeight,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
          8, 0, 8, miniPlayerHeight + 16),
      itemCount: files.length,
      itemBuilder: (context, i) {
        final file = files[i];
        final selected = selection.isSelected(file.path);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? PulseColors.accentPrimary.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: MediaCard(
            file: file,
            isGrid: false,
            onTap: () => onTap(file),
            onLongPress: () => onLongPress(file),
            isSelected: selected,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRID VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _GridView extends StatelessWidget {
  final List<MediaFile> files;
  final SelectionProvider selection;
  final double miniPlayerHeight;
  final ValueChanged<MediaFile> onTap;
  final ValueChanged<MediaFile> onLongPress;

  const _GridView({
    required this.files,
    required this.selection,
    required this.miniPlayerHeight,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossCount = width > 600 ? 3 : 2;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
          12, 4, 12, miniPlayerHeight + 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: files.length,
      itemBuilder: (context, i) {
        final file = files[i];
        final selected = selection.isSelected(file.path);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected
                ? PulseColors.accentPrimary.withValues(alpha: 0.15)
                : Colors.transparent,
            border: selected
                ? Border.all(
                    color: PulseColors.accentPrimary,
                    width: 2,
                  )
                : null,
          ),
          child: MediaCard(
            file: file,
            isGrid: true,
            onTap: () => onTap(file),
            onLongPress: () => onLongPress(file),
            isSelected: selected,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isFiltered;
  const _EmptyState({required this.isFiltered});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFiltered
                ? Icons.search_off_rounded
                : Icons.music_off_rounded,
            size: 64,
            color: PulseColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered ? 'No results' : 'No audio files found',
            style: PulseTypography.bodyLarge.copyWith(
                color: PulseColors.textSecondary),
          ),
          if (!isFiltered) ...[
            const SizedBox(height: 8),
            Text(
              'Add music to your device to get started',
              style: PulseTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}