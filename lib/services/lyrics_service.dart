import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine({required this.timestamp, required this.text});
}

class LyricsService {
  static final LyricsService instance = LyricsService._internal();
  LyricsService._internal();

  Future<Map<String, dynamic>?> fetchLyrics(String track, String artist, {Duration? duration}) async {
    try {
      final query = Uri.encodeComponent('$track $artist');
      // Step 1: Try exact match first
      String url = 'https://lrclib.net/api/search?q=$query';
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          if (data.isNotEmpty) {
            // Find the best match (e.g., matching track names) or just pick the first one
            final bestMatch = data.first;
            return {
              'plain': bestMatch['plainLyrics'] as String?,
              'synced': bestMatch['syncedLyrics'] as String?,
            };
          }
        }
      } on TimeoutException catch (e) {
        debugPrint("Lyrics fetch timeout: $e");
        return null;
      }
    } catch (e) {
      debugPrint("Error fetching lyrics: $e");
    }
    return null;
  }

  List<LyricLine> parseSyncedLyrics(String syncedLyrics) {
    final List<LyricLine> lines = [];
    final regExp = RegExp(r'^\[(\d+):(\d+)\.(\d+)\](.*)$');
    
    for (var line in syncedLyrics.split('\n')) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      final match = regExp.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final hundredths = int.parse(match.group(3)!);
        final text = match.group(4)!.trim();
        
        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: hundredths * 10,
        );
        lines.add(LyricLine(timestamp: duration, text: text));
      }
    }
    
    // Sort in ascending order of timestamps just in case
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }
}
