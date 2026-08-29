import 'package:flutter/foundation.dart';
import '../models/media_file.dart';
import '../models/playlist.dart';
import '../services/playlist_service.dart';
import '../services/playback_service.dart';

/// High-level coordinator that bridges the selection layer with
/// [PlaylistService] (persistence) and [PlaybackService] (live queue).
///
/// Use this instead of calling [PlaylistService] directly when acting on
/// a bulk selection — it handles deduplication, persistence, and optionally
/// enqueues the new items into the active playback queue.
class PlaylistManager {
  static final PlaylistManager instance = PlaylistManager._internal();
  PlaylistManager._internal();

  // ─── Bulk add to an existing playlist ────────────────────────────────────

  /// Adds [items] to the playlist identified by [playlistId].
  ///
  /// Skips items whose path is already present in the playlist (dedup).
  /// Returns the number of items actually added.
  Future<int> addItems(
    String playlistId,
    List<MediaFile> items, {
    bool enqueueInPlayer = false,
  }) async {
    if (items.isEmpty) return 0;

    int added = 0;
    for (final item in items) {
      // PlaylistService.addToPlaylist already deduplicates, but we count here.
      final playlist = _getPlaylist(playlistId);
      if (playlist != null && playlist.mediaIds.contains(item.path)) continue;

      await PlaylistService.instance.addToPlaylist(playlistId, item.path);
      added++;
    }

    if (enqueueInPlayer && added > 0) {
      enqueueItems(items);
    }

    return added;
  }

  /// Creates a brand-new playlist named [name] and bulk-adds [items] to it.
  /// Returns the newly created [Playlist].
  Future<Playlist> createAndAddItems(
    String name,
    List<MediaFile> items, {
    bool enqueueInPlayer = false,
  }) async {
    final playlist = await PlaylistService.instance.createPlaylist(name);
    await addItems(playlist.id, items, enqueueInPlayer: enqueueInPlayer);
    return playlist;
  }

  // ─── Bulk remove ─────────────────────────────────────────────────────────

  /// Removes [items] from the playlist identified by [playlistId].
  Future<void> removeItems(String playlistId, List<MediaFile> items) async {
    for (final item in items) {
      await PlaylistService.instance.removeFromPlaylist(playlistId, item.path);
    }
  }

  // ─── Enqueue into the live player queue ──────────────────────────────────

  /// Appends [items] to the end of [PlaybackService]'s current queue without
  /// starting playback. Audio-only items are enqueued; videos are skipped
  /// because the video player manages its own queue.
  void enqueueItems(List<MediaFile> items) {
    final audioItems = items.where((f) => !f.isVideo).toList();
    if (audioItems.isEmpty) return;

    final service = PlaybackService.instance;
    final current = List<MediaFile>.from(service.queue.value);

    // Append only items not already in the queue.
    for (final item in audioItems) {
      if (!current.any((t) => t.path == item.path)) {
        current.add(item);
      }
    }

    service.queue.value = current;
  }

  /// Replaces the live queue with [items] and starts playing from the first
  /// item. Useful for "Play all selected".
  Future<void> playItems(List<MediaFile> items) async {
    if (items.isEmpty) return;
    await PlaybackService.instance.playTrack(items.first, newQueue: items);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Returns all currently persisted playlists.
  List<Playlist> get playlists => PlaylistService.instance.playlists.value;

  /// Convenience listenable so widgets can rebuild when playlists change.
  ValueNotifier<List<Playlist>> get playlistsNotifier =>
      PlaylistService.instance.playlists;

  Playlist? _getPlaylist(String id) {
    try {
      return PlaylistService.instance.playlists.value
          .firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}