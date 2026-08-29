import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/media_file.dart';
import '../models/playlist.dart';
import 'media_scanner.dart';
import 'playback_service.dart';

class PlaylistService {
  static final PlaylistService instance = PlaylistService._internal();
  PlaylistService._internal();

  late Box _playlistBox;
  late Box _recentBox; // List of paths in order
  late Box _playCountBox; // Path -> Count

  final ValueNotifier<List<Playlist>> playlists = ValueNotifier<List<Playlist>>([]);
  final ValueNotifier<List<String>> favorites = ValueNotifier<List<String>>([]);

  Future<void> _safeOpenBox(String boxName, Function(Box) onOpened) async {
    try {
      onOpened(await Hive.openBox(boxName));
    } catch (e) {
      debugPrint('Failed to open $boxName, deleting: $e');
      await Hive.deleteBoxFromDisk(boxName);
      onOpened(await Hive.openBox(boxName));
    }
  }

  Future<void> init() async {
    await _safeOpenBox('playlists_box', (b) => _playlistBox = b);
    await _safeOpenBox('recent_box', (b) => _recentBox = b);
    await _safeOpenBox('play_count_box', (b) => _playCountBox = b);
    
    _loadPlaylists();
  }

  void _loadPlaylists() {
    final list = <Playlist>[];
    for (var key in _playlistBox.keys) {
      final map = _playlistBox.get(key);
      if (map is Map) {
        list.add(Playlist.fromMap(map));
      }
    }
    playlists.value = list;
  }

  // Favorites management
  Future<void> toggleFavorite(MediaFile file, Box mediaBox) async {
    final updated = file.copyWith(isFavorite: !file.isFavorite);
    await mediaBox.put(file.path, updated.toMap());

    // Update in media scanner
    try {
      final scannerFiles = List<MediaFile>.from(MediaScanner.instance.allFiles.value);
      final idx = scannerFiles.indexWhere((f) => _normalizePath(f.path) == _normalizePath(file.path));
      if (idx != -1) {
        scannerFiles[idx] = updated;
        MediaScanner.instance.allFiles.value = scannerFiles;
      }
    } catch (_) {}

    // Update in playback service current track
    try {
      final playbackService = PlaybackService.instance;
      if (playbackService.currentTrack.value != null &&
          _normalizePath(playbackService.currentTrack.value!.path) == _normalizePath(file.path)) {
        playbackService.currentTrack.value = updated;
      }
    } catch (_) {}
    
    final currentFavs = List<String>.from(favorites.value);
    final normalizedFilePath = _normalizePath(file.path);
    if (updated.isFavorite) {
      if (!currentFavs.map(_normalizePath).contains(normalizedFilePath)) {
        currentFavs.add(file.path);
      }
    } else {
      currentFavs.removeWhere((p) => _normalizePath(p) == normalizedFilePath);
    }
    favorites.value = currentFavs;
  }

  Future<void> loadFavorites(List<MediaFile> allFiles) async {
    favorites.value = allFiles.where((f) => f.isFavorite).map((f) => f.path).toList();
  }

  // Playlists management
  Future<Playlist> createPlaylist(String name) async {
    final newPlaylist = Playlist(
      id: const Uuid().v4(),
      name: name,
      mediaIds: [],
      createdDate: DateTime.now(),
    );
    await _playlistBox.put(newPlaylist.id, newPlaylist.toMap());
    _loadPlaylists();
    return newPlaylist;
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _playlistBox.delete(playlistId);
    _loadPlaylists();
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final map = _playlistBox.get(playlistId);
    if (map != null) {
      final p = Playlist.fromMap(map).copyWith(name: newName);
      await _playlistBox.put(playlistId, p.toMap());
      _loadPlaylists();
    }
  }

  Future<void> addToPlaylist(String playlistId, String mediaPath) async {
    final map = _playlistBox.get(playlistId);
    if (map != null) {
      final p = Playlist.fromMap(map);
      if (!p.mediaIds.contains(mediaPath)) {
        final updatedIds = List<String>.from(p.mediaIds)..add(mediaPath);
        await _playlistBox.put(playlistId, p.copyWith(mediaIds: updatedIds).toMap());
        _loadPlaylists();
      }
    }
  }

  Future<void> removeFromPlaylist(String playlistId, String mediaPath) async {
    final map = _playlistBox.get(playlistId);
    if (map != null) {
      final p = Playlist.fromMap(map);
      final updatedIds = List<String>.from(p.mediaIds)..remove(mediaPath);
      await _playlistBox.put(playlistId, p.copyWith(mediaIds: updatedIds).toMap());
      _loadPlaylists();
    }
  }

  Future<void> updatePlaylistTracks(String playlistId, List<String> newTracks) async {
    final map = _playlistBox.get(playlistId);
    if (map != null) {
      final p = Playlist.fromMap(map);
      await _playlistBox.put(playlistId, p.copyWith(mediaIds: newTracks).toMap());
      _loadPlaylists();
    }
  }

  // Play logs for smart playlists
  Future<void> logPlay(String filePath) async {
    final normalized = _normalizePath(filePath);
    // 1. Recently Played (up to 50)
    final recent = List<String>.from(_recentBox.get('played_list') ?? []);
    recent.removeWhere((p) => _normalizePath(p) == normalized);
    recent.insert(0, filePath);
    if (recent.length > 50) {
      recent.removeLast();
    }
    await _recentBox.put('played_list', recent);

    // 2. Play Count
    int count = 0;
    if (_playCountBox.containsKey(filePath)) {
      count = _playCountBox.get(filePath, defaultValue: 0) as int;
    } else if (_playCountBox.containsKey(normalized)) {
      count = _playCountBox.get(normalized, defaultValue: 0) as int;
    }
    await _playCountBox.put(normalized, count + 1);
  }

  String _normalizePath(String path) {
    return path.replaceAll('\\', '/').toLowerCase();
  }

  List<MediaFile> getFavorites(List<MediaFile> allFiles) {
    final favPaths = favorites.value.map(_normalizePath).toSet();
    return allFiles.where((f) => favPaths.contains(_normalizePath(f.path))).toList();
  }

  List<MediaFile> getRecentlyPlayed(List<MediaFile> allFiles) {
    final recentPaths = List<String>.from(_recentBox.get('played_list') ?? []);
    final map = {for (var f in allFiles) _normalizePath(f.path): f};
    return recentPaths.map((p) => map[_normalizePath(p)]).whereType<MediaFile>().toList();
  }

  int _getPlayCount(String path) {
    final normalized = _normalizePath(path);
    if (_playCountBox.containsKey(path)) {
      return _playCountBox.get(path, defaultValue: 0) as int;
    }
    if (_playCountBox.containsKey(normalized)) {
      return _playCountBox.get(normalized, defaultValue: 0) as int;
    }
    return 0;
  }

  List<MediaFile> getMostPlayed(List<MediaFile> allFiles) {
    final sortedFiles = List<MediaFile>.from(allFiles);
    sortedFiles.sort((a, b) {
      final countA = _getPlayCount(a.path);
      final countB = _getPlayCount(b.path);
      return countB.compareTo(countA);
    });
    // Filter out items with 0 plays
    return sortedFiles.where((f) {
      return _getPlayCount(f.path) > 0;
    }).take(20).toList();
  }

  List<MediaFile> getJustAdded(List<MediaFile> allFiles) {
    final now = DateTime.now();
    return allFiles.where((f) {
      return now.difference(f.addedDate).inDays <= 7;
    }).toList();
  }
}
