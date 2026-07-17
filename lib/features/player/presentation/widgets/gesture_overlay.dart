import 'package:flutter/material.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../settings/presentation/providers/settings_provider.dart';
import '../providers/player_provider.dart';

/// Zone-based gesture engine with edge detection to prevent accidental input.
///
/// • Left 22% vertical drag  → brightness
/// • Right 22% vertical drag → volume
/// • Center horizontal drag  → seek
/// • Center double-tap L/R   → seek ∓N s
/// • Pinch (2 fingers)       → zoom
/// • Long press center       → 2× speed
class GestureOverlay extends StatefulWidget {
  const GestureOverlay({super.key, required this.onToggleControls});
  final VoidCallback onToggleControls;

  @override
  State<GestureOverlay> createState() => _GestureOverlayState();
}

enum _GestureZone { left, center, right }

class _GestureOverlayState extends State<GestureOverlay> {
  static const _edgeFraction = 0.22;

  double _brightness = 0.5;
  double _volume = 0.5;
  String? _hud;
  double _seekAccumSec = 0;
  double _baseScale = 1.0;
  double? _previousSpeed;
  _GestureZone? _activeZone;

  Future<void> _showHud(String text,
      {Duration hold = const Duration(milliseconds: 700)}) async {
    setState(() => _hud = text);
    await Future<void>.delayed(hold);
    if (mounted && _hud == text) setState(() => _hud = null);
  }

  _GestureZone _zoneFor(double x, double width) {
    if (x < width * _edgeFraction) return _GestureZone.left;
    if (x > width * (1 - _edgeFraction)) return _GestureZone.right;
    return _GestureZone.center;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final p = context.read<PlayerProvider>();
    final settings = context.watch<SettingsProvider>();

    if (p.isLocked) return const SizedBox.expand();

    final tapOnly = !settings.gesturesEnabled;
    final seekStep = settings.seekSeconds;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggleControls,
            onLongPressStart: tapOnly
                ? null
                : (d) {
                    if (_zoneFor(d.localPosition.dx, size.width) !=
                        _GestureZone.center) {
                      return;
                    }
                    _previousSpeed = p.speed;
                    p.setSpeed(2.0);
                    _showHud('2× speed', hold: const Duration(seconds: 2));
                  },
            onLongPressEnd: tapOnly
                ? null
                : (_) {
                    final prev = _previousSpeed;
                    if (prev != null) {
                      p.setSpeed(prev);
                      _previousSpeed = null;
                    }
                  },
            onDoubleTapDown: tapOnly
                ? null
                : (d) {
                    if (_zoneFor(d.localPosition.dx, size.width) !=
                        _GestureZone.center) {
                      return;
                    }
                    final left = d.localPosition.dx < size.width / 2;
                    p.seekBy(Duration(seconds: left ? -seekStep : seekStep));
                    _showHud(left ? '⏪ ${seekStep}s' : '${seekStep}s ⏩');
                  },
            onScaleStart: tapOnly
                ? null
                : (_) => _baseScale = p.videoScale,
            onScaleUpdate: tapOnly
                ? null
                : (d) {
                    if (d.pointerCount >= 2) {
                      p.setVideoScale(_baseScale * d.scale);
                      _showHud(
                        '${(p.videoScale * 100).round()}%',
                        hold: const Duration(milliseconds: 400),
                      );
                    }
                  },
            onVerticalDragStart: tapOnly
                ? null
                : (d) => _activeZone = _zoneFor(d.localPosition.dx, size.width),
            onVerticalDragUpdate: tapOnly
                ? null
                : (d) async {
                    final zone = _activeZone;
                    if (zone == null || zone == _GestureZone.center) return;
                    final delta = d.primaryDelta;
                    if (delta == null) return;
                    final step = -delta / size.height;
                    if (zone == _GestureZone.left) {
                      _brightness = (_brightness + step).clamp(0.0, 1.0);
                      await ScreenBrightness()
                          .setApplicationScreenBrightness(_brightness);
                      _showHud('☀ ${(_brightness * 100).round()}%');
                    } else {
                      _volume = (_volume + step).clamp(0.0, 1.0);
                      await FlutterVolumeController.setVolume(_volume);
                      _showHud('🔊 ${(_volume * 100).round()}%');
                    }
                  },
            onVerticalDragEnd: tapOnly ? null : (_) => _activeZone = null,
            onHorizontalDragStart: tapOnly
                ? null
                : (d) {
                    _activeZone = _zoneFor(d.localPosition.dx, size.width);
                    if (_activeZone == _GestureZone.center) {
                      _seekAccumSec = 0;
                    }
                  },
            onHorizontalDragUpdate: tapOnly
                ? null
                : (d) {
                    if (_activeZone != _GestureZone.center) return;
                    final delta = d.primaryDelta;
                    if (delta == null) return;
                    _seekAccumSec += delta / 8;
                    final sign = _seekAccumSec >= 0 ? '+' : '−';
                    _showHud('$sign${_seekAccumSec.abs().round()}s',
                        hold: const Duration(milliseconds: 1500));
                  },
            onHorizontalDragEnd: tapOnly
                ? null
                : (_) {
                    if (_activeZone == _GestureZone.center &&
                        _seekAccumSec.abs() >= 1) {
                      p.seekBy(Duration(seconds: _seekAccumSec.round()));
                    }
                    _seekAccumSec = 0;
                    _activeZone = null;
                  },
          ),
        ),
        if (_hud != null)
          Center(
            child: Semantics(
              liveRegion: true,
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _hud!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
