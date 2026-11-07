import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/media_file.dart';
import '../services/download_service.dart';
import '../services/playback_service.dart';
import '../players/video_player_screen.dart';
import '../players/desktop_video_player.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isVideo = true;
  bool _isResolving = false;
  bool _isGridView = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    DownloadService.instance.init();

    DownloadService.instance.onCompletedStream.listen((task) {
      if (mounted) {
        _showCompletedPlaylistDialog(task);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
      final text = data.text!.trim();
      setState(() {
        _urlController.text = text;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pasted link from clipboard'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _processUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please paste or enter a URL'), backgroundColor: PulseColors.danger),
      );
      return;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please enter a valid HTTP/HTTPS URL'), backgroundColor: PulseColors.danger),
      );
      return;
    }

    setState(() => _isResolving = true);

    try {
      final downloadService = DownloadService.instance;
      final info = await downloadService.resolveMediaUrl(url);

      if (!mounted) return;
      setState(() => _isResolving = false);

      if (info.isPlaylist) {
        _showPlaylistSelectionSheet(info);
      } else if (info.qualityOptions.isNotEmpty) {
        _showQualitySelectionSheet(info);
      } else {
        // Direct media download fallback
        final customName = _nameController.text.trim();
        await downloadService.startDirectDownload(
          url,
          customFileName: customName.isNotEmpty ? customName : null,
          isVideo: _isVideo,
        );
        _urlController.clear();
        _nameController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Direct download started in background'),
            backgroundColor: PulseColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResolving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resolving stream: $e'),
          backgroundColor: PulseColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showQualitySelectionSheet(ResolvedMediaInfo info) {
    MediaQualityOption? selectedOption = info.qualityOptions.first;
    bool isAudioOnlyTab = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final videoOptions = info.qualityOptions.where((q) => !q.isAudioOnly).toList();
          final audioOptions = info.qualityOptions.where((q) => q.isAudioOnly).toList();
          final activeList = isAudioOnlyTab ? audioOptions : videoOptions;

          if (!activeList.contains(selectedOption) && activeList.isNotEmpty) {
            selectedOption = activeList.first;
          }

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PulseColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header with Thumbnail and Title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (info.thumbnailUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            info.thumbnailUrl,
                            width: 100,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 60,
                              color: PulseColors.surfaceHigh,
                              child: const Icon(Icons.video_library_rounded, color: Colors.white54),
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              info.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${info.author} • ${_formatDuration(info.duration)}',
                              style: PulseTypography.bodySmall.copyWith(color: PulseColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Format Tabs (Video / Audio Only)
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              isAudioOnlyTab = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !isAudioOnlyTab ? PulseColors.accentPrimary.withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !isAudioOnlyTab ? PulseColors.accentPrimary : Colors.white12,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.videocam_rounded, size: 18, color: !isAudioOnlyTab ? PulseColors.accentPrimary : Colors.white70),
                                const SizedBox(width: 8),
                                Text(
                                  'Video (${videoOptions.length})',
                                  style: TextStyle(
                                    color: !isAudioOnlyTab ? PulseColors.accentPrimary : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              isAudioOnlyTab = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isAudioOnlyTab ? PulseColors.accentSecondary.withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isAudioOnlyTab ? PulseColors.accentSecondary : Colors.white12,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.audiotrack_rounded, size: 18, color: isAudioOnlyTab ? PulseColors.accentSecondary : Colors.white70),
                                const SizedBox(width: 8),
                                Text(
                                  'Audio (${audioOptions.length})',
                                  style: TextStyle(
                                    color: isAudioOnlyTab ? PulseColors.accentSecondary : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Text('Select Quality:', style: PulseTypography.bodySmall.copyWith(color: PulseColors.textSecondary)),
                  const SizedBox(height: 8),

                  // Quality List
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: activeList.length,
                      itemBuilder: (ctx, i) {
                        final opt = activeList[i];
                        final isSelected = opt == selectedOption;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? PulseColors.surfaceHigh : Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? PulseColors.accentSecondary : Colors.white10,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            onTap: () {
                              setSheetState(() {
                                selectedOption = opt;
                              });
                            },
                            leading: Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? PulseColors.accentSecondary : Colors.white54,
                            ),
                            title: Text(opt.label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                            trailing: Text(
                              opt.sizeString,
                              style: TextStyle(color: PulseColors.textSecondary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Download Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PulseColors.accentPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: selectedOption == null
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              final customName = _nameController.text.trim();
                              DownloadService.instance.startYoutubeDownload(
                                info: info,
                                selectedQuality: selectedOption!,
                                customFileName: customName.isNotEmpty ? customName : null,
                              );
                              _urlController.clear();
                              _nameController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Downloading "${info.title}" in background'),
                                  backgroundColor: PulseColors.success,
                                ),
                              );
                            },
                      icon: const Icon(Icons.download_rounded),
                      label: Text(
                        'Download ${selectedOption != null ? "(${selectedOption!.label})" : ""}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPlaylistSelectionSheet(ResolvedMediaInfo info) {
    final videos = info.playlistVideos ?? [];
    bool audioOnly = false;
    String preferredQuality = '720p';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final selectedCount = videos.where((v) => v.isSelected).length;

          return Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: PulseColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.playlist_play_rounded, color: Colors.orangeAccent, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        info.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${videos.length} videos found • $selectedCount selected',
                  style: PulseTypography.bodySmall.copyWith(color: PulseColors.textSecondary),
                ),
                const SizedBox(height: 12),

                // Controls: Select All & Audio/Video mode
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setSheetState(() {
                          final allSelected = selectedCount == videos.length;
                          for (var v in videos) {
                            v.isSelected = !allSelected;
                          }
                        });
                      },
                      icon: Icon(selectedCount == videos.length ? Icons.deselect_rounded : Icons.select_all_rounded, size: 18),
                      label: Text(selectedCount == videos.length ? 'Deselect All' : 'Select All'),
                    ),
                    const Spacer(),
                    ChoiceChip(
                      label: const Text('Video'),
                      selected: !audioOnly,
                      onSelected: (val) => setSheetState(() => audioOnly = !val),
                      selectedColor: PulseColors.accentPrimary,
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Audio Only'),
                      selected: audioOnly,
                      onSelected: (val) => setSheetState(() => audioOnly = val),
                      selectedColor: PulseColors.accentSecondary,
                    ),
                  ],
                ),
                const Divider(color: Colors.white12),

                // Video Checklist
                Expanded(
                  child: ListView.builder(
                    itemCount: videos.length,
                    itemBuilder: (ctx, idx) {
                      final item = videos[idx];
                      return CheckboxListTile(
                        value: item.isSelected,
                        activeColor: PulseColors.accentSecondary,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setSheetState(() {
                            item.isSelected = val ?? false;
                          });
                        },
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${item.author} • ${_formatDuration(item.duration)}',
                          style: TextStyle(color: PulseColors.textSecondary, fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Download All Selected Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PulseColors.accentPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: selectedCount == 0
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            DownloadService.instance.startPlaylistDownload(
                              selectedVideos: videos,
                              audioOnly: audioOnly,
                              preferredQuality: preferredQuality,
                            );
                            _urlController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Queued $selectedCount playlist items for download'),
                                backgroundColor: PulseColors.success,
                              ),
                            );
                          },
                    icon: const Icon(Icons.download_rounded),
                    label: Text('Download $selectedCount Selected Items', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _previewOrPlay(DownloadTask task) {
    final playable = DownloadService.instance.getPlayableFile(task);
    final file = File(playable.path);
    if (!file.existsSync() || file.lengthSync() == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough data downloaded yet to preview')),
      );
      return;
    }

    if (playable.isVideo) {
      if (Platform.isWindows) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DesktopVideoPlayerScreen(file: playable),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(file: playable),
          ),
        );
      }
    } else {
      PlaybackService.instance.playTrack(playable, newQueue: [playable]);
    }
  }

  void _showCompletedPlaylistDialog(DownloadTask task) {
    final playable = DownloadService.instance.getPlayableFile(task);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddToPlaylistSheet(
        mediaFile: playable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Downloads & Links", style: PulseTypography.displayMedium),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded, color: Colors.white70),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: PulseColors.accentSecondary,
          labelColor: PulseColors.accentSecondary,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "Active Downloads"),
            Tab(text: "Completed"),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Download from URL Input Box ────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PulseColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Download from URL', style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: _pasteFromClipboard,
                      icon: const Icon(Icons.paste_rounded, size: 16),
                      label: const Text('Paste'),
                      style: TextButton.styleFrom(foregroundColor: PulseColors.accentSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Paste YouTube video, playlist, or direct media link...',
                    hintStyle: TextStyle(color: PulseColors.textSecondary.withValues(alpha: 0.6), fontSize: 12),
                    prefixIcon: const Icon(Icons.link_rounded, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Custom File Name (optional)',
                          hintStyle: TextStyle(color: PulseColors.textSecondary.withValues(alpha: 0.6), fontSize: 12),
                          prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.white54),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PulseColors.accentPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isResolving ? null : _processUrl,
                        child: _isResolving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Row(
                                children: [
                                  Icon(Icons.download_rounded, size: 18),
                                  SizedBox(width: 6),
                                  Text('Start Download', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Downloads Tab View ─────────────────────────────────────────────
          Expanded(
            child: ValueListenableBuilder<List<DownloadTask>>(
              valueListenable: DownloadService.instance.tasks,
              builder: (context, allTasks, child) {
                final activeTasks = allTasks.where((t) => t.status != DownloadStatus.completed).toList();
                final completedTasks = allTasks.where((t) => t.status == DownloadStatus.completed).toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTaskList(activeTasks, isActiveTab: true),
                    _buildTaskList(completedTasks, isActiveTab: false),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<DownloadTask> taskList, {required bool isActiveTab}) {
    if (taskList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActiveTab ? Icons.cloud_download_outlined : Icons.check_circle_outline_rounded,
              size: 64,
              color: Colors.white24,
            ),
            const SizedBox(height: 12),
            Text(
              isActiveTab ? 'No active downloads' : 'No completed downloads yet',
              style: PulseTypography.bodyLarge.copyWith(color: PulseColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              isActiveTab ? 'Paste a link above to begin downloading' : 'Downloaded files will appear here',
              style: PulseTypography.bodySmall.copyWith(color: PulseColors.textSecondary.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: taskList.length,
      itemBuilder: (context, index) {
        final task = taskList[index];
        return _buildTaskCard(task);
      },
    );
  }

  Widget _buildTaskCard(DownloadTask task) {
    final isDownloading = task.status == DownloadStatus.downloading;
    final isPaused = task.status == DownloadStatus.paused;
    final isCompleted = task.status == DownloadStatus.completed;
    final isFailed = task.status == DownloadStatus.failed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PulseColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? PulseColors.success.withValues(alpha: 0.3)
              : (isFailed ? PulseColors.danger.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon or Thumbnail
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: task.isVideo ? Colors.deepPurple.withValues(alpha: 0.2) : Colors.pink.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  task.isVideo ? Icons.movie_rounded : Icons.audiotrack_rounded,
                  color: task.isVideo ? PulseColors.accentSecondary : PulseColors.accentPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Title and speed info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCompleted
                          ? 'Downloaded • ${task.sizeString}'
                          : (isDownloading
                              ? '${task.speedString} • ${task.sizeString}'
                              : (isPaused ? 'Paused • ${task.sizeString}' : (task.error ?? 'Failed'))),
                      style: TextStyle(
                        fontSize: 11,
                        color: isFailed ? PulseColors.danger : PulseColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons
              if (isDownloading)
                IconButton(
                  icon: const Icon(Icons.pause_rounded, color: Colors.amber),
                  onPressed: () => DownloadService.instance.pauseDownload(task.id),
                ),
              if (isPaused)
                IconButton(
                  icon: Icon(Icons.play_arrow_rounded, color: PulseColors.accentSecondary),
                  onPressed: () => DownloadService.instance.resumeDownload(task.id),
                ),
              if (isFailed)
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: PulseColors.danger),
                  onPressed: () => DownloadService.instance.retryDownload(task.id),
                ),
              if (isCompleted)
                IconButton(
                  icon: Icon(Icons.play_circle_filled_rounded, color: PulseColors.success, size: 28),
                  onPressed: () => _previewOrPlay(task),
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                onPressed: () => DownloadService.instance.cancelAndDeleteDownload(task.id),
              ),
            ],
          ),

          if (!isCompleted) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.totalBytes > 0 ? task.progress : null,
                minHeight: 4,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isFailed ? PulseColors.danger : PulseColors.accentSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
