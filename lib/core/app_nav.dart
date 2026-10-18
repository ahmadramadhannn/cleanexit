import 'package:flutter/foundation.dart';

/// Tiny shared navigation bus. Panes deep in the tree (like the dashboard's
/// account banner) can switch the rail destination without prop-drilling
/// callbacks through every layer.
class AppNav extends ChangeNotifier {
  AppNav._();
  static final AppNav I = AppNav._();

  int index = 0;

  void goTo(int i) {
    if (index == i) return;
    index = i;
    notifyListeners();
  }
}
