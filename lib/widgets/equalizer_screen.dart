import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({Key? key}) : super(key: key);

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  final List<String> _presets = ['Normal', 'Bass', 'Pop', 'Rock', 'Jazz', 'Classical', 'Electronic'];
  String _selectedPreset = 'Normal';

  // Equalizer frequencies and decibel offsets
  final List<String> _bands = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];
  late List<double> _bandLevels; // values from -12 to +12

  double _bassBoost = 60.0; // 0 to 100
  double _virtualizer = 70.0;
  double _reverb = 30.0;

  @override
  void initState() {
    super.initState();
    _applyPreset('Normal');
  }

  void _applyPreset(String preset) {
    setState(() {
      _selectedPreset = preset;
      switch (preset) {
        case 'Normal':
          _bandLevels = [0.0, 0.0, 0.0, 0.0, 0.0];
          break;
        case 'Bass':
          _bandLevels = [8.0, 5.0, 1.0, 0.0, -2.0];
          _bassBoost = 90.0;
          break;
        case 'Pop':
          _bandLevels = [-2.0, -1.0, 3.0, 4.0, 2.0];
          break;
        case 'Rock':
          _bandLevels = [6.0, 3.0, -2.0, 4.0, 6.0];
          break;
        case 'Jazz':
          _bandLevels = [4.0, 2.0, 1.0, 2.0, -1.0];
          break;
        case 'Classical':
          _bandLevels = [5.0, 3.0, -1.0, 2.0, 4.0];
          break;
        case 'Electronic':
          _bandLevels = [7.0, 4.0, 0.0, 5.0, 6.0];
          _virtualizer = 85.0;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseColors.background,
      appBar: AppBar(
        title: Text("Equalizer", style: PulseTypography.displayMedium),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Equalizer settings saved"),
                  backgroundColor: PulseColors.success,
                ),
              );
              Navigator.pop(context);
            },
            child: Text(
              "Save",
              style: PulseTypography.bodyLarge.copyWith(
                color: PulseColors.accentPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Presets Header list
            Text(
              "Presets",
              style: PulseTypography.bodySmall.copyWith(color: PulseColors.textSecondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _presets.length,
                itemBuilder: (context, index) {
                  final preset = _presets[index];
                  final isSelected = _selectedPreset == preset;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(preset),
                      selected: isSelected,
                      selectedColor: PulseColors.accentPrimary,
                      backgroundColor: PulseColors.surface,
                      labelStyle: PulseTypography.bodyMedium.copyWith(
                        color: isSelected ? Colors.white : PulseColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onSelected: (selected) {
                        if (selected) _applyPreset(preset);
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),

            // Equalizer Sliders Area
            Container(
              height: 240,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PulseColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E1E30), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_bands.length, (index) {
                  return Column(
                    children: [
                      Text(
                        "${_bandLevels[index] > 0 ? '+' : ''}${_bandLevels[index].round()}dB",
                        style: PulseTypography.monoLabel.copyWith(color: PulseColors.textPrimary),
                      ),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Slider(
                            value: _bandLevels[index],
                            min: -12.0,
                            max: 12.0,
                            activeColor: PulseColors.accentPrimary,
                            inactiveColor: PulseColors.surfaceHigh,
                            onChanged: (val) {
                              setState(() {
                                _selectedPreset = 'Custom';
                                _bandLevels[index] = val;
                              });
                            },
                          ),
                        ),
                      ),
                      Text(
                        _bands[index],
                        style: PulseTypography.monoLabel,
                      ),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: 32),

            // Effects Controls
            _buildEffectSlider("Bass Boost", _bassBoost, (v) => setState(() => _bassBoost = v)),
            const SizedBox(height: 20),
            _buildEffectSlider("Virtualizer", _virtualizer, (v) => setState(() => _virtualizer = v)),
            const SizedBox(height: 20),
            _buildEffectSlider("Reverb", _reverb, (v) => setState(() => _reverb = v)),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectSlider(String title, double val, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
            Text("${val.round()}%", style: PulseTypography.monoLabel.copyWith(color: PulseColors.accentSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: val,
          min: 0,
          max: 100,
          activeColor: PulseColors.accentSecondary,
          inactiveColor: PulseColors.surface,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
