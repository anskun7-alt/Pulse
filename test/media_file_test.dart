import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/models/media_file.dart';

void main() {
  group('MediaFile Model Tests', () {
    test('Correctly identifies video and audio file types and formats strings', () {
      final video = MediaFile(
        id: '1',
        title: 'Sample Video',
        artist: 'Unknown',
        album: 'Videos',
        path: 'C:/Videos/sample.mp4',
        duration: const Duration(minutes: 5, seconds: 30),
        isVideo: true,
        size: 1024 * 1024 * 50,
        addedDate: DateTime.now(),
        resolution: '1920x1080',
        bitrate: 5000,
      );

      final audio = MediaFile(
        id: '2',
        title: 'Sample Song',
        artist: 'Artist',
        album: 'Album',
        path: 'C:/Music/sample.mp3',
        duration: const Duration(minutes: 3, seconds: 45),
        isVideo: false,
        size: 1024 * 1024 * 5,
        addedDate: DateTime.now(),
      );

      expect(video.isVideo, isTrue);
      expect(audio.isVideo, isFalse);
      expect(video.duration.inSeconds, equals(330));
      expect(video.durationString, equals('05:30'));
      expect(audio.durationString, equals('03:45'));
      expect(video.sizeString, contains('MB'));
    });

    test('Serialization toMap and fromMap preserves all fields', () {
      final now = DateTime.now();
      final original = MediaFile(
        id: 'test_id_123',
        title: 'Cyberpunk 2077 Theme',
        artist: 'Marcin Przybyłowicz',
        album: 'Soundtrack',
        path: 'D:/Media/cyberpunk.flac',
        duration: const Duration(minutes: 4, seconds: 12),
        isVideo: false,
        size: 45000000,
        addedDate: now,
        albumArtPath: 'D:/Media/cyberpunk.jpg',
        resolution: '1080p',
        bitrate: 1411,
        isFavorite: true,
      );

      final map = original.toMap();
      final restored = MediaFile.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(restored.artist, equals(original.artist));
      expect(restored.album, equals(original.album));
      expect(restored.path, equals(original.path));
      expect(restored.duration.inSeconds, equals(original.duration.inSeconds));
      expect(restored.isVideo, equals(original.isVideo));
      expect(restored.albumArtPath, equals(original.albumArtPath));
      expect(restored.resolution, equals(original.resolution));
      expect(restored.bitrate, equals(original.bitrate));
      expect(restored.isFavorite, equals(original.isFavorite));
    });

    test('copyWith updates specified fields only', () {
      final original = MediaFile(
        id: '1',
        title: 'Original Title',
        artist: 'Original Artist',
        album: 'Original Album',
        path: 'C:/music.mp3',
        duration: const Duration(seconds: 180),
        isVideo: false,
        size: 1000,
        addedDate: DateTime.now(),
      );

      final updated = original.copyWith(
        title: 'New Title',
        artist: 'New Artist',
        duration: const Duration(seconds: 240),
        isFavorite: true,
      );

      expect(updated.title, equals('New Title'));
      expect(updated.artist, equals('New Artist'));
      expect(updated.duration.inSeconds, equals(240));
      expect(updated.path, equals('C:/music.mp3'));
      expect(updated.album, equals('Original Album'));
      expect(updated.isFavorite, isTrue);
    });
  });
}
