import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/media_scanner.dart';
import '../services/playback_service.dart';
import '../services/update_service.dart';
import '../widgets/equalizer_screen.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

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
  bool _backgroundAudio = true;
  double _crossfadeDuration = 2.0;
  bool _autoPlayNext = true;

  String _themeMode = 'Dark';
  bool _dynamicColor = true;
  String _albumArtBg = 'Blur';
  String _visualizerStyle = 'Bars';

  bool _showHiddenFiles = false;

  double _bassBoostVal = 60.0;
  bool _stereoWidener = false;

  String _currentVersion = '1.0.0';
  bool _autoCheckUpdates = true;

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
      _autoPlayNext = _settingsBox.get('auto_play_next', defaultValue: true) as bool;
      _backgroundAudio = _settingsBox.get('background_audio', defaultValue: true) as bool;
      _crossfadeDuration = _settingsBox.get('crossfade_duration', defaultValue: 2.0) as double;

      _themeMode = _settingsBox.get('theme_mode', defaultValue: 'Dark') as String;
      _dynamicColor = _settingsBox.get('dynamic_color', defaultValue: true) as bool;
      _albumArtBg = _settingsBox.get('album_art_bg', defaultValue: 'Blur') as String;
      _visualizerStyle = _settingsBox.get('visualizer_style', defaultValue: 'Bars') as String;

      _showHiddenFiles = _settingsBox.get('show_hidden_files', defaultValue: false) as bool;

      _bassBoostVal = _settingsBox.get('bass_boost_val', defaultValue: 60.0) as double;
      _stereoWidener = _settingsBox.get('stereo_widener', defaultValue: false) as bool;

      _currentVersion = version;
      _autoCheckUpdates = _settingsBox.get('auto_check_updates', defaultValue: true) as bool;

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
                  child: Text("Settings", style: PulseTypography.displayLarge),
                ),

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

                // APPEARANCE GROUP
                _buildSectionHeader("APPEARANCE"),
                _buildDropDownSetting<String>(
                  title: "Theme",
                  value: _themeMode,
                  items: ['Dark', 'AMOLED', 'Creme', 'Light', 'System'],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _themeMode = val);
                      _saveSetting('theme_mode', val);
                    }
                  },
                ),
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
}
