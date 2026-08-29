import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../models/media_file.dart';
import 'metadata_service.dart';
import 'playlist_service.dart';

class IsolateScanParams {
  final List<String> rootPaths;
  final bool showHidden;
  final List<String> excludedFolders;
  final List<String> audioExtensions;
  final List<String> videoExtensions;

  IsolateScanParams({
    required this.rootPaths,
    required this.showHidden,
    required this.excludedFolders,
    required this.audioExtensions,
    required this.videoExtensions,
  });
}

List<String> _performScanSync(IsolateScanParams params) {
  final List<String> foundPaths = [];
  for (var rootPath in params.rootPaths) {
    try {
      final rootDir = Directory(rootPath);
      if (rootDir.existsSync()) {
        _searchDirSync(rootDir, foundPaths, params);
      }
    } catch (_) {}
  }
  return foundPaths;
}

void _searchDirSync(Directory dir, List<String> foundPaths, IsolateScanParams params) {
  try {
    final entities = dir.listSync(recursive: false, followLinks: false);
    for (final entity in entities) {
      final path = entity.path;
      final name = path.split(Platform.pathSeparator).last;

      if (!params.showHidden && name.startsWith('.')) continue;
      if (params.excludedFolders.any((ex) => path.startsWith(ex))) continue;

      if (entity is Directory) {
        if (name == 'Android' || name == 'data' || name == 'obb' || name == 'LOST.DIR') continue;
        _searchDirSync(entity, foundPaths, params);
      } else if (entity is File) {
        final ext = name.split('.').last.toLowerCase();
        if (params.audioExtensions.contains(ext) || params.videoExtensions.contains(ext)) {
          foundPaths.add(path);
        }
      }
    }
  } catch (_) {}
}

class MediaScanner {
  static final MediaScanner instance = MediaScanner._internal();
  MediaScanner._internal();

  late Box _mediaBox;
  late Box _settingsBox;

  final ValueNotifier<List<MediaFile>> allFiles = ValueNotifier<List<MediaFile>>([]);
  final ValueNotifier<bool> isScanning = ValueNotifier<bool>(false);
  final ValueNotifier<double> scanProgress = ValueNotifier<double>(0.0);
  final ValueNotifier<String> scanStatus = ValueNotifier<String>("");

  // Path to JSON cache file (computed at runtime)
  Future<String> _getCacheFilePath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'cache', 'media_cache.json');
  }

  /// Load cached media list from JSON file if it exists.
  Future<List<MediaFile>> _loadCache() async {
    final path = await _getCacheFilePath();
    final file = File(path);
    if (await file.exists()) {
      try {
        final jsonStr = await file.readAsString();
        final List<dynamic> data = json.decode(jsonStr);
        return data.map((e) => MediaFile.fromMap(e as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Cache load error: $e');
        return [];
      }
    }
    return [];
  }

  /// Save the provided media list to JSON cache.
  Future<void> _saveCache(List<MediaFile> list) async {
    final path = await _getCacheFilePath();
    final file = File(path);
    try {
      final jsonStr = json.encode(list.map((e) => e.toMap()).toList());
      await file.create(recursive: true);
      await file.writeAsString(jsonStr);
    } catch (e) {
      debugPrint('Cache save error: $e');
    }
  }

  /// Public method to get media list, using cache when possible.
  /// If [forceRefresh] is true, it will re‑scan the file system.
  Future<List<MediaFile>> scanMediaAsync({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _loadCache();
      if (cached.isNotEmpty) {
        allFiles.value = cached;
        return cached;
      }
    }
    // Perform heavy scan in an isolate.
    final List<String> paths = await compute(_performScan, null);
    // After isolate finishes, process metadata as in original scan logic.
    // For brevity, we reuse the existing scan implementation logic.
    await scan(); // existing method updates cache and UI.
    await _saveCache(allFiles.value);
    return allFiles.value;
  }

  // Helper isolate function – performs the directory walk and returns list of file paths.
  static Future<List<String>> _performScan(dynamic _) async {
    // Only scan the primary internal storage directory on Android
    final List<String> foundPaths = [];
    final rootDir = Directory('/storage/emulated/0');
    if (rootDir.existsSync()) {
      await _searchDirectoryStatic(rootDir, foundPaths);
    }
    return foundPaths;
  }

  // Static version of the directory search used inside the isolate.
  static Future<void> _searchDirectoryStatic(Directory dir, List<String> foundPaths) async {
    try {
      final stream = dir.list(recursive: false, followLinks: false);
      await for (var entity in stream) {
        final path = entity.path;
        final name = path.split(Platform.pathSeparator).last;
        if (entity is Directory) {
          if (name == 'Android' || name == 'data' || name == 'obb' || name == 'LOST.DIR') continue;
          await _searchDirectoryStatic(entity, foundPaths);
        } else if (entity is File) {
          final ext = name.split('.').last.toLowerCase();
          if (audioExtensions.contains(ext) || videoExtensions.contains(ext)) {
            foundPaths.add(path);
          }
        }
      }
    } catch (_) {}
  }

  static const List<String> audioExtensions = [
    'mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg', 'opus', 'webm',
    'aiff', 'wma', 'dsf', 'dff', 'ape'
  ];

  static const List<String> videoExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', '3gp',
    'ts', 'm2ts'
  ];

  Future<void> init() async {
    try {
      _mediaBox = await Hive.openBox('media_files_box');
    } catch (e) {
      debugPrint('Failed to open media_files_box, deleting: $e');
      await Hive.deleteBoxFromDisk('media_files_box');
      _mediaBox = await Hive.openBox('media_files_box');
    }
    
    // settings_box is already safely opened in main.dart
    _settingsBox = Hive.box('settings_box');
    
    _loadCachedFiles();
  }

  void _loadCachedFiles() {
    // Load cached media entries safely, skipping corrupted items
    final list = <MediaFile>[];
    for (var key in _mediaBox.keys) {
      final map = _mediaBox.get(key);
      if (map is Map) {
        try {
          list.add(MediaFile.fromMap(map));
        } catch (e) {
          debugPrint('Corrupted media entry for key $key: $e');
          // Optionally delete the bad entry to avoid future errors
          _mediaBox.delete(key);
        }
      }
    }
    // Sort: newest added first
    list.sort((a, b) => b.addedDate.compareTo(a.addedDate));
    allFiles.value = list;
    PlaylistService.instance.loadFavorites(list);
  }

  Future<void> scan() async {
    if (isScanning.value) return;
    
    isScanning.value = true;
    scanProgress.value = 0.0;
    scanStatus.value = "Requesting permissions...";

    if (Platform.isAndroid) {
      try {
        // Handle permission requests based on API level
        final audioStatus = await Permission.audio.request();
        final videoStatus = await Permission.videos.request();
        final storageStatus = await Permission.storage.request();
        final photosStatus = await Permission.photos.request();
        final manageStatus = await Permission.manageExternalStorage.request();
        final notificationStatus = await Permission.notification.request();

        // Check if at least one permission is granted
        if (!audioStatus.isGranted && !videoStatus.isGranted && !storageStatus.isGranted && !photosStatus.isGranted && !manageStatus.isGranted) {
          scanStatus.value = "Permissions denied. Please grant media access in settings.";
          isScanning.value = false;
          return;
        }

        debugPrint("Permissions - Audio: ${audioStatus.isGranted}, Video: ${videoStatus.isGranted}, Storage: ${storageStatus.isGranted}, Photos: ${photosStatus.isGranted}, Manage: ${manageStatus.isGranted}, Notification: ${notificationStatus.isGranted}");
      } catch (e) {
        debugPrint("Permission request failed (likely running in background isolate): $e");
      }
    }

    scanStatus.value = "Finding media folders...";
    final List<Directory> rootDirectories = [];

    try {
      rootDirectories.add(Directory('/storage/emulated/0'));
    } catch (e) {
      debugPrint("Error establishing roots: $e");
    }

    final foundPaths = <String>[];
    final showHidden = _settingsBox.get('show_hidden_files', defaultValue: false) as bool;
    final excludedFolders = List<String>.from(_settingsBox.get('excluded_folders', defaultValue: []));

    scanStatus.value = "Searching folders...";
    try {
      final paths = await compute(
        _performScanSync,
        IsolateScanParams(
          rootPaths: rootDirectories.map((d) => d.path).toList(),
          showHidden: showHidden,
          excludedFolders: excludedFolders,
          audioExtensions: audioExtensions,
          videoExtensions: videoExtensions,
        ),
      );
      foundPaths.addAll(paths);
    } catch (e) {
      debugPrint("Isolate scan failed, falling back: $e");
      for (var root in rootDirectories) {
        scanStatus.value = "Searching in ${root.path}...";
        await _searchDirectory(root, foundPaths, showHidden, excludedFolders);
      }
    }

    if (foundPaths.isEmpty) {
      scanStatus.value = "No media files found.";
      isScanning.value = false;
      return;
    }

    scanStatus.value = "Extracting details for ${foundPaths.length} files...";
    
    // Process files and cache them
    int index = 0;
    final cachedPaths = _mediaBox.keys.cast<String>().toSet();
    final List<MediaFile> newFiles = [];

    for (var path in foundPaths) {
      index++;
      scanProgress.value = index / foundPaths.length;
      scanStatus.value = "Processing: ${path.split(Platform.pathSeparator).last}";

      // If already cached, reuse it (only if it has a valid duration, or is a video)
      if (cachedPaths.contains(path)) {
        final map = _mediaBox.get(path);
        if (map is Map) {
          final cachedFile = MediaFile.fromMap(map);
          if (cachedFile.isVideo || cachedFile.duration > Duration.zero) {
            newFiles.add(cachedFile);
            continue;
          }
        }
      }

      // Otherwise extract metadata
      final file = File(path);
      if (await file.exists()) {
        final ext = path.split('.').last.toLowerCase();
        final isVideo = videoExtensions.contains(ext);
        
        final mediaFile = await MetadataService.instance.extractMetadata(file, isVideo: isVideo);
        await _mediaBox.put(path, mediaFile.toMap());
        newFiles.add(mediaFile);

        // Progressive stream to UI every 20 files
        if (newFiles.length % 20 == 0) {
          final partial = List<MediaFile>.from(newFiles)..sort((a, b) => b.addedDate.compareTo(a.addedDate));
          allFiles.value = partial;
        }
      }
    }

    // Clean up cache of deleted files
    final currentPaths = foundPaths.toSet();
    for (var key in cachedPaths) {
      if (!currentPaths.contains(key)) {
        await _mediaBox.delete(key);
      }
    }

    // Update list
    newFiles.sort((a, b) => b.addedDate.compareTo(a.addedDate));
    allFiles.value = newFiles;
    await PlaylistService.instance.loadFavorites(newFiles);

    scanStatus.value = "Scan complete!";
    isScanning.value = false;
  }

  Future<void> _searchDirectory(Directory dir, List<String> foundPaths, bool showHidden, List<String> excluded) async {
    try {
      final stream = dir.list(recursive: false, followLinks: false);
      await for (var entity in stream) {
        final path = entity.path;
        final name = path.split(Platform.pathSeparator).last;

        // Skip hidden files if setting is off
        if (!showHidden && name.startsWith('.')) continue;

        // Skip excluded folders
        if (excluded.any((ex) => path.startsWith(ex))) continue;

        if (entity is Directory) {
          // Prevent infinite recursion and Android system directory crashes (like /Android/data)
          if (name == 'Android' || name == 'data' || name == 'obb' || name == 'LOST.DIR') continue;
          await _searchDirectory(entity, foundPaths, showHidden, excluded);
        } else if (entity is File) {
          final ext = name.split('.').last.toLowerCase();
          if (audioExtensions.contains(ext) || videoExtensions.contains(ext)) {
            foundPaths.add(path);
          }
        }
      }
    } catch (e) {
      // Ignore directory access denied errors
    }
  }

  Future<void> deleteMediaFile(MediaFile file) async {
    try {
      final f = File(file.path);
      if (await f.exists()) {
        await f.delete();
      }
      await _mediaBox.delete(file.path);
      
      final current = List<MediaFile>.from(allFiles.value);
      current.removeWhere((item) => item.path == file.path);
      allFiles.value = current;
      await PlaylistService.instance.loadFavorites(current);
    } catch (e) {
      debugPrint("Error deleting file: $e");
    }
  }

  Future<void> renameMediaFile(MediaFile file, String newNameWithoutExtension) async {
    try {
      final f = File(file.path);
      if (await f.exists()) {
        final dir = f.parent.path;
        final ext = file.path.split('.').last;
        final newPath = '$dir${Platform.pathSeparator}$newNameWithoutExtension.$ext';
        
        final renamedFile = await f.rename(newPath);
        
        // Delete old cache entry
        await _mediaBox.delete(file.path);
        
        // Save new cache entry
        final updatedFile = file.copyWith(
          title: newNameWithoutExtension,
          path: renamedFile.path,
        );
        await _mediaBox.put(renamedFile.path, updatedFile.toMap());
        
        // Reload cache
        _loadCachedFiles();
      }
    } catch (e) {
      debugPrint("Error renaming file: $e");
    }
  }
}
