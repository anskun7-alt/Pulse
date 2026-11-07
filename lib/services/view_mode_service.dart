import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class ViewModeService {
  static final ViewModeService instance = ViewModeService._internal();
  ViewModeService._internal();

  final ValueNotifier<bool> isGrid = ValueNotifier<bool>(true);
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    try {
      if (Hive.isBoxOpen('settings_box')) {
        final box = Hive.box('settings_box');
        isGrid.value = box.get('view_mode_grid', defaultValue: true) as bool;
      }
    } catch (_) {}
    _initialized = true;
  }

  void toggleViewMode() {
    isGrid.value = !isGrid.value;
    try {
      if (Hive.isBoxOpen('settings_box')) {
        final box = Hive.box('settings_box');
        box.put('view_mode_grid', isGrid.value);
      }
    } catch (_) {}
  }

  void setViewMode(bool grid) {
    if (isGrid.value == grid) return;
    isGrid.value = grid;
    try {
      if (Hive.isBoxOpen('settings_box')) {
        final box = Hive.box('settings_box');
        box.put('view_mode_grid', grid);
      }
    } catch (_) {}
  }
}
