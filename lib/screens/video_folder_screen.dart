import 'dart:io';
import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../widgets/media_card.dart';
import '../widgets/context_bottom_sheet.dart';
import '../players/video_player_screen.dart';
import '../services/playlist_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/action_toolbar.dart';
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
    final playlists = PlaylistService.instance.playlists.value;
    String? chosenId;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add to Playlist'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...playlists.map((p) => RadioListTile<String>(
                    title: Text(p.name),
                    value: p.id,
                    groupValue: chosenId,
                    onChanged: (v) => setState(() => chosenId = v),
                  )),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Create New Playlist'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final nameController = TextEditingController();
                  final newName = await showDialog<String>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('New Playlist'),
                      content: TextField(
                        controller: nameController,
                        decoration: const InputDecoration(hintText: 'Playlist name'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () => Navigator.of(c).pop(nameController.text.trim()),
                          child: const Text('Create'),
                        ),
                      ],
                    ),
                  );
                  if (newName != null && newName.isNotEmpty) {
                    final newPl = await PlaylistService.instance.createPlaylist(newName);
                    chosenId = newPl.id;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (chosenId != null) {
                  for (var path in widget.selectionProvider.selectedIds) {
                    await PlaylistService.instance.addToPlaylist(chosenId!, path);
                  }
                  widget.selectionProvider.clear();
                }
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
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
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideoPlayerScreen(file: video, playlist: sortedVideos)));
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
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideoPlayerScreen(file: video, playlist: sortedVideos)));
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
                onAddToPlaylist: _showAddToPlaylistDialog,
                onMove: () {},
                onDelete: () {},
              )
            : null,
      ),
    );
  }
}
