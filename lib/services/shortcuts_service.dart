import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'playback_service.dart';

class ShortcutItem {
  final String action;
  final String keys;
  final String category;
  final String? description;

  const ShortcutItem({
    required this.action,
    required this.keys,
    required this.category,
    this.description,
  });
}

class PulseShortcuts {
  static const List<ShortcutItem> desktopShortcuts = [
    // Playback
    ShortcutItem(action: 'Play / Pause', keys: 'Space', category: 'Playback', description: 'Toggle video or music playback'),
    ShortcutItem(action: 'Next Track', keys: 'N', category: 'Playback', description: 'Skip to next item in queue'),
    ShortcutItem(action: 'Previous Track', keys: 'P', category: 'Playback', description: 'Go to previous track or start'),
    ShortcutItem(action: 'Speed Up (+0.25x)', keys: ']', category: 'Playback', description: 'Increase playback rate'),
    ShortcutItem(action: 'Slow Down (-0.25x)', keys: '[', category: 'Playback', description: 'Decrease playback rate'),
    ShortcutItem(action: 'Normal Speed (1.0x)', keys: '=', category: 'Playback', description: 'Reset playback speed to normal'),

    // Navigation & Seeking
    ShortcutItem(action: 'Seek Forward 5s', keys: '→', category: 'Navigation', description: 'Jump forward 5 seconds'),
    ShortcutItem(action: 'Seek Backward 5s', keys: '←', category: 'Navigation', description: 'Jump backward 5 seconds'),
    ShortcutItem(action: 'Seek Forward 30s', keys: 'Ctrl + →', category: 'Navigation', description: 'Large step jump forward'),
    ShortcutItem(action: 'Seek Backward 30s', keys: 'Ctrl + ←', category: 'Navigation', description: 'Large step jump backward'),
    ShortcutItem(action: 'Jump to Start', keys: 'Home', category: 'Navigation', description: 'Restart media from 0:00'),

    // Volume & Audio
    ShortcutItem(action: 'Volume Up (+5%)', keys: '↑', category: 'Audio', description: 'Increase audio volume'),
    ShortcutItem(action: 'Volume Down (-5%)', keys: '↓', category: 'Audio', description: 'Decrease audio volume'),
    ShortcutItem(action: 'Toggle Mute', keys: 'M', category: 'Audio', description: 'Silence audio output'),

    // Subtitles & Video
    ShortcutItem(action: 'Toggle Fullscreen', keys: 'F', category: 'Video', description: 'Enter or exit fullscreen'),
    ShortcutItem(action: 'Toggle Subtitles', keys: 'V', category: 'Video', description: 'Switch subtitle tracks on / off'),
    ShortcutItem(action: 'Cycle Aspect Ratio', keys: 'A', category: 'Video', description: 'Fit / Fill / Stretch / 16:9'),
    ShortcutItem(action: 'Rotate Video (90°)', keys: 'R', category: 'Video', description: 'Rotate orientation clockwise'),

    // System & Open
    ShortcutItem(action: 'Open File', keys: 'Ctrl + O', category: 'System', description: 'Browse and open media file'),
    ShortcutItem(action: 'Open Network Stream', keys: 'Ctrl + N', category: 'System', description: 'Stream from URL / HLS / RTSP'),
    ShortcutItem(action: 'Shortcuts Cheat Sheet', keys: '?', category: 'System', description: 'Show keyboard shortcuts guide'),
  ];

  static const List<ShortcutItem> mobileGestures = [
    ShortcutItem(action: 'Swipe Left / Right', keys: 'Center Drag', category: 'Playback Gestures', description: 'Smooth seek forward / backward'),
    ShortcutItem(action: 'Double Tap Right', keys: '2x Tap Right', category: 'Playback Gestures', description: 'Jump +10 seconds forward'),
    ShortcutItem(action: 'Double Tap Left', keys: '2x Tap Left', category: 'Playback Gestures', description: 'Jump -10 seconds backward'),
    ShortcutItem(action: 'Long Press', keys: 'Hold Screen', category: 'Playback Gestures', description: 'Turbo 2x speed playback while held'),
    ShortcutItem(action: 'Left Edge Swipe', keys: 'Vertical Drag Left', category: 'Controls', description: 'Adjust screen brightness smoothly'),
    ShortcutItem(action: 'Right Edge Swipe', keys: 'Vertical Drag Right', category: 'Controls', description: 'Adjust volume smoothly'),
    ShortcutItem(action: 'Pinch to Zoom', keys: '2-Finger Pinch', category: 'Video Scale', description: 'Freely zoom and pan video frame'),
  ];

  /// Handles desktop keyboard events
  static void handleKeyEvent(KeyEvent event, BuildContext context, {VoidCallback? onOpenNetworkStream}) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;
    final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;

    if (key == LogicalKeyboardKey.space) {
      PlaybackService.instance.togglePlayPause();
    } else if (key == LogicalKeyboardKey.arrowRight) {
      final pos = PlaybackService.instance.position.value;
      final step = isCtrl ? const Duration(seconds: 30) : const Duration(seconds: 5);
      PlaybackService.instance.seek(pos + step);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      final pos = PlaybackService.instance.position.value;
      final step = isCtrl ? const Duration(seconds: 30) : const Duration(seconds: 5);
      final newPos = pos - step;
      PlaybackService.instance.seek(newPos < Duration.zero ? Duration.zero : newPos);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      final currentVol = PlaybackService.instance.volumeScale.value;
      PlaybackService.instance.setVolumeScale((currentVol + 0.05).clamp(0.0, 1.0));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      final currentVol = PlaybackService.instance.volumeScale.value;
      PlaybackService.instance.setVolumeScale((currentVol - 0.05).clamp(0.0, 1.0));
    } else if (key == LogicalKeyboardKey.keyM) {
      final currentVol = PlaybackService.instance.volumeScale.value;
      if (currentVol > 0.0) {
        PlaybackService.instance.setVolumeScale(0.0);
      } else {
        PlaybackService.instance.setVolumeScale(1.0);
      }
    } else if (key == LogicalKeyboardKey.keyN && !isCtrl) {
      PlaybackService.instance.playNext();
    } else if (key == LogicalKeyboardKey.keyP && !isCtrl) {
      PlaybackService.instance.playPrevious();
    } else if (isCtrl && key == LogicalKeyboardKey.keyN) {
      if (onOpenNetworkStream != null) {
        onOpenNetworkStream();
      }
    }
  }
}
