import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../theme/logo.dart';
import '../services/media_scanner.dart';
import '../services/playlist_service.dart';
import '../services/playback_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  final String? initialFilePath;
  const SplashScreen({Key? key, this.initialFilePath}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  bool _navigated = false;
  double _progress = 0.1;
  String _status = 'Initializing Pulse...';

  @override
  void initState() {
    super.initState();
    _bootstrapApp();
  }

  Future<void> _bootstrapApp() async {
    final startTime = DateTime.now();

    try {
      if (mounted) {
        setState(() {
          _progress = 0.3;
          _status = 'Loading your media library...';
        });
      }

      // Initialize media and playlist caches
      await Future.wait([
        MediaScanner.instance.init(),
        PlaylistService.instance.init(),
      ]).timeout(const Duration(seconds: 2), onTimeout: () {
        debugPrint('[SplashScreen] Scanner/Playlist init timed out, continuing...');
        return [];
      });

      if (mounted) {
        setState(() {
          _progress = 0.7;
          _status = 'Configuring audio engine...';
        });
      }

      // Request permissions proactively on Android
      if (Platform.isAndroid) {
        try {
          await [
            Permission.audio,
            Permission.videos,
            Permission.storage,
            Permission.photos,
            Permission.notification,
          ].request().timeout(const Duration(seconds: 2), onTimeout: () => <Permission, PermissionStatus>{});
        } catch (_) {}
      }

      // Initialize playback engine
      try {
        await PlaybackService.instance.init().timeout(const Duration(seconds: 2), onTimeout: () {
          debugPrint('[SplashScreen] PlaybackService init timed out, continuing...');
        });
      } catch (e) {
        debugPrint('[SplashScreen] PlaybackService init error: $e');
      }

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _status = 'Ready';
        });
      }
    } catch (e) {
      debugPrint('[SplashScreen] Bootstrap error: $e');
    } finally {
      // Ensure smooth branding display for at least 750ms
      final elapsed = DateTime.now().difference(startTime);
      const minDuration = Duration(milliseconds: 750);
      if (elapsed < minDuration) {
        await Future.delayed(minDuration - elapsed);
      }
      _navigateToHome();
    }
  }

  void _navigateToHome() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    String? targetPath = widget.initialFilePath;

    // Check Android Open with / View Intent if initialFilePath is empty
    if (Platform.isAndroid && (targetPath == null || targetPath.isEmpty)) {
      try {
        const channel = MethodChannel('com.pulse.player/media_intent');
        final androidPath = await channel.invokeMethod<String>('getInitialFile');
        if (androidPath != null && androidPath.isNotEmpty) {
          targetPath = androidPath;
        }
      } catch (e) {
        debugPrint('Error getting Android initial intent file: $e');
      }
    }

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );

    // Auto-play media file if opened from external file manager or open-with
    if (targetPath != null && targetPath.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final mediaFile = await MediaScanner.instance.scanFile(targetPath!);
          if (mediaFile != null) {
            await PlaybackService.instance.playTrack(mediaFile, newQueue: [mediaFile]);
          }
        } catch (e) {
          debugPrint('Error auto-playing initial file: $e');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = PulseColors.accentPrimary;
    final secondary = PulseColors.accentSecondary;

    return Scaffold(
      backgroundColor: PulseColors.background,
      body: Stack(
        children: [
          // Background subtle ambient radial glow
          Positioned(
            top: MediaQuery.of(context).size.height * 0.25,
            left: MediaQuery.of(context).size.width * 0.2,
            right: MediaQuery.of(context).size.width * 0.2,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primary.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
              ),
            ),
          ),

          // Central branding content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulse Glowing App Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.35),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.asset(
                      PulseLogo.currentAssetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [primary, secondary],
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 54,
                        ),
                      ),
                    ),
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1.0, 1.0),
                      end: const Offset(1.06, 1.06),
                      duration: 1200.ms,
                      curve: Curves.easeInOut,
                    ),

                const SizedBox(height: 24),

                // App Title
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.white, secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text(
                    'PULSE',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4.0,
                      color: Colors.white,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms),

                const SizedBox(height: 6),

                // Tagline
                Text(
                  'Your media, your way',
                  style: PulseTypography.bodySmall.copyWith(
                    color: PulseColors.textSecondary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 400.ms),

                const SizedBox(height: 48),

                // Progress Indicator & Status
                SizedBox(
                  width: 160,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 3.5,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(secondary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _status,
                          key: ValueKey<String>(_status),
                          style: PulseTypography.bodySmall.copyWith(
                            fontSize: 11,
                            color: PulseColors.textSecondary.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 250.ms, duration: 400.ms),
              ],
            ),
          ),

          // Bottom Version info
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Text(
              'Version 1.0.3',
              textAlign: TextAlign.center,
              style: PulseTypography.bodySmall.copyWith(
                fontSize: 11,
                color: PulseColors.textSecondary.withValues(alpha: 0.4),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
