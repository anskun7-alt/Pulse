import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/media_file.dart';
import '../widgets/media_card.dart';
import '../services/playback_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/action_toolbar.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../providers/selection_provider.dart';

class VideoFolderScreen extends StatefulWidget {
  final String folderName;
  final List<MediaFile> videos;
  final SelectionProvider selectionProvider;

  const VideoFolderScreen({
    Key? key,
    required this.folderName,
    required this.videos,
    required this.selectionProvider,
  }) : super(key: key);

  @override
  State<VideoFolderScreen> createState() => _VideoFolderScreenState();
}

class _VideoFolderScreenState extends State<VideoFolderScreen> {
  bool _isGrid = false;
  String _sortBy = 'Name'; // 'Name' | 'Date' | 'Duration' | 'Size'
  bool _autoPlayFolder = true;

  @override
  void initState() {
    super.initState();
    try {
      _autoPlayFolder = Hive.box('settings_box').get('auto_play_folder', defaultValue: true) as bool;
    } catch (_) {}
  }

  // Helper to sort videos based on the selected criterion.
  List<MediaFile> _sortVideos(List<MediaFile> files) {
    var list = List<MediaFile>.from(files);
    switch (_sortBy) {
      case 'Name':
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'Date':
        list.sort((a, b) => b.addedDate.compareTo(a.addedDate));
        break;
      case 'Duration':
        list.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case 'Size':
        list.sort((a, b) => b.size.compareTo(a.size));
        break;
    }
    return list;
  }

  // Show dialog to add selected items to a playlist.
  Future<void> _showAddToPlaylistDialog() async {
    final selectedFiles = widget.videos
        .where((f) => widget.selectionProvider.isSelected(f.path))
        .toList();
    if (selectedFiles.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddToPlaylistSheet.multiple(
        mediaFiles: selectedFiles,
        onAdded: (playlistId) {
          widget.selectionProvider.clear();
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

  @override
  Widget build(BuildContext context) {
    final sortedVideos = _sortVideos(widget.videos);
    final isSelectionMode = widget.selectionProvider.isActive;
    return WillPopScope(
      onWillPop: () async {
        if (isSelectionMode) {
          widget.selectionProvider.clear();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: PulseColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.folderName, style: PulseTypography.displaySmall),
          actions: [
            IconButton(
              icon: Icon(
                _autoPlayFolder ? Icons.playlist_play_rounded : Icons.playlist_remove_rounded,
                color: _autoPlayFolder ? PulseColors.accentPrimary : Colors.white60,
              ),
              tooltip: _autoPlayFolder ? 'Folder Auto-Play: ON' : 'Folder Auto-Play: OFF',
              onPressed: () {
                setState(() => _autoPlayFolder = !_autoPlayFolder);
                Hive.box('settings_box').put('auto_play_folder', _autoPlayFolder);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_autoPlayFolder ? 'Auto-play next video in folder enabled' : 'Auto-play next video in folder disabled'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: PulseColors.surfaceHigh,
                ));
              },
            ),
            if (isSelectionMode)
              IconButton(
                icon: const Icon(Icons.select_all_rounded, color: Colors.white),
                tooltip: 'Select All',
                onPressed: () => widget.selectionProvider.selectAll(sortedVideos.map((v) => v.path)),
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sort pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 10),
              child: Row(
                children: ['Name', 'Date', 'Duration', 'Size'].map((criterion) {
                  final selected = _sortBy == criterion;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () => setState(() => _sortBy = criterion),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : PulseColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? Colors.white : const Color(0xFF1E1E30), width: 1),
                        ),
                        child: Text(
                          criterion,
                          style: PulseTypography.bodyMedium.copyWith(color: selected ? Colors.black : PulseColors.textSecondary, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // Content grid/list
            Expanded(
              child: _isGrid
                  ? GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: sortedVideos.length,
                      itemBuilder: (context, index) {
                        final video = sortedVideos[index];
                        final isSelected = widget.selectionProvider.isSelected(video.path);
                        return MediaCard(
                          file: video,
                          isGrid: true,
                          isSelectionMode: isSelectionMode,
                          isSelected: isSelected,
                          onTap: () {
                            if (isSelectionMode) {
                              widget.selectionProvider.toggle(video.path);
                            } else {
                              PlaybackService.instance.navigateToVideo(sortedVideos, video);
                            }
                          },
                          onLongPress: () => widget.selectionProvider.toggle(video.path),
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: sortedVideos.length,
                      itemBuilder: (context, index) {
                        final video = sortedVideos[index];
                        final isSelected = widget.selectionProvider.isSelected(video.path);
                        return MediaCard(
                          file: video,
                          isGrid: false,
                          isSelectionMode: isSelectionMode,
                          isSelected: isSelected,
                          onTap: () {
                            if (isSelectionMode) {
                              widget.selectionProvider.toggle(video.path);
                            } else {
                              PlaybackService.instance.navigateToVideo(sortedVideos, video);
                            }
                          },
                          onLongPress: () => widget.selectionProvider.toggle(video.path),
                        );
                      },
                    ),
            ),
          ],
        ),
        bottomNavigationBar: isSelectionMode
            ? ActionToolbar(
                provider: widget.selectionProvider,
                hasFloatingNavBar: false,
                onAddToPlaylist: _showAddToPlaylistDialog,
                onMove: () {},
                onDelete: () {},
              )
            : null,
      ),
    );
  }
}
