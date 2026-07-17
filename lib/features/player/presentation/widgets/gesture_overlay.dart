import 'package:flutter/material.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../settings/presentation/providers/settings_provider.dart';
import '../providers/player_provider.dart';

/// Player gesture engine:
/// - left vertical drag  → brightness
/// - right vertical drag → volume
/// - horizontal drag     → seek (live HUD)
/// - double-tap L/R      → seek ∓N s (N = settings.seekSeconds)
/// - pinch               → zoom
/// - long press          → 2× speed
/// - single tap          → toggle controls
class GestureOverlay extends StatefulWidget {
  const GestureOverlay({super.key, required this.onToggleControls});
  final VoidCallback onToggleControls;

  @override
  State<GestureOverlay> createState() => _GestureOverlayState();
}

class _GestureOverlayState extends State<GestureOverlay> {
  double _brightness = 0.5;
  double _volume = 0.5;
  String? _hud;
  double _seekAccumSec = 0;
  double _baseScale = 1.0;
  double? _previousSpeed;

  Future<void> _showHud(String text,
      {Duration hold = const Duration(milliseconds: 700)}) async {
    setState(() => _hud = text);
    await Future<void>.delayed(hold);
    if (mounted && _hud == text) setState(() => _hud = null);
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
                : (_) {
                    _previousSpeed = p.speed;
                    p.setSpeed(2.0);
                    _showHud('2× speed', hold: const Duration(seconds: 2));
                  },
            onLongPressEnd: tapOnly
                ? null
                : (_) {
                    if (_previousSpeed != null) {
                      p.setSpeed(_previousSpeed!);
                      _previousSpeed = null;
                    }
                  },
            onDoubleTapDown: tapOnly
                ? null
                : (d) {
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
            onVerticalDragUpdate: tapOnly
                ? null
                : (d) async {
                    final left = d.localPosition.dx < size.width / 2;
                    final delta = -d.primaryDelta! / size.height;
                    if (left) {
                      _brightness = (_brightness + delta).clamp(0.0, 1.0);
                      await ScreenBrightness()
                          .setApplicationScreenBrightness(_brightness);
                      _showHud('☀ ${(_brightness * 100).round()}%');
                    } else {
                      _volume = (_volume + delta).clamp(0.0, 1.0);
                      await FlutterVolumeController.setVolume(_volume);
                      _showHud('🔊 ${(_volume * 100).round()}%');
                    }
                  },
            onHorizontalDragStart: tapOnly ? null : (_) => _seekAccumSec = 0,
            onHorizontalDragUpdate: tapOnly
                ? null
                : (d) {
                    _seekAccumSec += d.primaryDelta! / 8;
                    final sign = _seekAccumSec >= 0 ? '+' : '−';
                    _showHud('$sign${_seekAccumSec.abs().round()}s',
                        hold: const Duration(milliseconds: 1500));
                  },
            onHorizontalDragEnd: tapOnly
                ? null
                : (_) {
                    if (_seekAccumSec.abs() >= 1) {
                      p.seekBy(Duration(seconds: _seekAccumSec.round()));
                    }
                    _seekAccumSec = 0;
                  },
          ),
        ),
        if (_hud != null)
          Center(
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
      ],
    );
  }
}
