import 'package:ds_video_player/features/media_library/presentation/home_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeNavigationState', () {
    test('fresh state lands on dashboard', () {
      final nav = HomeNavigationState();
      expect(nav.onDashboard, isTrue);
      expect(nav.activeLibraryTab, isNull);
    });

    test('selecting a tab leaves dashboard', () {
      final nav = HomeNavigationState();
      nav.selectLibraryTab(0);
      expect(nav.onDashboard, isFalse);
      expect(nav.activeLibraryTab, 0);
    });

    test('goToDashboard clears tab selection', () {
      final nav = HomeNavigationState()
        ..selectLibraryTab(2);
      nav.goToDashboard();
      expect(nav.onDashboard, isTrue);
      expect(nav.activeLibraryTab, isNull);
    });

    test('tab selection is session-only and never auto-restored', () {
      // Simulates a new process / widget state after kill: new instance.
      final session = HomeNavigationState()..selectLibraryTab(0);
      expect(session.activeLibraryTab, 0);

      final afterKill = HomeNavigationState();
      expect(afterKill.onDashboard, isTrue);
    });
  });
}
