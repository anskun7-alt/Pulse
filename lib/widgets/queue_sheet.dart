import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/media_file.dart';
import '../services/playback_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'animated_widgets.dart';

class QueueBottomSheet extends StatefulWidget {
  const QueueBottomSheet({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QueueBottomSheet(),
    );
  }

  @override
  State<QueueBottomSheet> createState() => _QueueBottomSheetState();
}

class _QueueBottomSheetState extends State<QueueBottomSheet> {
  final _playback = PlaybackService.instance;

  @override
  Widget build(BuildContext context) {
    final primary = PulseColors.accentPrimary;
    final secondary = PulseColors.accentSecondary;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            color: PulseColors.surface.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: primary.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              // Top drag pill
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),

              // Queue Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primary.withValues(alpha: 0.2), secondary.withValues(alpha: 0.2)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.queue_music_rounded, color: primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Playing Queue',
                              style: PulseTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            ValueListenableBuilder<List<MediaFile>>(
                              valueListenable: _playback.queue,
                              builder: (context, q, _) => Text(
                                '${q.length} tracks',
                                style: PulseTypography.bodySmall.copyWith(color: PulseColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Clear queue button
                    TextButton.icon(
                      onPressed: () {
                        _playback.queue.value = [];
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.clear_all_rounded, color: PulseColors.danger, size: 18),
                      label: Text('Clear', style: TextStyle(color: PulseColors.danger, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white12, height: 1),

              // Queue List
              Expanded(
                child: ValueListenableBuilder<List<MediaFile>>(
                  valueListenable: _playback.queue,
                  builder: (context, queue, _) {
                    if (queue.isEmpty) {
                      return const PulseEmptyState(
                        icon: Icons.music_off_rounded,
                        title: 'Queue is Empty',
                        subtitle: 'Add tracks to the queue to keep the music playing.',
                      );
                    }

                    return ValueListenableBuilder<int>(
                      valueListenable: _playback.queueIndex,
                      builder: (context, activeIdx, _) {
                        return ReorderableListView.builder(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 40),
                          itemCount: queue.length,
                          onReorder: (oldIndex, newIndex) {
                            if (oldIndex < newIndex) newIndex -= 1;
                            final list = List<MediaFile>.from(queue);
                            final item = list.removeAt(oldIndex);
                            list.insert(newIndex, item);
                            _playback.queue.value = list;
                          },
                          itemBuilder: (context, index) {
                            final track = queue[index];
                            final isPlaying = index == activeIdx;

                            return Container(
                              key: ValueKey(track.path + index.toString()),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: isPlaying
                                    ? primary.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPlaying ? primary.withValues(alpha: 0.35) : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    color: PulseColors.surfaceHigh,
                                    child: track.albumArtPath != null && track.albumArtPath!.isNotEmpty
                                        ? Image.file(
                                            File(track.albumArtPath!),
                                            fit: BoxFit.cover,
                                            cacheWidth: 100,
                                            cacheHeight: 100,
                                            errorBuilder: (_, __, ___) => Icon(Icons.music_note_rounded, color: primary),
                                          )
                                        : Icon(Icons.music_note_rounded, color: primary),
                                  ),
                                ),
                                title: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PulseTypography.bodyLarge.copyWith(
                                    fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                                    color: isPlaying ? primary : Colors.white,
                                  ),
                                ),
                                subtitle: Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PulseTypography.bodySmall.copyWith(color: PulseColors.textSecondary),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPlaying) ...[
                                      ValueListenableBuilder<bool>(
                                        valueListenable: _playback.isPlaying,
                                        builder: (_, playing, __) => PulseEqualizerBars(isPlaying: playing),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(Icons.drag_handle_rounded, color: Colors.white38),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  _playback.playTrack(track, newQueue: queue);
                                },
                              ),
                            );
                          },
                        );
                      },
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
