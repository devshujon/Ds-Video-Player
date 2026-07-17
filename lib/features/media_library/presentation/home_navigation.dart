/// Session-only shell navigation for [HomeScreen].
///
/// [libraryTab] is `null` on every fresh process start (cold or warm after kill).
/// It is kept in memory while the app stays alive so background resume restores
/// the last library tab. It is never written to disk.
class HomeNavigationState {
  int? libraryTab;

  static const int tabCount = 6;

  bool get onDashboard => libraryTab == null;

  int? get activeLibraryTab => libraryTab;

  void selectLibraryTab(int index) {
    assert(index >= 0 && index < tabCount);
    libraryTab = index;
  }

  void goToDashboard() {
    libraryTab = null;
  }
}
