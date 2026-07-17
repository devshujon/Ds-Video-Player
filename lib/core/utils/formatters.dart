/// Pure formatting helpers used across the UI.
class Formatters {
  Formatters._();

  static String duration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  static String durationMs(int ms) =>
      duration(Duration(milliseconds: ms < 0 ? 0 : ms));

  static String fileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    final fixed = size >= 100 || i == 0 ? 0 : 1;
    return '${size.toStringAsFixed(fixed)} ${units[i]}';
  }

  /// 0.0–1.0 watched fraction for the resume progress bar.
  static double progress(int positionMs, int durationMs) {
    if (durationMs <= 0) return 0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }
}
