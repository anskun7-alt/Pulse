// Updated JustAudioBackground initialization to set androidStopForegroundOnPause to false
// File: e:/GMWF/media_player/lib/main.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'dart:io';
import 'app.dart';
import 'services/media_scanner.dart';
import 'services/playlist_service.dart';
import 'services/playback_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.pulse.audio_playback',
        androidNotificationChannelName: 'Pulse Media Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false, // Updated per user request
        fastForwardInterval: const Duration(seconds: 5),
        rewindInterval: const Duration(seconds: 5),
        androidShowNotificationBadge: true,
      );
    } catch (e) {
      debugPrint('JustAudioBackground init error: $e');
    }
  }

  // Initialize local Hive database caching systems
  await Hive.initFlutter();

  try {
    // Pre-open system preferences/settings cache
    await Hive.openBox('settings_box');
  } catch (e) {
    debugPrint('Failed to open settings_box, deleting and retrying: $e');
    await Hive.deleteBoxFromDisk('settings_box');
    await Hive.openBox('settings_box');
  }

  try {
    // Boot strap core application services
    await MediaScanner.instance.init();
    await PlaylistService.instance.init();
  } catch (e, stackTrace) {
    debugPrint('Initialization error: $e\n$stackTrace');
    // UI will still render
  }

  runApp(const PulseApp());

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await PlaybackService.instance.init();
    } catch (e, stackTrace) {
      debugPrint('PlaybackService initialization error: $e\n$stackTrace');
    }
  });
}
