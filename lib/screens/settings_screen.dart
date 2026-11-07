import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../services/media_scanner.dart';
import '../services/playback_service.dart';
import '../services/update_service.dart';
import '../widgets/equalizer_screen.dart';
import 'shortcuts_screen.dart';
import 'downloads_screen.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../theme/logo.dart';
import '../theme/design_system.dart';
import '../services/avatar_service.dart';
import '../widgets/custom_toast.dart';
import '../widgets/interactive_elements.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Box _settingsBox;
  bool _isLoading = true;

  // Settings states
  double _defaultSpeed = 1.0;
  int _skipInterval = 10;
  bool _rememberPosition = true;
  String _videoResumeMode = 'ask';
  bool _defaultFullscreen = true;
  bool _autoDetectOrientation = true;
  bool _backgroundAudio = true;
  double _crossfadeDuration = 2.0;
  bool _autoPlayNext = true;
  bool _autoPlayFolder = true;

  String _themeMode = 'Dark';
  String _fontStyle = 'Auto';
  String _logoStyle = PulseLogo.classic;
  bool _dynamicColor = true;
  String _albumArtBg = 'Blur';
  String _visualizerStyle = 'Bars';

  bool _showHiddenFiles = false;

  double _bassBoostVal = 60.0;
  bool _stereoWidener = false;

  String _currentVersion = '1.0.0';
  bool _autoCheckUpdates = true;

  bool _gesturesEnabled = true;
  bool _swipeVolumeBrightness = true;
  bool _doubleTapSeek = true;
  bool _holdSpeed = true;
  bool _pinchZoom = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _settingsBox = await Hive.openBox('settings_box');
    final version = await UpdateService.instance.getCurrentVersion();
    setState(() {
      _defaultSpeed = _settingsBox.get('default_speed', defaultValue: 1.0) as double;
      _skipInterval = _settingsBox.get('skip_interval', defaultValue: 10) as int;
      _rememberPosition = _settingsBox.get('remember_position', defaultValue: true) as bool;
      _videoResumeMode = _settingsBox.get('video_resume_mode', defaultValue: 'ask') as String;
      _defaultFullscreen = _settingsBox.get('default_fullscreen', defaultValue: true) as bool;
      _autoDetectOrientation = _settingsBox.get('auto_detect_orientation', defaultValue: true) as bool;
      _autoPlayNext = _settingsBox.get('auto_play_next', defaultValue: true) as bool;
      _autoPlayFolder = _settingsBox.get('auto_play_folder', defaultValue: true) as bool;
      _backgroundAudio = _settingsBox.get('background_audio', defaultValue: true) as bool;
      _crossfadeDuration = _settingsBox.get('crossfade_duration', defaultValue: 2.0) as double;

      _themeMode = _settingsBox.get('theme_mode', defaultValue: 'Dark') as String;
      _fontStyle = _settingsBox.get('font_style', defaultValue: 'Auto') as String;
      _logoStyle = _settingsBox.get('app_logo_style', defaultValue: PulseLogo.classic) as String;
      _dynamicColor = _settingsBox.get('dynamic_color', defaultValue: true) as bool;
      _albumArtBg = _settingsBox.get('album_art_bg', defaultValue: 'Blur') as String;
      _visualizerStyle = _settingsBox.get('visualizer_style', defaultValue: 'Bars') as String;

      _showHiddenFiles = _settingsBox.get('show_hidden_files', defaultValue: false) as bool;

      _bassBoostVal = _settingsBox.get('bass_boost_val', defaultValue: 60.0) as double;
      _stereoWidener = _settingsBox.get('stereo_widener', defaultValue: false) as bool;

      _currentVersion = version;
      _autoCheckUpdates = _settingsBox.get('auto_check_updates', defaultValue: true) as bool;

      _gesturesEnabled = _settingsBox.get('gestures_enabled', defaultValue: true) as bool;
      _swipeVolumeBrightness = _settingsBox.get('swipe_vol_bright', defaultValue: true) as bool;
      _doubleTapSeek = _settingsBox.get('double_tap_seek', defaultValue: true) as bool;
      _holdSpeed = _settingsBox.get('hold_speed', defaultValue: true) as bool;
      _pinchZoom = _settingsBox.get('pinch_zoom', defaultValue: true) as bool;

      _isLoading = false;
    });
  }

  void _saveSetting(String key, dynamic value) {
    _settingsBox.put(key, value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: PulseColors.background,
        body: Center(child: CircularProgressIndicator(color: PulseColors.accentPrimary)),
      );
    }

    return Scaffold(
      backgroundColor: PulseColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Settings", style: PulseTypography.displayLarge),
                      BouncingTap(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          PulseColors.toggleLightDark();
                          setState(() {
                            _themeMode = PulseColors.themeMode;
                          });
                          _saveSetting('theme_mode', _themeMode);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: PulseColors.surfaceHigh.withValues(alpha: PulseColors.isLight ? 0.95 : 0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: PulseColors.accentPrimary.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: PulseColors.isLight ? 0.05 : 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PulseColors.isLight ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                size: 18,
                                color: PulseColors.isLight ? PulseColors.accentPrimary : const Color(0xFFFBBF24),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                PulseColors.isLight ? "Dark Mode" : "Light Mode",
                                style: PulseTypography.bodySmall.copyWith(
                                  color: PulseColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // USER PROFILE & CHARACTER AVATARS
                _buildProfileAvatarCard(),
                const SizedBox(height: 20),

                // PLAYBACK GROUP
                _buildSectionHeader("PLAYBACK"),
                _buildDropDownSetting<double>(
                  title: "Default speed",
                  value: _defaultSpeed,
                  items: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _defaultSpeed = val);
                      _saveSetting('default_speed', val);
                    }
                  },
                ),
                _buildDropDownSetting<int>(
                  title: "Skip interval",
                  value: _skipInterval,
                  items: [5, 10, 15, 30],
                  labels: {5: "5s", 10: "10s", 15: "15s", 30: "30s"},
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _skipInterval = val);
                      _saveSetting('skip_interval', val);
                    }
                  },
                ),
                _buildSwitchSetting(
                  title: "Remember position",
                  value: _rememberPosition,
                  onChanged: (val) {
                    setState(() => _rememberPosition = val);
                    _saveSetting('remember_position', val);
                  },
                ),
                _buildDropDownSetting<String>(
                  title: "Video resume behavior",
                  value: _videoResumeMode,
                  items: ['always', 'never', 'ask'],
                  labels: {
                    'ask': 'Ask every time (Prompt to resume or start over)',
                    'always': 'Always resume where left off',
                    'never': 'Always start from beginning',
                  },
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _videoResumeMode = val);
                      _saveSetting('video_resume_mode', val);
                    }
                  },
                ),
                _buildSwitchSetting(
                  title: "Default to fullscreen",
                  value: _defaultFullscreen,
                  onChanged: (val) {
                    setState(() => _defaultFullscreen = val);
                    _saveSetting('default_fullscreen', val);
                  },
                ),
                _buildSwitchSetting(
                  title: "Auto-detect video orientation",
                  value: _autoDetectOrientation,
                  onChanged: (val) {
                    setState(() => _autoDetectOrientation = val);
                    _saveSetting('auto_detect_orientation', val);
                  },
                ),
                _buildSwitchSetting(
                  title: "Auto-play next track",
                  value: _autoPlayNext,
                  onChanged: (val) {
                    setState(() => _autoPlayNext = val);
                    _saveSetting('auto_play_next', val);
                    PlaybackService.instance.autoPlayNext.value = val;
                  },
                ),
                _buildSwitchSetting(
                  title: "Auto-play next in folder",
                  value: _autoPlayFolder,
                  onChanged: (val) {
                    setState(() => _autoPlayFolder = val);
                    _saveSetting('auto_play_folder', val);
                  },
                ),
                _buildSwitchSetting(
                  title: "Background audio",
                  value: _backgroundAudio,
                  onChanged: (val) {
                    setState(() => _backgroundAudio = val);
                    _saveSetting('background_audio', val);
                  },
                ),
                _buildSliderSetting(
                  title: "Crossfade duration",
                  value: _crossfadeDuration,
                  min: 0.0,
                  max: 5.0,
                  divisions: 5,
                  label: "${_crossfadeDuration.round()}s",
                  onChanged: (val) {
                    setState(() => _crossfadeDuration = val);
                    _saveSetting('crossfade_duration', val);
                  },
                ),
                const SizedBox(height: 20),

                // CONTROLS & SHORTCUTS GROUP
                _buildSectionHeader("CONTROLS & SHORTCUTS"),
                _buildSwitchSetting(
                  title: "Enable touch gestures",
                  value: _gesturesEnabled,
                  onChanged: (val) {
                    setState(() => _gesturesEnabled = val);
                    _saveSetting('gestures_enabled', val);
                  },
                ),
                if (_gesturesEnabled) ...[
                  _buildSwitchSetting(
                    title: "Swipe volume & brightness",
                    value: _swipeVolumeBrightness,
                    onChanged: (val) {
                      setState(() => _swipeVolumeBrightness = val);
                      _saveSetting('swipe_vol_bright', val);
                    },
                  ),
                  _buildSwitchSetting(
                    title: "Double-tap to seek (±10s)",
                    value: _doubleTapSeek,
                    onChanged: (val) {
                      setState(() => _doubleTapSeek = val);
                      _saveSetting('double_tap_seek', val);
                    },
                  ),
                  _buildSwitchSetting(
                    title: "Hold for 2x speed",
                    value: _holdSpeed,
                    onChanged: (val) {
                      setState(() => _holdSpeed = val);
                      _saveSetting('hold_speed', val);
                    },
                  ),
                  _buildSwitchSetting(
                    title: "Pinch to zoom",
                    value: _pinchZoom,
                    onChanged: (val) {
                      setState(() => _pinchZoom = val);
                      _saveSetting('pinch_zoom', val);
                    },
                  ),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PulseColors.accentPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.keyboard_rounded, color: PulseColors.accentPrimary, size: 20),
                  ),
                  title: Text("Shortcuts & Gestures Guide", style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Text("VLC desktop hotkeys and mobile touch gestures", style: TextStyle(color: PulseColors.textSecondary, fontSize: 12)),
                  trailing: Icon(Icons.chevron_right_rounded, color: PulseColors.textSecondary),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ShortcutsScreen()));
                  },
                ),
                const SizedBox(height: 20),

                // DOWNLOADS & STREAMING
                _buildSectionHeader("DOWNLOADS & STREAMS"),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PulseColors.accentSecondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.cloud_download_rounded, color: PulseColors.accentSecondary, size: 20),
                  ),
                  title: Text("Downloads & Link Downloader", style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Text("Manage video & audio downloads, previews, and links", style: TextStyle(color: PulseColors.textSecondary, fontSize: 12)),
                  trailing: Icon(Icons.chevron_right_rounded, color: PulseColors.textSecondary),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen()));
                  },
                ),
                const SizedBox(height: 20),

                // APPEARANCE GROUP
                _buildSectionHeader("APPEARANCE"),
                _buildThemeModeSelector(),
                _buildDropDownSetting<String>(
                  title: "Aesthetic Skin & Accent Theme",
                  value: ['Dark', 'AMOLED', 'Light', 'System'].contains(_themeMode) ? 'Default' : _themeMode,
                  items: ['Default', 'Cyberpunk', 'Nordic', 'Royale', 'RDR2', 'Manga', 'Anime', 'Gamer', 'Turkish', 'Creme'],
                  labels: {
                    'Default': '✨ Default (Follows Light/Dark Mode)',
                    'Cyberpunk': '⚡ Cyberpunk 2077 Neon',
                    'Nordic': '❄️ Nordic Glacier Frost',
                    'Royale': '👑 Royale Gold & Onyx',
                    'RDR2': '🤠 Red Dead Outlaw',
                    'Manga': '📖 Shonen Manga',
                    'Anime': '🌸 Cyber Sakura Anime',
                    'Gamer': '🎮 Gamer Battlestation',
                    'Turkish': '🇹🇷 Ottoman Turkish',
                    'Creme': '☕ Warm Creme',
                  },
                  onChanged: (val) {
                    if (val != null) {
                      final newTheme = val == 'Default' ? (PulseColors.isLight ? 'Light' : 'Dark') : val;
                      setState(() => _themeMode = newTheme);
                      _saveSetting('theme_mode', newTheme);
                      PulseColors.setTheme(newTheme);
                    }
                  },
                ),
                _buildDropDownSetting<String>(
                  title: "Typography & Font Style",
                  value: _fontStyle,
                  items: [
                    'Auto',
                    'Modern',
                    'Cyberpunk',
                    'Western',
                    'Comic Book',
                    'Batman',
                    'Death Note',
                    'Funky',
                    'Anime',
                  ],
                  labels: {
                    'Auto': '✨ Auto (Follow Theme)',
                    'Modern': '💎 Modern Premium (Outfit)',
                    'Cyberpunk': '⚡ Cyberpunk (Orbitron)',
                    'Western': '🤠 Western Outlaw (Rye - RDR2)',
                    'Comic Book': '💥 Comic Book / Spiderman (Bangers)',
                    'Batman': '🦇 Batman Dark Knight (Russo One)',
                    'Death Note': '📓 Death Note Gothic (Pirata One & Cinzel)',
                    'Funky': '🕺 Funky Retro (Righteous)',
                    'Anime': '🌸 Anime Neo-Tokyo (Zen Dots)',
                  },
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _fontStyle = val);
                      _saveSetting('font_style', val);
                      PulseTypography.setFontStyle(val);
                    }
                  },
                ),
                _buildLogoSelector(),
                _buildSwitchSetting(
                  title: "Dynamic color",
                  value: _dynamicColor,
                  onChanged: (val) {
                    setState(() => _dynamicColor = val);
                    _saveSetting('dynamic_color', val);
                  },
                ),
                _buildDropDownSetting<String>(
                  title: "Album art background",
                  value: _albumArtBg,
                  items: ['Blur', 'Gradient', 'Solid'],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _albumArtBg = val);
                      _saveSetting('album_art_bg', val);
                    }
                  },
                ),
                _buildDropDownSetting<String>(
                  title: "Visualizer style",
                  value: _visualizerStyle,
                  items: ['Bars', 'Wave', 'Circle', 'Off'],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _visualizerStyle = val);
                      _saveSetting('visualizer_style', val);
                    }
                  },
                ),
                const SizedBox(height: 20),

                // LIBRARY & FOLDERS GROUP
                _buildSectionHeader("LIBRARY & FOLDERS"),
                ValueListenableBuilder<bool>(
                  valueListenable: MediaScanner.instance.isScanning,
                  builder: (context, isScanning, _) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Scan media", style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: ValueListenableBuilder<String>(
                        valueListenable: MediaScanner.instance.scanStatus,
                        builder: (context, status, _) => status.isNotEmpty
                            ? Text(status, style: TextStyle(color: PulseColors.accentSecondary, fontSize: 12))
                            : const Text("Scan device & custom folders", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ),
                      trailing: ElevatedButton.icon(
                        onPressed: isScanning ? null : () => MediaScanner.instance.scan(),
                        icon: isScanning
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(isScanning ? "Scanning..." : "Scan now"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PulseColors.accentPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Custom Folder Manager Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PulseColors.surfaceHigh.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Custom Media Locations",
                            style: PulseTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final path = await MediaScanner.instance.pickAndAddCustomFolder();
                              if (path != null && mounted) {
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Added folder: $path"),
                                    backgroundColor: PulseColors.accentPrimary,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text("Add Folder"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PulseColors.accentPrimary.withValues(alpha: 0.25),
                              foregroundColor: PulseColors.accentPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: PulseColors.accentPrimary.withValues(alpha: 0.5)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Include music and videos stored in other folders, external SD cards, or external drives.",
                        style: TextStyle(color: PulseColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final folders = MediaScanner.instance.getCustomFolders();
                          if (folders.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                "No custom folders added yet. Default storage roots are active.",
                                style: TextStyle(color: PulseColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            );
                          }
                          return Column(
                            children: folders.map((f) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: PulseColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.folder_rounded, size: 18, color: PulseColors.accentSecondary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        f,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        await MediaScanner.instance.removeCustomFolder(f);
                                        if (mounted) setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Excluded Folder Manager Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PulseColors.surfaceHigh.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Excluded Folders",
                            style: PulseTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final path = await MediaScanner.instance.pickAndAddExcludedFolder();
                              if (path != null && mounted) {
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Excluded folder: $path"),
                                    backgroundColor: Colors.orangeAccent,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.folder_off_rounded, size: 16),
                            label: const Text("Exclude Folder"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
                              foregroundColor: Colors.orangeAccent,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.5)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Hide noisy directories (like WhatsApp audio, voice notes, ringtones, system sound files).",
                        style: TextStyle(color: PulseColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final excluded = MediaScanner.instance.getExcludedFolders();
                          if (excluded.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                "No folders excluded. All detected folders are scanned.",
                                style: TextStyle(color: PulseColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            );
                          }
                          return Column(
                            children: excluded.map((f) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: PulseColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.folder_off_rounded, size: 18, color: Colors.orangeAccent),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        f,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        await MediaScanner.instance.removeExcludedFolder(f);
                                        if (mounted) setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildSwitchSetting(
                  title: "Show hidden files",
                  value: _showHiddenFiles,
                  onChanged: (val) {
                    setState(() => _showHiddenFiles = val);
                    _saveSetting('show_hidden_files', val);
                  },
                ),
            const SizedBox(height: 20),

            // AUDIO GROUP
            _buildSectionHeader("AUDIO"),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("Equalizer", style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
              trailing: Icon(Icons.chevron_right_rounded, color: PulseColors.textSecondary),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const EqualizerScreen()));
              },
            ),
            _buildSliderSetting(
              title: "Bass boost",
              value: _bassBoostVal,
              min: 0.0,
              max: 100.0,
              divisions: 10,
              label: "${_bassBoostVal.round()}%",
              onChanged: (val) {
                setState(() => _bassBoostVal = val);
                _saveSetting('bass_boost_val', val);
              },
            ),
            _buildSwitchSetting(
              title: "Stereo widener",
              value: _stereoWidener,
              onChanged: (val) {
                setState(() => _stereoWidener = val);
                _saveSetting('stereo_widener', val);
              },
            ),
            const SizedBox(height: 20),

            // ABOUT GROUP
            _buildSectionHeader("ABOUT & UPDATES"),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PulseLogo.buildLogo(size: 42, borderRadius: BorderRadius.circular(21)),
              title: Text("App Version", style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
              subtitle: Text("Pulse v$_currentVersion", style: PulseTypography.bodySmall.copyWith(color: PulseColors.textSecondary)),
              trailing: ElevatedButton.icon(
                onPressed: () {
                  UpdateService.instance.checkAndShowPrompt(context, isManual: true);
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text("Check Updates"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PulseColors.accentPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            _buildSwitchSetting(
              title: "Auto-check for updates",
              value: _autoCheckUpdates,
              onChanged: (val) {
                setState(() => _autoCheckUpdates = val);
                _saveSetting('auto_check_updates', val);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Media Cache", style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                  ElevatedButton(
                    onPressed: () async {
                      final box = await Hive.openBox('media_files_box');
                      await box.clear();
                      MediaScanner.instance.allFiles.value = [];
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text("Cache cleared"), backgroundColor: PulseColors.danger),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: PulseColors.danger.withValues(alpha: 0.2), foregroundColor: PulseColors.danger),
                    child: const Text("Clear cache"),
                  )
                ],
              ),
            ),

            // Spacer bottom padding
            const SizedBox(height: 160),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildThemeModeSelector() {
    final modes = [
      {
        'key': 'Light',
        'label': 'Light',
        'icon': Icons.light_mode_rounded,
        'desc': 'Soft light',
      },
      {
        'key': 'Dark',
        'label': 'Dark',
        'icon': Icons.dark_mode_rounded,
        'desc': 'Midnight',
      },
      {
        'key': 'AMOLED',
        'label': 'AMOLED',
        'icon': Icons.brightness_2_rounded,
        'desc': 'Pure black',
      },
      {
        'key': 'System',
        'label': 'System',
        'icon': Icons.settings_brightness_rounded,
        'desc': 'Follow OS',
      },
    ];

    final current = _themeMode;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
      child: Row(
        children: modes.map((m) {
          final key = m['key'] as String;
          final label = m['label'] as String;
          final icon = m['icon'] as IconData;
          final desc = m['desc'] as String;
          final isSelected = current == key;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: BouncingTap(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _themeMode = key);
                  _saveSetting('theme_mode', key);
                  PulseColors.setTheme(key);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? PulseColors.accentPrimary.withValues(alpha: PulseColors.isLight ? 0.16 : 0.22)
                        : PulseColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? PulseColors.accentPrimary
                          : (PulseColors.isLight ? Colors.black12 : PulseColors.surfaceHigh),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: PulseColors.accentPrimary.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? PulseColors.accentPrimary : PulseColors.textSecondary,
                        size: 24,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: PulseTypography.bodySmall.copyWith(
                          color: isSelected ? PulseColors.textPrimary : PulseColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: TextStyle(
                          color: PulseColors.textSecondary.withValues(alpha: 0.7),
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: PulseTypography.monoLabel.copyWith(color: PulseColors.activeAccentSecondary, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSwitchSetting({required String title, required bool value, required ValueChanged<bool> onChanged}) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
      value: value,
      activeThumbColor: PulseColors.accentPrimary,
      onChanged: onChanged,
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
              Text(label, style: PulseTypography.monoLabel.copyWith(color: PulseColors.activeAccentSecondary)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: PulseColors.accentPrimary,
            inactiveColor: PulseColors.surface,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDropDownSetting<T>({
    required String title,
    required T value,
    required List<T> items,
    Map<T, String>? labels,
    required ValueChanged<T?> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
      trailing: DropdownButton<T>(
        value: value,
        dropdownColor: PulseColors.surfaceHigh,
        iconEnabledColor: PulseColors.activeAccentPrimary,
        underline: const SizedBox.shrink(),
        style: PulseTypography.bodyLarge.copyWith(color: PulseColors.activeAccentPrimary, fontWeight: FontWeight.bold),
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(labels != null ? labels[item]! : item.toString()),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildLogoSelector() {
    final logos = [
      {
        'id': PulseLogo.classic,
        'title': 'Classic Pulse',
        'subtitle': 'Original cyan/violet neon emblem',
        'asset': 'assets/play-button.webp',
        'accent': const Color(0xFF00E5FF),
      },
      {
        'id': PulseLogo.rdr2,
        'title': 'Red Dead Outlaw',
        'subtitle': 'Crimson frontier outlaw edition',
        'asset': 'assets/rdr2_styled.webp',
        'accent': const Color(0xFFE50914),
      },
      {
        'id': PulseLogo.auto,
        'title': 'Auto (Adaptive)',
        'subtitle': 'Adapts to theme & typography',
        'asset': PulseLogo.currentAssetPath,
        'accent': PulseColors.accentPrimary,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "App Logo & Emblem Style",
                style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: PulseColors.accentPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PulseColors.accentPrimary.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Text(
                  PulseLogo.currentTitle,
                  style: TextStyle(color: PulseColors.accentPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Change the in-app logo, splash emblem, and badges on the fly:",
            style: TextStyle(color: PulseColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: logos.map((item) {
                final id = item['id'] as String;
                final title = item['title'] as String;
                final subtitle = item['subtitle'] as String;
                final asset = item['asset'] as String;
                final accent = item['accent'] as Color;
                final isSelected = _logoStyle == id;

                return GestureDetector(
                  onTap: () {
                    setState(() => _logoStyle = id);
                    _saveSetting('app_logo_style', id);
                    PulseLogo.setLogoStyle(id);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('App logo set to $title'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: PulseColors.surfaceHigh,
                    ));
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(right: 12),
                    width: 175,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accent.withValues(alpha: 0.18)
                          : PulseColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? accent : Colors.white12,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.3),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.asset(
                                  asset,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? accent : Colors.white24,
                              size: 22,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.white38,
                            fontSize: 10,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatarCard() {
    return ValueListenableBuilder<AvatarItem>(
      valueListenable: AvatarService.instance.currentAvatar,
      builder: (context, avatar, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AvatarService.instance.userName,
          builder: (context, name, _) {
            return PulseGlassCard(
              padding: PulseInsets.card,
              borderRadius: PulseRadius.xl,
              backgroundColor: PulseColors.surface.withValues(alpha: 0.85),
              borderColor: avatar.accentColor.withValues(alpha: 0.4),
              child: Row(
                children: [
                  // Avatar with glow
                  Container(
                    width: PulseSizes.avatarXl, // 72px (Table of 4)
                    height: PulseSizes.avatarXl,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: avatar.accentColor, width: 2.5),
                      boxShadow: PulseShadows.glow(avatar.accentColor, opacity: 0.35, blur: 16),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        avatar.assetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: PulseColors.surfaceHigh,
                          child: Icon(Icons.person, color: avatar.accentColor, size: 36),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: PulseSpacing.sm), // 16px (Table of 4)

                  // User Info & Tagline
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: PulseTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                              tooltip: 'Edit Profile Name',
                              onPressed: () => _showEditNameDialog(context, name),
                            ),
                          ],
                        ),
                        Text(
                          avatar.tagLine,
                          style: TextStyle(
                            color: avatar.accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: PulseSpacing.xxs), // 8px (Table of 4)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: avatar.accentColor.withValues(alpha: 0.18),
                                borderRadius: PulseRadius.xs,
                                border: Border.all(color: avatar.accentColor.withValues(alpha: 0.4), width: 0.8),
                              ),
                              child: Text(
                                avatar.series,
                                style: TextStyle(
                                  color: avatar.accentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Choose PFP button
                            InkWell(
                              borderRadius: PulseRadius.full,
                              onTap: () => _showAvatarPickerModal(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: PulseColors.accentPrimary.withValues(alpha: 0.15),
                                  borderRadius: PulseRadius.full,
                                  border: Border.all(color: PulseColors.accentPrimary.withValues(alpha: 0.5), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.theater_comedy_rounded, size: 14, color: PulseColors.accentPrimary),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Change PFP",
                                      style: TextStyle(
                                        color: PulseColors.accentPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: PulseColors.surface,
        shape: RoundedRectangleBorder(borderRadius: PulseRadius.lg),
        title: Text("Edit Profile Name", style: PulseTypography.displayMedium),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: PulseTypography.bodyLarge,
          decoration: InputDecoration(
            hintText: "Enter your name or gamer tag",
            hintStyle: PulseTypography.bodyMedium,
            enabledBorder: OutlineInputBorder(
              borderRadius: PulseRadius.md,
              borderSide: BorderSide(color: PulseColors.surfaceHigh),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: PulseRadius.md,
              borderSide: BorderSide(color: PulseColors.accentPrimary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text("Cancel", style: TextStyle(color: PulseColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PulseColors.accentPrimary,
              shape: RoundedRectangleBorder(borderRadius: PulseRadius.md),
            ),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                AvatarService.instance.setUserName(newName);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAvatarPickerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        String selectedCategory = 'All';
        final categories = ['All', 'RDR2', 'Hajime no Ippo', 'Anime', 'Pulse'];

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredAvatars = selectedCategory == 'All'
                ? AvatarService.allAvatars
                : AvatarService.allAvatars.where((a) => a.category == selectedCategory).toList();

            final currentAvatarId = AvatarService.instance.currentAvatar.value.id;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: PulseColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(PulseRadius.r24)),
                border: Border(top: BorderSide(color: PulseColors.surfaceHigh, width: 1.5)),
              ),
              child: Column(
                children: [
                  // Handle pill
                  Container(
                    margin: const EdgeInsets.only(top: PulseSpacing.xs),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: PulseRadius.full,
                    ),
                  ),

                  // Header
                  Padding(
                    padding: PulseInsets.screen,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Official Character PFPs", style: PulseTypography.displayMedium),
                            const SizedBox(height: 2),
                            Text(
                              "RDR 2 • Hajime no Ippo • Anime Legends",
                              style: TextStyle(color: PulseColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: PulseSpacing.sm),
                    child: Row(
                      children: categories.map((cat) {
                        final isSel = selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: PulseSpacing.xxs),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSel,
                            selectedColor: PulseColors.accentPrimary,
                            backgroundColor: PulseColors.surfaceHigh,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : Colors.white70,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (sel) {
                              if (sel) {
                                setModalState(() => selectedCategory = cat);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: PulseSpacing.xs),
                  const Divider(color: Colors.white10, height: 1),

                  // Avatars Grid
                  Expanded(
                    child: GridView.builder(
                      padding: PulseInsets.dialog,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: PulseSpacing.sm,
                        mainAxisSpacing: PulseSpacing.sm,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: filteredAvatars.length,
                      itemBuilder: (context, index) {
                        final item = filteredAvatars[index];
                        final isEquipped = item.id == currentAvatarId;

                        return InkWell(
                          borderRadius: PulseRadius.lg,
                          onTap: () {
                            AvatarService.instance.setAvatar(item);
                            Navigator.pop(modalCtx);
                            CustomToast.show(
                              context,
                              message: "Equipped ${item.name}: ${item.tagLine}",
                              icon: Icons.check_circle_rounded,
                              accentColor: item.accentColor,
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isEquipped
                                  ? item.accentColor.withValues(alpha: 0.2)
                                  : PulseColors.surfaceHigh.withValues(alpha: 0.5),
                              borderRadius: PulseRadius.lg,
                              border: Border.all(
                                color: isEquipped ? item.accentColor : Colors.white12,
                                width: isEquipped ? 2.0 : 1.0,
                              ),
                              boxShadow: isEquipped ? PulseShadows.glow(item.accentColor, opacity: 0.35, blur: 12) : null,
                            ),
                            padding: PulseInsets.all8,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Avatar circle image
                                Stack(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isEquipped ? item.accentColor : Colors.white24,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: Image.asset(
                                          item.assetPath,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.person,
                                            color: item.accentColor,
                                            size: 32,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isEquipped)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: item.accentColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check, size: 12, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: PulseSpacing.xxs),
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: isEquipped ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.series,
                                  style: TextStyle(
                                    color: isEquipped ? item.accentColor : Colors.white38,
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
