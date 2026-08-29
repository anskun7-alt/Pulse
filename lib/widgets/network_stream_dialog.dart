import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../services/playback_service.dart';
import '../players/video_player_screen.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class NetworkStreamDialog extends StatefulWidget {
  const NetworkStreamDialog({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const NetworkStreamDialog(),
    );
  }

  @override
  State<NetworkStreamDialog> createState() => _NetworkStreamDialogState();
}

class _NetworkStreamDialogState extends State<NetworkStreamDialog> {
  final TextEditingController _urlController = TextEditingController();
  bool _isVideo = true;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _playStream() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final name = url.split('/').last.split('?').first;
    final streamFile = MediaFile(
      id: url,
      path: url,
      title: name.isNotEmpty ? name : 'Network Stream',
      artist: 'Network Stream',
      album: 'Live / Online',
      isVideo: _isVideo,
      duration: Duration.zero,
      size: 0,
      addedDate: DateTime.now(),
    );

    Navigator.of(context).pop();

    if (_isVideo) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(file: streamFile),
        ),
      );
    } else {
      PlaybackService.instance.playTrack(streamFile, newQueue: [streamFile]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PulseColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.stream_rounded, color: PulseColors.accentPrimary),
          const SizedBox(width: 10),
          Text("Open Network Stream", style: PulseTypography.displaySmall),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Enter a network URL (HTTP, HTTPS, HLS .m3u8, or RTSP):",
            style: PulseTypography.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            autofocus: true,
            style: PulseTypography.bodyLarge,
            decoration: InputDecoration(
              hintText: "https://example.com/live/stream.m3u8",
              hintStyle: PulseTypography.bodyMedium,
              filled: true,
              fillColor: PulseColors.surface,
              prefixIcon: const Icon(Icons.link_rounded, size: 20),
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
          const SizedBox(height: 16),
          Row(
            children: [
              ChoiceChip(
                label: const Text("Video Stream"),
                selected: _isVideo,
                onSelected: (val) => setState(() => _isVideo = true),
                selectedColor: PulseColors.accentPrimary.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: _isVideo ? PulseColors.accentPrimary : PulseColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text("Audio Stream"),
                selected: !_isVideo,
                onSelected: (val) => setState(() => _isVideo = false),
                selectedColor: PulseColors.accentPrimary.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: !_isVideo ? PulseColors.accentPrimary : PulseColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Cancel", style: TextStyle(color: PulseColors.textSecondary)),
        ),
        ElevatedButton.icon(
          onPressed: _playStream,
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text("Play Stream"),
          style: ElevatedButton.styleFrom(
            backgroundColor: PulseColors.accentPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
