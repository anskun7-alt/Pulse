import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/services/playback_service.dart';

void main() {
  group('Playback Service and Enums Tests', () {
    test('RepeatMode enum has expected values', () {
      expect(RepeatMode.values.contains(RepeatMode.off), isTrue);
      expect(RepeatMode.values.contains(RepeatMode.all), isTrue);
      expect(RepeatMode.values.contains(RepeatMode.one), isTrue);
      expect(RepeatMode.values.length, equals(3));
    });

    test('PlaybackService initial notifier states are initialized', () {
      final service = PlaybackService.instance;
      expect(service.queue.value, isEmpty);
      expect(service.queueIndex.value, equals(-1));
      expect(service.currentTrack.value, isNull);
      expect(service.isPlaying.value, isFalse);
      expect(service.position.value, equals(Duration.zero));
      expect(service.duration.value, equals(Duration.zero));
      expect(service.repeatMode.value, equals(RepeatMode.off));
      expect(service.isShuffle.value, isFalse);
      expect(service.autoPlayNext.value, isTrue);
      expect(service.playbackSpeed.value, equals(1.0));
      expect(service.volumeScale.value, equals(1.0));
    });
  });
}
