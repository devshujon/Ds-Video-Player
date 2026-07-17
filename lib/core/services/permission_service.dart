import 'package:permission_handler/permission_handler.dart';

/// Handles Android's split media permissions (13+) vs legacy storage (≤32).
class PermissionService {
  Future<bool> requestMediaAccess() async {
    // Android 13+: granular media perms. Older: READ_EXTERNAL_STORAGE.
    final results = await [
      Permission.videos,
      Permission.audio,
      Permission.photos,
      Permission.storage,
    ].request();

    final granted = results.entries.any(
      (e) => e.value.isGranted || e.value.isLimited,
    );
    return granted;
  }

  Future<bool> requestNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> get hasMediaAccess async {
    return await Permission.videos.isGranted ||
        await Permission.audio.isGranted ||
        await Permission.photos.isGranted ||
        await Permission.storage.isGranted;
  }

  Future<void> openSettings() => openAppSettings();
}
