import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    // Scan library automatically on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MediaScanner.instance.scan();
      _checkAutoUpdate();
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
    // Set system status and navigation bar styling to transparent for edge-to-edge UI
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ));

    return Scaffold(
      extendBody: true, // Let the body flow beneath the nav bars
      backgroundColor: const Color(0xFF080810),
      body: WillPopScope(
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
    );
  }
}
