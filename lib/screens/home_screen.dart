import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/mini_player_bar.dart';
import 'videos_tab.dart';
import 'music_tab.dart';
import 'folders_tab.dart';
import 'playlists_tab.dart';
import 'settings_screen.dart';
import 'package:hive/hive.dart';
import '../services/media_scanner.dart';
import '../services/update_service.dart';
import '../services/shortcuts_service.dart';
import '../services/playback_service.dart';
import '../widgets/network_stream_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Scan library automatically on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MediaScanner.instance.scan();
      _checkAutoUpdate();
      _initAndroidIntentListener();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // If user came back after granting permissions in Settings or system dialog, auto-scan immediately
      if (MediaScanner.instance.allFiles.value.isEmpty && !MediaScanner.instance.isScanning.value) {
        MediaScanner.instance.scan();
      }
    }
  }

  void _initAndroidIntentListener() {
    const channel = MethodChannel('com.pulse.player/media_intent');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewFile') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          try {
            final mediaFile = await MediaScanner.instance.scanFile(path);
            if (mediaFile != null) {
              await PlaybackService.instance.playTrack(mediaFile, newQueue: [mediaFile]);
            }
          } catch (e) {
            debugPrint('Error handling incoming file: $e');
          }
        }
      }
    });
  }

  Future<void> _checkAutoUpdate() async {
    try {
      final box = await Hive.openBox('settings_box');
      final autoCheck = box.get('auto_check_updates', defaultValue: true) as bool;
      if (autoCheck && mounted) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            UpdateService.instance.checkAndShowPrompt(context, isManual: false);
          }
        });
      }
    } catch (_) {}
  }

  Widget _buildBody() {
    Widget activeTab;
    switch (_currentIndex) {
      case 0:
        activeTab = const VideosTab();
        break;
      case 1:
        activeTab = const MusicTab();
        break;
      case 2:
        activeTab = const FoldersTab();
        break;
      case 3:
        activeTab = const PlaylistsTab();
        break;
      case 4:
        activeTab = const SettingsScreen();
        break;
      default:
        activeTab = const VideosTab();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_currentIndex),
        child: activeTab,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: PulseColors.themeNotifier,
      builder: (context, currentTheme, _) {
        final isLight = PulseColors.isLight;

        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
        ));

        return Scaffold(
          extendBody: true, // Let the body flow beneath the nav bars
          backgroundColor: PulseColors.background,
          body: KeyboardListener(
            focusNode: FocusNode()..requestFocus(),
            autofocus: true,
            onKeyEvent: (event) {
              PulseShortcuts.handleKeyEvent(
                event,
                context,
                onOpenNetworkStream: () => NetworkStreamDialog.show(context),
              );
            },
            child: WillPopScope(
              onWillPop: () async {
                final now = DateTime.now();
                if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
                  _lastBackPressTime = now;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Press back again to exit'), duration: Duration(seconds: 2)),
                  );
                  return false;
                }
                return true; // exit app
              },
              child: Stack(
              children: [
                // Screen content
                Positioned.fill(
                  child: _buildBody(),
                ),

                // Bottom controls overlay: Mini player and Floating navigation bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MiniPlayerBar(),
                      FloatingNavBar(
                        currentIndex: _currentIndex,
                        onTap: (index) {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  }
}
