import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/update_dialog.dart';

class ReleaseAsset {
  final String name;
  final String downloadUrl;
  final int size;

  ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name'] ?? '',
      downloadUrl: json['browser_download_url'] ?? '',
      size: json['size'] ?? 0,
    );
  }
}

class AppReleaseInfo {
  final String tagName;
  final String version;
  final String title;
  final String changelog;
  final String htmlUrl;
  final DateTime? publishedAt;
  final List<ReleaseAsset> assets;
  final ReleaseAsset? primaryAsset;

  AppReleaseInfo({
    required this.tagName,
    required this.version,
    required this.title,
    required this.changelog,
    required this.htmlUrl,
    required this.publishedAt,
    required this.assets,
    this.primaryAsset,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? 'v1.0.0';
    final version = tagName.startsWith('v') || tagName.startsWith('V')
        ? tagName.substring(1)
        : tagName;

    final assetsList = (json['assets'] as List<dynamic>? ?? [])
        .map((e) => ReleaseAsset.fromJson(e as Map<String, dynamic>))
        .toList();

    // Find best asset for platform
    ReleaseAsset? bestAsset;
    if (Platform.isAndroid) {
      bestAsset = assetsList.firstWhere(
        (a) => a.name.toLowerCase().endsWith('.apk'),
        orElse: () => assetsList.isNotEmpty ? assetsList.first : ReleaseAsset(name: '', downloadUrl: '', size: 0),
      );
    } else if (Platform.isWindows) {
      bestAsset = assetsList.firstWhere(
        (a) => a.name.toLowerCase().endsWith('.exe') || a.name.toLowerCase().endsWith('.msix') || a.name.toLowerCase().endsWith('.zip'),
        orElse: () => assetsList.isNotEmpty ? assetsList.first : ReleaseAsset(name: '', downloadUrl: '', size: 0),
      );
    }

    if (bestAsset != null && bestAsset.downloadUrl.isEmpty) {
      bestAsset = null;
    }

    return AppReleaseInfo(
      tagName: tagName,
      version: version,
      title: json['name'] ?? tagName,
      changelog: json['body'] ?? 'No release notes provided.',
      htmlUrl: json['html_url'] ?? 'https://github.com/anskun7-alt/Pulse/releases',
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at']) : null,
      assets: assetsList,
      primaryAsset: bestAsset,
    );
  }
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String repoOwner = 'anskun7-alt';
  static const String repoName = 'Pulse';
  static const String apiUrl = 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  /// Check if a newer release exists on GitHub.
  Future<AppReleaseInfo?> checkForUpdate() async {
    if (_isChecking) return null;
    _isChecking = true;

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Pulse-App-Updater',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final release = AppReleaseInfo.fromJson(data);

        final currentVersion = await getCurrentVersion();
        if (_isNewerVersion(currentVersion, release.version)) {
          return release;
        }
      } else if (response.statusCode == 404) {
        debugPrint('No GitHub releases found for $repoOwner/$repoName yet.');
      }
    } catch (e) {
      debugPrint('UpdateService check error: $e');
    } finally {
      _isChecking = false;
    }
    return null;
  }

  /// Get the current installed app version.
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      return '1.0.0';
    }
  }

  /// Compare two semantic version strings (e.g. "1.0.1" vs "1.0.0").
  bool _isNewerVersion(String current, String remote) {
    try {
      final curClean = current.split('+').first.replaceAll(RegExp(r'[^0-9.]'), '');
      final remClean = remote.split('+').first.replaceAll(RegExp(r'[^0-9.]'), '');

      final curParts = curClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final remParts = remClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (curParts.length < 3) {
        curParts.add(0);
      }
      while (remParts.length < 3) {
        remParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (remParts[i] > curParts[i]) return true;
        if (remParts[i] < curParts[i]) return false;
      }

      // Check build number if versions are equal
      final curBuild = int.tryParse(current.contains('+') ? current.split('+').last : '0') ?? 0;
      final remBuild = int.tryParse(remote.contains('+') ? remote.split('+').last : '0') ?? 0;
      return remBuild > curBuild;
    } catch (e) {
      return false;
    }
  }

  /// Downloads and automatically triggers installation of the release asset.
  Future<void> downloadAndInstall({
    required AppReleaseInfo release,
    required void Function(double progress, int downloadedBytes, int totalBytes) onProgress,
    required void Function(String error) onError,
    required void Function() onSuccess,
  }) async {
    final asset = release.primaryAsset;

    // Fallback to browser if no direct installable asset or unsupported platform
    if (asset == null || asset.downloadUrl.isEmpty) {
      await launchUrl(Uri.parse(release.htmlUrl), mode: LaunchMode.externalApplication);
      onSuccess();
      return;
    }

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(asset.downloadUrl));
      request.headers['User-Agent'] = 'Pulse-App-Updater';
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed with status code ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? asset.size;
      final tempDir = await getTemporaryDirectory();
      final saveFileName = asset.name.isNotEmpty ? asset.name : 'Pulse-update.apk';
      final file = File('${tempDir.path}/$saveFileName');

      if (await file.exists()) {
        await file.delete();
      }

      final sink = file.openWrite();
      int downloadedBytes = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(downloadedBytes / totalBytes, downloadedBytes, totalBytes);
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      onSuccess();

      // Trigger automatic installation
      if (Platform.isAndroid) {
        final result = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
        if (result.type != ResultType.done) {
          debugPrint('OpenFilex install result: ${result.message}');
          // If native open fails, fallback to opening browser
          await launchUrl(Uri.parse(release.htmlUrl), mode: LaunchMode.externalApplication);
        }
      } else if (Platform.isWindows) {
        if (file.path.endsWith('.exe')) {
          await Process.start(file.path, [], runInShell: true);
        } else {
          await OpenFilex.open(file.path);
        }
      } else {
        await launchUrl(Uri.parse(release.htmlUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      onError(e.toString());
    }
  }

  /// Check for updates and show prompt UI in context.
  Future<void> checkAndShowPrompt(BuildContext context, {bool isManual = false}) async {
    if (isManual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Checking GitHub for updates...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final release = await checkForUpdate();

    if (!context.mounted) return;

    if (release != null) {
      final currentVer = await getCurrentVersion();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => UpdateDialog(
          release: release,
          currentVersion: currentVer,
        ),
      );
    } else if (isManual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are on the latest version of Pulse!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
