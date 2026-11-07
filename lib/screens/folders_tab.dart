import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/media_file.dart';
import '../providers/selection_provider.dart';
import '../services/media_scanner.dart';
import '../services/playback_service.dart';
import '../widgets/action_toolbar.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/media_card.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/view_mode_service.dart';

class FoldersTab extends StatefulWidget {
  const FoldersTab({Key? key}) : super(key: key);

  @override
  State<FoldersTab> createState() => _FoldersTabState();
}

class _FoldersTabState extends State<FoldersTab> {
  late Box _settingsBox;
  final List<Directory> _navigationHistory = [];
  Directory? _currentDir;
  final SelectionProvider _selection = SelectionProvider();
  
  List<Directory> _pinnedFolders = [];
  List<FileSystemEntity> _dirContents = [];

  @override
  void initState() {
    super.initState();
    _initStorage();
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  Future<void> _initStorage() async {
    _settingsBox = await Hive.openBox('settings_box');
    
    // Load pinned folders
    final pins = List<String>.from(_settingsBox.get('pinned_folders', defaultValue: []));
    _pinnedFolders = pins.map((p) => Directory(p)).toList();

    // Default to device storage root or music directory
    if (Platform.isAndroid) {
      _navigateTo(Directory('/storage/emulated/0'));
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      final musicDir = userProfile != null ? Directory('$userProfile\\Music') : null;
      if (musicDir != null && musicDir.existsSync()) {
        _navigateTo(musicDir);
      } else {
        _navigateTo(Directory('C:\\'));
      }
    } else {
      // Fallback
      final docDir = await getTemporaryDirectory();
      _navigateTo(docDir.parent);
    }
  }

  Future<void> _selectFolder() async {
    final String? selectedPath = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select media folder to browse',
    );
    if (selectedPath != null && selectedPath.isNotEmpty) {
      final selectedDir = Directory(selectedPath);
      if (selectedDir.existsSync()) {
        _navigateTo(selectedDir);
        // Automatically register to custom scanned folders
        await MediaScanner.instance.addCustomFolder(selectedPath);
        await MediaScanner.instance.scanFolder(selectedPath);
      }
    }
  }

  void _navigateTo(Directory dir) {
    if (!dir.existsSync()) return;

    setState(() {
      _currentDir = dir;
      _navigationHistory.add(dir);
      _dirContents = []; // Clear while loading
    });
    _loadContents(dir);
  }

  void _navigateBack() {
    if (_navigationHistory.length <= 1) return;
    
    _navigationHistory.removeLast();
    final prevDir = _navigationHistory.last;

    setState(() {
      _currentDir = prevDir;
      _dirContents = []; // Clear while loading
    });
    _loadContents(prevDir);
  }

  Future<void> _loadContents(Directory dir) async {
    try {
      final stream = dir.list(recursive: false, followLinks: false);
  
      final List<FileSystemEntity> filtered = [];

      await for (var entity in stream) {
        if (entity is Directory) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (!name.startsWith('.') && name != 'Android') {
            filtered.add(entity); // Show folder
          }
        } else if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          if (MediaScanner.audioExtensions.contains(ext) || MediaScanner.videoExtensions.contains(ext)) {
            filtered.add(entity);
          }
        }
      }

      // Sort: folders first, then files
      filtered.sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      if (mounted) {
        setState(() {
          _dirContents = filtered;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dirContents = [];
        });
      }
    }
  }

  void _togglePin(Directory dir) {
    final pins = List<String>.from(_settingsBox.get('pinned_folders', defaultValue: []));
    if (pins.contains(dir.path)) {
      pins.remove(dir.path);
    } else {
      pins.add(dir.path);
    }
    _settingsBox.put('pinned_folders', pins);

    setState(() {
      _pinnedFolders = pins.map((p) => Directory(p)).toList();
    });
  }

  void _handleAddToPlaylist() async {
    final mediaFiles = _dirContents
        .whereType<File>()
        .map((f) => _findMediaFile(f.path)!)
        .where((f) => _selection.isSelected(f.path))
        .toList();
    if (mediaFiles.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddToPlaylistSheet.multiple(
        mediaFiles: mediaFiles,
      ),
    );
    _selection.clear();
    setState(() {});
  }

  Future<void> _addDirectoryToPlaylist(Directory dir) async {
    final List<MediaFile> files = [];
    try {
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final e in entities) {
        if (e is File) {
          final ext = e.path.split('.').last.toLowerCase();
          if (MediaScanner.audioExtensions.contains(ext) || MediaScanner.videoExtensions.contains(ext)) {
            final mediaFile = _findMediaFile(e.path);
            if (mediaFile != null) {
              files.add(mediaFile);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning folder for playlist: $e');
    }

    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No playable media files found in this folder')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddToPlaylistSheet.multiple(
        mediaFiles: files,
      ),
    );
  }

  MediaFile? _findMediaFile(String path) {
    // Lookup matching MediaFile in the media scanner's discovered list to pass to actions
    try {
      return MediaScanner.instance.allFiles.value.firstWhere((f) => f.path == path);
    } catch (e) {
      // Create a fast dummy file if not scanned
      return MediaFile(
        id: path,
        title: path.split(Platform.pathSeparator).last.split('.').first,
        artist: "Unknown",
        album: "Local Storage",
        path: path,
        duration: Duration.zero,
        isVideo: MediaScanner.videoExtensions.contains(path.split('.').last.toLowerCase()),
        size: 0,
        addedDate: DateTime.now(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentDir == null) {
      return Scaffold(
        backgroundColor: PulseColors.background,
        body: Center(child: CircularProgressIndicator(color: PulseColors.accentPrimary)),
      );
    }

    final breadcrumbs = _currentDir!.path.split(Platform.pathSeparator).where((s) => s.isNotEmpty).toList();
    final isSelectionMode = _selection.isActive;

    return Scaffold(
      backgroundColor: PulseColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Folder Breadcrumb header
                Padding(
                  padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 8),
                  child: Row(
                    children: [
                      if (_navigationHistory.length > 1)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                          onPressed: () {
                            _selection.clear();
                            _navigateBack();
                          },
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(breadcrumbs.length, (index) {
                              final label = breadcrumbs[index];
                              final isLast = index == breadcrumbs.length - 1;

                              return Row(
                                children: [
                                  Text(
                                    label == 'storage' || label == 'emulated' ? 'Home' : label,
                                    style: PulseTypography.displaySmall.copyWith(
                                      color: isLast ? Colors.white : PulseColors.textSecondary,
                                    ),
                                  ),
                                  if (!isLast)
                                    Icon(Icons.chevron_right_rounded, color: PulseColors.textSecondary, size: 20),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                      if (isSelectionMode) ...[
                        IconButton(
                          icon: const Icon(Icons.select_all_rounded, color: Colors.white),
                          tooltip: 'Select all files',
                          onPressed: () {
                            final allFilePaths = _dirContents
                                .whereType<File>()
                                .map((f) => f.path)
                                .toList();
                            _selection.selectAll(allFilePaths);
                            setState(() {});
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: PulseColors.danger),
                          tooltip: 'Clear selection',
                          onPressed: () {
                            _selection.clear();
                            setState(() {});
                          },
                        ),
                      ] else ...[
                        ValueListenableBuilder<bool>(
                          valueListenable: ViewModeService.instance.isGrid,
                          builder: (context, isGrid, _) {
                            return IconButton(
                              icon: Icon(
                                isGrid ? Icons.format_list_bulleted_rounded : Icons.grid_view_rounded,
                                color: Colors.white,
                              ),
                              tooltip: isGrid ? 'Switch to List View' : 'Switch to Grid View',
                              onPressed: () => ViewModeService.instance.toggleViewMode(),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                          tooltip: 'Add this folder to playlist',
                          onPressed: () => _addDirectoryToPlaylist(_currentDir!),
                        ),
                        IconButton(
                          icon: const Icon(Icons.folder_open_rounded, color: Colors.white),
                          tooltip: 'Browse different folder',
                          onPressed: _selectFolder,
                        ),
                      ],
                    ],
                  ),
                ),

                // Pinned Folders Bar
                if (_pinnedFolders.isNotEmpty && _navigationHistory.length == 1) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text("Pinned Folders", style: PulseTypography.bodySmall.copyWith(color: PulseColors.textSecondary)),
                  ),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pinnedFolders.length,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemBuilder: (context, index) {
                        final dir = _pinnedFolders[index];
                        final name = dir.path.split(Platform.pathSeparator).last;

                        return GestureDetector(
                          onTap: () => _navigateTo(dir),
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: PulseColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF1E1E30), width: 1),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.folder_shared_rounded, color: PulseColors.accentSecondary, size: 28),
                                const SizedBox(width: 10),
                                Text(name, style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // Content View (Grid / List)
                Expanded(
                  child: _dirContents.isEmpty
                      ? Center(child: Text("Folder is empty.", style: PulseTypography.bodyLarge))
                      : ValueListenableBuilder<bool>(
                          valueListenable: ViewModeService.instance.isGrid,
                          builder: (context, isGrid, _) {
                            if (isGrid) {
                              return GridView.builder(
                                itemCount: _dirContents.length,
                                padding: EdgeInsets.only(
                                  left: 20, right: 20, top: 8,
                                  bottom: isSelectionMode ? 200 : 168,
                                ),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: MediaQuery.of(context).size.width >= 1200
                                      ? 5
                                      : (MediaQuery.of(context).size.width >= 800
                                          ? 4
                                          : (MediaQuery.of(context).size.width >= 600 ? 3 : 2)),
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.84,
                                ),
                                itemBuilder: (context, index) {
                                  final entity = _dirContents[index];
                                  final name = entity.path.split(Platform.pathSeparator).last;

                                  if (entity is Directory) {
                                    final isPinned = _pinnedFolders.any((d) => d.path == entity.path);
                                    return GestureDetector(
                                      onTap: () {
                                        _selection.clear();
                                        _navigateTo(entity);
                                      },
                                      child: Container(
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
                                                  ),
                                                  child: const Icon(Icons.folder_rounded, size: 20, color: Colors.white),
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                                    color: isPinned ? PulseColors.accentSecondary : PulseColors.textSecondary,
                                                    size: 18,
                                                  ),
                                                  onPressed: () => _togglePin(entity),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 13.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  } else {
                                    final mediaFile = _findMediaFile(entity.path)!;
                                    final isSelected = _selection.isSelected(mediaFile.path);
                                    return MediaCard(
                                      file: mediaFile,
                                      isGrid: true,
                                      isSelectionMode: isSelectionMode,
                                      isSelected: isSelected,
                                      onLongPress: () {
                                        _selection.toggle(mediaFile.path);
                                        setState(() {});
                                      },
                                      onTap: () {
                                        if (isSelectionMode) {
                                          _selection.toggle(mediaFile.path);
                                          setState(() {});
                                          return;
                                        }
                                        if (mediaFile.isVideo) {
                                          final folderVideos = _dirContents
                                              .where((e) => e is File && MediaScanner.videoExtensions.contains(e.path.split('.').last.toLowerCase()))
                                              .map((e) => _findMediaFile(e.path)!)
                                              .whereType<MediaFile>()
                                              .toList();
                                          PlaybackService.instance.navigateToVideo(folderVideos, mediaFile);
                                        } else {
                                          final folderAudio = _dirContents
                                              .where((e) => e is File && MediaScanner.audioExtensions.contains(e.path.split('.').last.toLowerCase()))
                                              .map((e) => _findMediaFile(e.path)!)
                                              .whereType<MediaFile>()
                                              .toList();
                                          PlaybackService.instance.playTrack(mediaFile, newQueue: folderAudio);
                                        }
                                      },
                                    );
                                  }
                                },
                              );
                            }

                            return ListView.builder(
                              itemCount: _dirContents.length,
                              padding: EdgeInsets.only(
                                left: 20, right: 20, top: 8,
                                bottom: isSelectionMode ? 200 : 168,
                              ),
                              itemBuilder: (context, index) {
                                final entity = _dirContents[index];
                                final name = entity.path.split(Platform.pathSeparator).last;

                                if (entity is Directory) {
                                  final isPinned = _pinnedFolders.any((d) => d.path == entity.path);

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.folder_rounded, color: PulseColors.accentPrimary, size: 36),
                                    title: Text(
                                      name,
                                      style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.playlist_add_rounded,
                                            color: PulseColors.accentSecondary,
                                            size: 22,
                                          ),
                                          tooltip: "Add Folder to Playlist",
                                          onPressed: () => _addDirectoryToPlaylist(entity),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                            color: isPinned ? PulseColors.accentSecondary : PulseColors.textSecondary,
                                            size: 18,
                                          ),
                                          onPressed: () => _togglePin(entity),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      _selection.clear();
                                      _navigateTo(entity);
                                    },
                                  );
                                } else {
                                  // File Card
                                  final mediaFile = _findMediaFile(entity.path)!;
                                  final isSelected = _selection.isSelected(mediaFile.path);
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: isSelected
                                          ? PulseColors.accentPrimary.withValues(alpha: 0.12)
                                          : Colors.transparent,
                                    ),
                                    child: MediaCard(
                                      file: mediaFile,
                                      isGrid: false,
                                      isSelectionMode: isSelectionMode,
                                      isSelected: isSelected,
                                      onLongPress: () {
                                        _selection.toggle(mediaFile.path);
                                        setState(() {});
                                      },
                                      onTap: () {
                                        if (isSelectionMode) {
                                          _selection.toggle(mediaFile.path);
                                          setState(() {});
                                          return;
                                        }
                                        if (mediaFile.isVideo) {
                                          final folderVideos = _dirContents
                                              .where((e) => e is File && MediaScanner.videoExtensions.contains(e.path.split('.').last.toLowerCase()))
                                              .map((e) => _findMediaFile(e.path)!)
                                              .whereType<MediaFile>()
                                              .toList();
                                          PlaybackService.instance.navigateToVideo(folderVideos, mediaFile);
                                        } else {
                                          final folderAudio = _dirContents
                                              .where((e) => e is File && MediaScanner.audioExtensions.contains(e.path.split('.').last.toLowerCase()))
                                              .map((e) => _findMediaFile(e.path)!)
                                              .whereType<MediaFile>()
                                              .toList();
                                          PlaybackService.instance.playTrack(mediaFile, newQueue: folderAudio);
                                        }
                                      },
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),

            // Floating action toolbar for multi-select
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ActionToolbar(
                provider: _selection,
                onAddToPlaylist: _handleAddToPlaylist,
                onMove: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Move: coming soon')),
                ),
                onPlaySelected: () {
                  final selectedFiles = _selection.selectedIds
                      .map((p) => _findMediaFile(p))
                      .whereType<MediaFile>()
                      .toList();
                  if (selectedFiles.isNotEmpty) {
                    _selection.clear();
                    final first = selectedFiles.first;
                    if (first.isVideo) {
                      PlaybackService.instance.navigateToVideo(selectedFiles, first);
                    } else {
                      PlaybackService.instance.playTrack(first, newQueue: selectedFiles);
                    }
                  }
                },
                onDelete: () async {
                  final selectedPaths = _selection.selectedIds.toList();
                  if (selectedPaths.isEmpty) return;
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: PulseColors.surface,
                      title: Text('Delete ${selectedPaths.length} file${selectedPaths.length == 1 ? '' : 's'}?',
                          style: PulseTypography.displayMedium),
                      content: Text(
                        'This will permanently remove the selected files.',
                        style: PulseTypography.bodyLarge.copyWith(color: PulseColors.textSecondary),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Cancel', style: PulseTypography.bodyLarge)),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: PulseColors.danger),
                          child: Text('Delete',
                              style: PulseTypography.bodyLarge.copyWith(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  for (final path in selectedPaths) {
                    try { await File(path).delete(); } catch (_) {}
                  }
                  _selection.clear();
                  if (_currentDir != null) _loadContents(_currentDir!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

