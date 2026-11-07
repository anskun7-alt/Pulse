import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:io';
import 'theme/logo.dart';
import 'services/avatar_service.dart';
import 'app.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // MediaKit is only for Windows/Linux/macOS desktop builds; do NOT initialize on Android where libmpv is absent
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    try {
      MediaKit.ensureInitialized();
    } catch (e) {
      debugPrint('MediaKit init error: $e');
    }
  }

  // Parse command line arguments for Windows "Open with" file paths
  String? initialFilePath;
  if (args.isNotEmpty) {
    for (final arg in args) {
      final clean = arg.replaceAll('"', '').trim();
      if (clean.isNotEmpty && !clean.startsWith('--')) {
        try {
          if (File(clean).existsSync()) {
            initialFilePath = clean;
            break;
          }
        } catch (_) {}
      }
    }
  }

  // Initialize local Hive database caching systems first so settings/theme are available
  try {
    await Hive.initFlutter();
  } catch (e) {
    debugPrint('Hive.initFlutter error: $e');
  }

  try {
    await Hive.openBox('settings_box');
  } catch (e) {
    debugPrint('Failed to open settings_box, deleting and retrying: $e');
    try {
      await Hive.deleteBoxFromDisk('settings_box');
      await Hive.openBox('settings_box');
    } catch (_) {}
  }

  PulseLogo.init();
  AvatarService.instance.init();

  if (Platform.isAndroid) {
    try {
      const themeColor = Color(0xFF818CF8);
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.pulse.audio_playback',
        androidNotificationChannelName: 'Pulse Media Playback',
        androidNotificationIcon: 'drawable/ic_notification',
        notificationColor: themeColor,
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
        androidNotificationClickStartsActivity: true,
        artDownscaleWidth: 512,
        artDownscaleHeight: 512,
        fastForwardInterval: const Duration(seconds: 10),
        rewindInterval: const Duration(seconds: 10),
        androidShowNotificationBadge: true,
      );
    } catch (e) {
      debugPrint('JustAudioBackground init error: $e');
    }
  }

  // Launch UI immediately
  runApp(PulseApp(initialFilePath: initialFilePath));
}
