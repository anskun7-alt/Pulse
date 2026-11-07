import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/models/playlist.dart';

void main() {
  group('Playlist Model Tests', () {
    test('Correctly serializes and deserializes a Playlist', () {
      final now = DateTime.now();
      final original = Playlist(
        id: 'pl_001',
        name: 'Chill Vibes',
        createdDate: now,
        mediaIds: ['C:/Music/song1.mp3', 'C:/Music/song2.flac', 'C:/Videos/clip1.mp4'],
      );

      final map = original.toMap();
      final restored = Playlist.fromMap(map);

      expect(restored.id, equals('pl_001'));
      expect(restored.name, equals('Chill Vibes'));
      expect(restored.mediaIds.length, equals(3));
      expect(restored.mediaIds[1], equals('C:/Music/song2.flac'));
      expect(restored.createdDate.millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));
    });

    test('Playlist copyWith preserves unmodified fields', () {
      final now = DateTime.now();
      final original = Playlist(
        id: 'pl_002',
        name: 'Road Trip',
        createdDate: now,
        mediaIds: ['/a.mp3'],
      );

      final updated = original.copyWith(
        name: 'Epic Road Trip',
        mediaIds: ['/a.mp3', '/b.mp3'],
      );

      expect(updated.id, equals('pl_002'));
      expect(updated.name, equals('Epic Road Trip'));
      expect(updated.mediaIds.length, equals(2));
      expect(updated.createdDate, equals(now));
    });
  });
}
