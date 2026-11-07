import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'playback_service.dart';
import 'media_scanner.dart';

class ShortcutItem {
  final String id;
  final String action;
  final String keys;
  final String category;
  final String? description;

  const ShortcutItem({
    required this.id,
    required this.action,
    required this.keys,
    required this.category,
    this.description,
  });

  ShortcutItem copyWith({String? keys}) {
    return ShortcutItem(
      id: id,
      action: action,
      keys: keys ?? this.keys,
      category: category,
      description: description,
    );
  }
}

class PulseShortcuts {
  static final ValueNotifier<Map<String, String>> customBindingsNotifier =
      ValueNotifier<Map<String, String>>({});

  static void init() {
    try {
      final box = Hive.box('settings_box');
      final dynamic raw = box.get('custom_shortcuts');
      if (raw is Map) {
        customBindingsNotifier.value = Map<String, String>.from(raw);
      }
    } catch (_) {}
  }

  static Future<void> saveBinding(String id, String newKey) async {
    final updated = Map<String, String>.from(customBindingsNotifier.value);
    updated[id] = newKey.trim();
    customBindingsNotifier.value = updated;
    try {
      final box = Hive.box('settings_box');
      await box.put('custom_shortcuts', updated);
    } catch (_) {}
  }

  static Future<void> resetAllBindings() async {
    customBindingsNotifier.value = {};
    try {
      final box = Hive.box('settings_box');
      await box.delete('custom_shortcuts');
    } catch (_) {}
  }

  static bool hasCustom(String id) => customBindingsNotifier.value.containsKey(id);

  static String getKeyFor(String id) {
    if (customBindingsNotifier.value.containsKey(id)) {
      return customBindingsNotifier.value[id]!;
    }
    final match = desktopShortcuts.firstWhere(
      (s) => s.id == id,
      orElse: () => const ShortcutItem(id: '', action: '', keys: '', category: ''),
    );
    return match.keys;
  }

  static List<ShortcutItem> getActiveShortcuts() {
    final customs = customBindingsNotifier.value;
    return desktopShortcuts.map((item) {
      if (customs.containsKey(item.id)) {
        return item.copyWith(keys: customs[item.id]!);
      }
      return item;
    }).toList();
  }

  static bool matches(LogicalKeyboardKey key, bool isCtrl, String actionId) {
    final customKey = getKeyFor(actionId).trim().toLowerCase();
    final label = key.keyLabel.toLowerCase();
    final debugName = (key.debugName ?? '').toLowerCase();

    if (customKey.contains('ctrl')) {
      if (!isCtrl) return false;
      final stripped = customKey.replaceAll('ctrl', '').replaceAll('+', '').trim();
      return _keyMatches(stripped, label, debugName, key);
    }

    if (isCtrl) return false;
    return _keyMatches(customKey, label, debugName, key);
  }

  static bool _keyMatches(String target, String label, String debugName, LogicalKeyboardKey key) {
    if (target.isEmpty) return false;
    if (target == 'space' && key == LogicalKeyboardKey.space) return true;
    if ((target == 'arrow right' || target == '→' || target == 'right') && key == LogicalKeyboardKey.arrowRight) return true;
    if ((target == 'arrow left' || target == '←' || target == 'left') && key == LogicalKeyboardKey.arrowLeft) return true;
    if ((target == 'arrow up' || target == '↑' || target == 'up') && key == LogicalKeyboardKey.arrowUp) return true;
    if ((target == 'arrow down' || target == '↓' || target == 'down') && key == LogicalKeyboardKey.arrowDown) return true;
    if (target == 'escape' && key == LogicalKeyboardKey.escape) return true;
    if (target == 'enter' && key == LogicalKeyboardKey.enter) return true;
    if (target == label) return true;
    if (debugName.contains(target)) return true;
    return false;
  }

  static const List<ShortcutItem> desktopShortcuts = [
    // Playback Controls
    ShortcutItem(id: 'play_pause', action: 'Play / Pause', keys: 'Space', category: 'Playback', description: 'Toggle video or music playback'),
    ShortcutItem(id: 'next_track', action: 'Next Track', keys: 'N', category: 'Playback', description: 'Skip to next item in playlist'),
    ShortcutItem(id: 'prev_track', action: 'Previous Track', keys: 'P', category: 'Playback', description: 'Return to previous track'),
    ShortcutItem(id: 'speed_up', action: 'Speed Up (+0.25x)', keys: ']', category: 'Playback', description: 'Increase playback speed rate'),
    ShortcutItem(id: 'speed_down', action: 'Slow Down (-0.25x)', keys: '[', category: 'Playback', description: 'Decrease playback speed rate'),
    ShortcutItem(id: 'speed_normal', action: 'Normal Speed (1.0x)', keys: '=', category: 'Playback', description: 'Reset playback speed to 1.0x'),
    ShortcutItem(id: 'loop', action: 'A-B Loop Repeat', keys: 'L', category: 'Playback', description: 'Set loop start, end, and toggle repeating segment'),

    // Seeking & Navigation
    ShortcutItem(id: 'seek_fwd_5', action: 'Seek Forward 5s', keys: '→', category: 'Seeking', description: 'Jump forward 5 seconds'),
    ShortcutItem(id: 'seek_back_5', action: 'Seek Backward 5s', keys: '←', category: 'Seeking', description: 'Jump backward 5 seconds'),
    ShortcutItem(id: 'seek_fwd_30', action: 'Seek Forward 30s', keys: 'Ctrl + →', category: 'Seeking', description: 'Large jump forward 30 seconds'),
    ShortcutItem(id: 'seek_back_30', action: 'Seek Backward 30s', keys: 'Ctrl + ←', category: 'Seeking', description: 'Large jump backward 30 seconds'),
    ShortcutItem(id: 'jump_start', action: 'Jump to Start', keys: 'Home', category: 'Seeking', description: 'Restart media from 00:00'),
    ShortcutItem(id: 'jump_end', action: 'Jump to End', keys: 'End', category: 'Seeking', description: 'Jump to the end of media'),

    // Audio & Volume
    ShortcutItem(id: 'vol_up', action: 'Volume Up (+5%)', keys: '↑', category: 'Audio', description: 'Increase audio output level'),
    ShortcutItem(id: 'vol_down', action: 'Volume Down (-5%)', keys: '↓', category: 'Audio', description: 'Decrease audio output level'),
    ShortcutItem(id: 'toggle_mute', action: 'Toggle Mute', keys: 'M', category: 'Audio', description: 'Silence audio output completely'),
    ShortcutItem(id: 'cycle_audio', action: 'Cycle Audio Track', keys: 'B', category: 'Audio', description: 'Switch between multi-language audio streams'),

    // Subtitles
    ShortcutItem(id: 'cycle_subs', action: 'Cycle Subtitles', keys: 'V / C', category: 'Subtitles', description: 'Toggle / switch available subtitle tracks'),
    ShortcutItem(id: 'sub_delay', action: 'Subtitle Delay (+50ms)', keys: 'H', category: 'Subtitles', description: 'Delay subtitle timing forward'),
    ShortcutItem(id: 'sub_advance', action: 'Subtitle Advance (-50ms)', keys: 'G', category: 'Subtitles', description: 'Advance subtitle timing backward'),
    ShortcutItem(id: 'sub_reset', action: 'Reset Subtitle Sync', keys: 'J', category: 'Subtitles', description: 'Reset subtitle sync timing to 0ms'),

    // Video & Display
    ShortcutItem(id: 'cycle_video', action: 'Cycle Video Track', keys: 'T', category: 'Video', description: 'Toggle / switch available video streams and qualities'),
    ShortcutItem(id: 'fullscreen', action: 'Toggle Fullscreen', keys: 'F', category: 'Video', description: 'Enter or exit fullscreen video mode'),
    ShortcutItem(id: 'aspect_ratio', action: 'Cycle Aspect Ratio', keys: 'A', category: 'Video', description: 'Switch between Fit, Fill, Stretch, and 16:9'),
    ShortcutItem(id: 'rotate_video', action: 'Rotate Video (90°)', keys: 'R', category: 'Video', description: 'Rotate video 90 degrees clockwise'),
    ShortcutItem(id: 'snapshot', action: 'Take Snapshot', keys: 'S', category: 'Video', description: 'Capture frame-accurate image snapshot'),
    ShortcutItem(id: 'stats', action: 'Media Stats / Codec', keys: 'Ctrl + J', category: 'Video', description: 'Show video resolution, bitrate, & codec info'),

    // System & Open
    ShortcutItem(id: 'open_file', action: 'Open File', keys: 'Ctrl + O', category: 'System', description: 'Browse and open media file from disk'),
    ShortcutItem(id: 'open_network', action: 'Open Network Stream', keys: 'Ctrl + N', category: 'System', description: 'Stream video or audio from URL (HLS / RTSP)'),
    ShortcutItem(id: 'shortcuts_guide', action: 'Shortcuts Guide', keys: '?', category: 'System', description: 'Display all keyboard shortcuts & controls'),
  ];

  static const List<ShortcutItem> mobileGestures = [
    ShortcutItem(id: 'g_swipe', action: 'Swipe Left / Right', keys: 'Center Drag', category: 'Playback Gestures', description: 'Smooth seek forward / backward'),
    ShortcutItem(id: 'g_dt_right', action: 'Double Tap Right', keys: '2x Tap Right', category: 'Playback Gestures', description: 'Jump +10 seconds forward'),
    ShortcutItem(id: 'g_dt_left', action: 'Double Tap Left', keys: '2x Tap Left', category: 'Playback Gestures', description: 'Jump -10 seconds backward'),
    ShortcutItem(id: 'g_hold', action: 'Long Press', keys: 'Hold Screen', category: 'Playback Gestures', description: 'Turbo 2x speed playback while held'),
    ShortcutItem(id: 'g_left_swipe', action: 'Left Edge Swipe', keys: 'Vertical Drag Left', category: 'Controls', description: 'Adjust screen brightness smoothly'),
    ShortcutItem(id: 'g_right_swipe', action: 'Right Edge Swipe', keys: 'Vertical Drag Right', category: 'Controls', description: 'Adjust volume smoothly'),
    ShortcutItem(id: 'g_pinch', action: 'Pinch to Zoom', keys: '2-Finger Pinch', category: 'Video Scale', description: 'Freely zoom and pan video frame'),
  ];

  /// Handles desktop keyboard events
  static void handleKeyEvent(
    KeyEvent event,
    BuildContext context, {
    VoidCallback? onOpenNetworkStream,
    VoidCallback? onOpenFile,
    VoidCallback? onToggleSubtitles,
    VoidCallback? onCycleAudioTrack,
    VoidCallback? onCycleVideoTrack,
    VoidCallback? onToggleFullscreen,
    VoidCallback? onCycleAspectRatio,
    VoidCallback? onRotateVideo,
    VoidCallback? onTakeSnapshot,
    VoidCallback? onToggleStats,
  }) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;
    final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;

    // Space: Play/Pause
    if (key == LogicalKeyboardKey.space) {
      PlaybackService.instance.togglePlayPause();
    }
    // Arrows: Seeking
    else if (key == LogicalKeyboardKey.arrowRight) {
      final pos = PlaybackService.instance.position.value;
      final step = isCtrl ? const Duration(seconds: 30) : const Duration(seconds: 5);
      PlaybackService.instance.seek(pos + step);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      final pos = PlaybackService.instance.position.value;
      final step = isCtrl ? const Duration(seconds: 30) : const Duration(seconds: 5);
      final newPos = pos - step;
      PlaybackService.instance.seek(newPos < Duration.zero ? Duration.zero : newPos);
    }
    // Up / Down: Volume
    else if (key == LogicalKeyboardKey.arrowUp) {
      final currentVol = PlaybackService.instance.volumeScale.value;
      PlaybackService.instance.setVolumeScale((currentVol + 0.05).clamp(0.0, 1.0));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      final currentVol = PlaybackService.instance.volumeScale.value;
      PlaybackService.instance.setVolumeScale((currentVol - 0.05).clamp(0.0, 1.0));
    }
    // M: Mute
    else if (key == LogicalKeyboardKey.keyM) {
      final currentVol = PlaybackService.instance.volumeScale.value;
      if (currentVol > 0.0) {
        PlaybackService.instance.setVolumeScale(0.0);
      } else {
        PlaybackService.instance.setVolumeScale(1.0);
      }
    }
    // N / P: Next / Previous
    else if (key == LogicalKeyboardKey.keyN && !isCtrl) {
      PlaybackService.instance.playNext();
    } else if (key == LogicalKeyboardKey.keyP && !isCtrl) {
      PlaybackService.instance.playPrevious();
    }
    // [ / ]: Speed
    else if (key == LogicalKeyboardKey.bracketRight) {
      final speed = PlaybackService.instance.player.speed;
      PlaybackService.instance.setPlaybackSpeed((speed + 0.25).clamp(0.25, 3.0));
    } else if (key == LogicalKeyboardKey.bracketLeft) {
      final speed = PlaybackService.instance.player.speed;
      PlaybackService.instance.setPlaybackSpeed((speed - 0.25).clamp(0.25, 3.0));
    } else if (key == LogicalKeyboardKey.equal) {
      PlaybackService.instance.setPlaybackSpeed(1.0);
    }
    // B: Audio track switch
    else if (key == LogicalKeyboardKey.keyB && !isCtrl) {
      if (onCycleAudioTrack != null) onCycleAudioTrack();
    }
    // T: Video track switch
    else if (key == LogicalKeyboardKey.keyT && !isCtrl) {
      if (onCycleVideoTrack != null) onCycleVideoTrack();
    }
    // V / C: Subtitles switch
    else if ((key == LogicalKeyboardKey.keyV || key == LogicalKeyboardKey.keyC) && !isCtrl) {
      if (onToggleSubtitles != null) onToggleSubtitles();
    }
    // F: Fullscreen
    else if (key == LogicalKeyboardKey.keyF && !isCtrl) {
      if (onToggleFullscreen != null) onToggleFullscreen();
    }
    // A: Aspect Ratio
    else if (key == LogicalKeyboardKey.keyA && !isCtrl) {
      if (onCycleAspectRatio != null) onCycleAspectRatio();
    }
    // R: Rotate
    else if (key == LogicalKeyboardKey.keyR && !isCtrl) {
      if (onRotateVideo != null) onRotateVideo();
    }
    // S: Screenshot Snapshot
    else if (key == LogicalKeyboardKey.keyS && !isCtrl) {
      if (onTakeSnapshot != null) onTakeSnapshot();
    }
    // Ctrl + J: Media Stats
    else if (isCtrl && key == LogicalKeyboardKey.keyJ) {
      if (onToggleStats != null) onToggleStats();
    }
    // Ctrl + N: Network Stream
    else if (isCtrl && key == LogicalKeyboardKey.keyN) {
      if (onOpenNetworkStream != null) onOpenNetworkStream();
    }
    // Ctrl + O: Open file
    else if (isCtrl && key == LogicalKeyboardKey.keyO) {
      if (onOpenFile != null) {
        onOpenFile();
      } else {
        MediaScanner.instance.pickAndAddCustomFolder();
      }
    }
  }
}
