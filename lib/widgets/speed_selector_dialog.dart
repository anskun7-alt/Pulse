import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class SpeedSelectorSheet extends StatefulWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedChanged;

  const SpeedSelectorSheet({
    Key? key,
    required this.currentSpeed,
    required this.onSpeedChanged,
  }) : super(key: key);

  @override
  State<SpeedSelectorSheet> createState() => _SpeedSelectorSheetState();
}

class _SpeedSelectorSheetState extends State<SpeedSelectorSheet> {
  late double _speed;

  static const List<double> _presets = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];

  @override
  void initState() {
    super.initState();
    _speed = widget.currentSpeed;
  }

  void _updateSpeed(double val) {
    // Round to nearest 0.05
    final rounded = (val * 20).round() / 20.0;
    setState(() => _speed = rounded);
    widget.onSpeedChanged(rounded);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: PulseColors.surfaceHigh.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: const Color(0xFF2C2C42).withValues(alpha: 0.6)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Current Speed indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Playback Speed", style: PulseTypography.displaySmall),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: PulseColors.accentGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      "${_speed.toStringAsFixed(2)}x",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Fine-tuning Slider
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white70),
                    onPressed: () {
                      if (_speed > 0.25) _updateSpeed(_speed - 0.05);
                    },
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: PulseColors.accentSecondary,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: PulseColors.accentSecondary,
                        overlayColor: PulseColors.accentSecondary.withValues(alpha: 0.2),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _speed.clamp(0.25, 3.0),
                        min: 0.25,
                        max: 3.0,
                        divisions: 55, // (3.0 - 0.25) / 0.05 = 55 steps
                        onChanged: _updateSpeed,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white70),
                    onPressed: () {
                      if (_speed < 3.0) _updateSpeed(_speed + 0.05);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Preset Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _presets.map((preset) {
                  final isSelected = (_speed - preset).abs() < 0.02;
                  return ChoiceChip(
                    label: Text(
                      "${preset}x",
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: PulseColors.accentSecondary,
                    backgroundColor: PulseColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? PulseColors.accentSecondary : Colors.white12,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) _updateSpeed(preset);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Reset to 1.0x Button
              TextButton.icon(
                onPressed: () => _updateSpeed(1.0),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white60, size: 18),
                label: const Text(
                  "Reset to Normal (1.0x)",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
