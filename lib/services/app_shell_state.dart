import 'package:flutter/foundation.dart';

/// Lightweight shell state used to suppress notifications for the screen the
/// user is already looking at.
class AppShellState extends ChangeNotifier {
  AppShellState._();

  static final AppShellState instance = AppShellState._();

  int _selectedTab = 0;
  bool _activityOpen = false;
  bool _requestsOpen = false;

  int get selectedTab => _selectedTab;

  bool get activityOpen => _activityOpen;

  bool get requestsOpen => _requestsOpen;

  void setSelectedTab(int index) {
    if (_selectedTab == index) return;
    _selectedTab = index;
    notifyListeners();
  }

  void setActivityOpen(bool value) {
    if (_activityOpen == value) return;
    _activityOpen = value;
    notifyListeners();
  }

  void setRequestsOpen(bool value) {
    if (_requestsOpen == value) return;
    _requestsOpen = value;
    notifyListeners();
  }

  void reset() {
    _selectedTab = 0;
    _activityOpen = false;
    _requestsOpen = false;
    notifyListeners();
  }
}
