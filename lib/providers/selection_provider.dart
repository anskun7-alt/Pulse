import 'package:flutter/foundation.dart';

/// Manages the multi-select state across media tabs.
/// Holds a [Set] of selected file paths and notifies listeners on change.
class SelectionProvider extends ChangeNotifier {
  final Set<String> _selectedIds = {};

  bool get isActive => _selectedIds.isNotEmpty;
  int get count => _selectedIds.length;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);




  bool isSelected(String id) => _selectedIds.contains(id);

  void toggle(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll(Iterable<String> ids) {
    _selectedIds.addAll(ids);
    notifyListeners();
  }

  void clear() {
    _selectedIds.clear();
    notifyListeners();
  }
}