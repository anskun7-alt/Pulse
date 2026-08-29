import 'dart:io';
import 'package:flutter/material.dart';
import '../services/shortcuts_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/interactive_elements.dart';

class ShortcutsScreen extends StatelessWidget {
  const ShortcutsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final items = isDesktop ? PulseShortcuts.desktopShortcuts : PulseShortcuts.mobileGestures;

    final categories = <String, List<ShortcutItem>>{};
    for (var item in items) {
      categories.putIfAbsent(item.category, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: PulseColors.background,
      appBar: AppBar(
        backgroundColor: PulseColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: PulseColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isDesktop ? "Keyboard Shortcuts" : "Gestures & Controls",
          style: PulseTypography.displaySmall,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      PulseColors.accentPrimary.withValues(alpha: 0.20),
                      PulseColors.accentSecondary.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: PulseColors.accentPrimary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PulseColors.accentPrimary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDesktop ? Icons.keyboard_rounded : Icons.touch_app_rounded,
                        color: PulseColors.accentPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDesktop ? "VLC-Style Desktop Hotkeys" : "Intuitive Media Gestures",
                            style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isDesktop 
                                ? "Control playback, volume, and seeking rapidly with hardware keys."
                                : "Seamless swipe controls for brightness, volume, seeking, and zoom.",
                            style: PulseTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Categories
              for (var entry in categories.entries) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: PulseTypography.monoLabel.copyWith(
                      color: PulseColors.activeAccentSecondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: PulseColors.surfaceHigh.withValues(alpha: PulseColors.isLight ? 0.95 : 0.65),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: PulseColors.isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < entry.value.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: PulseColors.isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.value[i].action,
                                      style: PulseTypography.bodyLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (entry.value[i].description != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        entry.value[i].description!,
                                        style: TextStyle(
                                          color: PulseColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Key badge
                              _buildKeyBadge(entry.value[i].keys),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyBadge(String keys) {
    final parts = keys.split(' + ');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < parts.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text("+", style: TextStyle(color: PulseColors.textSecondary, fontWeight: FontWeight.bold)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: PulseColors.isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: PulseColors.isLight ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.20),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                )
              ],
            ),
            child: Text(
              parts[i],
              style: PulseTypography.monoLabel.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: PulseColors.textPrimary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
