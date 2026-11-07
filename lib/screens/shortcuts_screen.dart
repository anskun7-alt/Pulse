import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/shortcuts_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/interactive_elements.dart';

class ShortcutsScreen extends StatefulWidget {
  const ShortcutsScreen({Key? key}) : super(key: key);

  @override
  State<ShortcutsScreen> createState() => _ShortcutsScreenState();
}

class _ShortcutsScreenState extends State<ShortcutsScreen> {
  @override
  void initState() {
    super.initState();
    PulseShortcuts.init();
  }

  void _editShortcut(BuildContext context, ShortcutItem item) {
    String capturedKey = item.keys;
    final focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return KeyboardListener(
              focusNode: focusNode..requestFocus(),
              autofocus: true,
              onKeyEvent: (event) {
                if (event is! KeyDownEvent) return;
                final key = event.logicalKey;
                final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
                final isShift = HardwareKeyboard.instance.isShiftPressed;
                final isAlt = HardwareKeyboard.instance.isAltPressed;

                // Ignore pure modifier presses
                if (key == LogicalKeyboardKey.controlLeft ||
                    key == LogicalKeyboardKey.controlRight ||
                    key == LogicalKeyboardKey.shiftLeft ||
                    key == LogicalKeyboardKey.shiftRight ||
                    key == LogicalKeyboardKey.altLeft ||
                    key == LogicalKeyboardKey.altRight ||
                    key == LogicalKeyboardKey.metaLeft ||
                    key == LogicalKeyboardKey.metaRight) {
                  return;
                }

                String label = key.keyLabel;
                if (key == LogicalKeyboardKey.space) label = 'Space';
                if (key == LogicalKeyboardKey.arrowRight) label = '→';
                if (key == LogicalKeyboardKey.arrowLeft) label = '←';
                if (key == LogicalKeyboardKey.arrowUp) label = '↑';
                if (key == LogicalKeyboardKey.arrowDown) label = '↓';
                if (key == LogicalKeyboardKey.escape) label = 'Esc';
                if (key == LogicalKeyboardKey.enter) label = 'Enter';

                final List<String> parts = [];
                if (isCtrl) parts.add('Ctrl');
                if (isAlt) parts.add('Alt');
                if (isShift) parts.add('Shift');
                parts.add(label);

                setDialogState(() {
                  capturedKey = parts.join(' + ');
                });
              },
              child: AlertDialog(
                backgroundColor: PulseColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: PulseColors.accentSecondary.withValues(alpha: 0.3)),
                ),
                title: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: PulseColors.accentSecondary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Edit: ${item.action}",
                        style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.description != null) ...[
                      Text(item.description!, style: TextStyle(color: PulseColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 16),
                    ],
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PulseColors.accentSecondary.withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Press desired key combination...",
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: PulseColors.accentGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: PulseColors.accentSecondary.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Text(
                              capturedKey,
                              style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      // Reset this action to default
                      final match = PulseShortcuts.desktopShortcuts.firstWhere(
                        (s) => s.id == item.id,
                        orElse: () => item,
                      );
                      await PulseShortcuts.saveBinding(item.id, match.keys);
                      Navigator.pop(dialogContext);
                      setState(() {});
                    },
                    child: const Text("Default", style: TextStyle(color: Colors.white60)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PulseColors.accentSecondary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      await PulseShortcuts.saveBinding(item.id, capturedKey);
                      Navigator.pop(dialogContext);
                      setState(() {});
                    },
                    child: const Text("Save Shortcut", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: PulseShortcuts.customBindingsNotifier,
      builder: (context, customBindings, _) {
        final items = isDesktop ? PulseShortcuts.getActiveShortcuts() : PulseShortcuts.mobileGestures;

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
            actions: [
              if (isDesktop && customBindings.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: const Text("Reset All"),
                  style: TextButton.styleFrom(foregroundColor: PulseColors.accentSecondary),
                  onPressed: () async {
                    await PulseShortcuts.resetAllBindings();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("All shortcuts reset to defaults")),
                    );
                  },
                ),
            ],
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
                                isDesktop ? "Customizable Hotkeys" : "Intuitive Media Gestures",
                                style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isDesktop
                                    ? "Click any shortcut below to rebind it to your own custom keys. Saved permanently."
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
                          color: PulseColors.isLight
                              ? Colors.black.withValues(alpha: 0.06)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < entry.value.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: PulseColors.isLight
                                    ? Colors.black.withValues(alpha: 0.05)
                                    : Colors.white.withValues(alpha: 0.05),
                              ),
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: isDesktop ? () => _editShortcut(context, entry.value[i]) : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                entry.value[i].action,
                                                style: PulseTypography.bodyLarge.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              if (isDesktop && customBindings.containsKey(entry.value[i].id)) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: PulseColors.accentSecondary.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    "Custom",
                                                    style: TextStyle(
                                                      color: PulseColors.accentSecondary,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
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
                                    _buildKeyBadge(entry.value[i].keys, isDesktop),
                                  ],
                                ),
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
      },
    );
  }

  Widget _buildKeyBadge(String keys, bool isInteractive) {
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
                ),
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
        if (isInteractive) ...[
          const SizedBox(width: 8),
          Icon(Icons.edit_outlined, size: 16, color: PulseColors.textSecondary.withValues(alpha: 0.6)),
        ],
      ],
    );
  }
}
