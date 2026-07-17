import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../media_library/domain/usecases/library_usecases.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/playback_args.dart';
import '../providers/player_provider.dart';
import '../widgets/gesture_overlay.dart';
import '../widgets/player_controls.dart';
import '../widgets/subtitle_sheet.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.args});
  final PlaybackArgs args;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _enterPip() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Picture-in-Picture is coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return ChangeNotifierProvider(
      create: (_) => PlayerProvider(
        sl<SaveResume>(),
        forceSoftwareDecode: settings.forceSoftwareDecode,
        resumeEnabled: settings.resumePlayback,
      )..start(widget.args),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<PlayerProvider>(
          builder: (context, p, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                _VideoSurface(player: p),
                if (p.isBuffering)
                  const Center(child: CircularProgressIndicator()),
                if (p.errorText != null)
                  Center(
                    child: Text(
                      p.errorText!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                GestureOverlay(
                  onToggleControls: () =>
                      setState(() => _showControls = !_showControls),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  left: 0,
                  right: 0,
                  top: _showControls && !p.isLocked ? 0 : -80,
                  child: _TopBar(
                    title: p.currentItem?.title ?? '',
                    isRotationLocked: p.isRotationLocked,
                    aspectLabel: _aspectLabel(p.aspectMode),
                    onSubtitles: () => SubtitleSheet.show(context),
                    onPip: _enterPip,
                    onToggleRotation:
                        context.read<PlayerProvider>().toggleRotationLock,
                    onCycleAspect: context.read<PlayerProvider>().cycleAspectMode,
                    onSleepTimer: () => _sleepSheet(context, p),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  left: 0,
                  right: 0,
                  bottom: _showControls && !p.isLocked ? 0 : -240,
                  child: const PlayerControls(),
                ),
                Positioned(
                  right: 12,
                  top: MediaQuery.sizeOf(context).height / 2 - 24,
                  child: IconButton(
                    icon: Icon(
                      p.isLocked ? Icons.lock : Icons.lock_open,
                      color: Colors.white,
                    ),
                    onPressed: context.read<PlayerProvider>().toggleLock,
                  ),
                ),
                if (p.sleepRemaining != null)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 48,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Sleep ${p.sleepRemaining!.inMinutes}:${(p.sleepRemaining!.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _aspectLabel(AspectRatioMode mode) => switch (mode) {
        AspectRatioMode.fit => 'Fit',
        AspectRatioMode.fill => 'Fill',
        AspectRatioMode.ratio16x9 => '16:9',
        AspectRatioMode.ratio4x3 => '4:3',
        AspectRatioMode.original => 'Original',
      };

  void _sleepSheet(BuildContext context, PlayerProvider p) {
    const options = <(String, Duration?)>[
      ('Off', null),
      ('15 min', Duration(minutes: 15)),
      ('30 min', Duration(minutes: 30)),
      ('45 min', Duration(minutes: 45)),
      ('60 min', Duration(minutes: 60)),
    ];
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map(
                (o) => ListTile(
                  title: Text(o.$1),
                  onTap: () {
                    context.read<PlayerProvider>().setSleepTimer(o.$2);
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({required this.player});
  final PlayerProvider player;

  @override
  Widget build(BuildContext context) {
    final ar = switch (player.aspectMode) {
      AspectRatioMode.fit => null,
      AspectRatioMode.fill => null,
      AspectRatioMode.ratio16x9 => 16 / 9,
      AspectRatioMode.ratio4x3 => 4 / 3,
      AspectRatioMode.original => player.videoController.rect.value?.width != null &&
              player.videoController.rect.value!.width > 0
          ? player.videoController.rect.value!.width /
              player.videoController.rect.value!.height
          : null,
    };

    Widget video = Video(
      controller: player.videoController,
      controls: NoVideoControls,
      fit: player.aspectMode == AspectRatioMode.fill
          ? BoxFit.cover
          : BoxFit.contain,
    );

    if (ar != null) {
      video = AspectRatio(aspectRatio: ar, child: video);
    }

    return Center(
      child: Transform.scale(
        scale: player.videoScale,
        child: video,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.isRotationLocked,
    required this.aspectLabel,
    required this.onSubtitles,
    required this.onPip,
    required this.onToggleRotation,
    required this.onCycleAspect,
    required this.onSleepTimer,
  });

  final String title;
  final bool isRotationLocked;
  final String aspectLabel;
  final VoidCallback onSubtitles;
  final VoidCallback onPip;
  final VoidCallback onToggleRotation;
  final VoidCallback onCycleAspect;
  final VoidCallback onSleepTimer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          TextButton(
            onPressed: onCycleAspect,
            child: Text(aspectLabel,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          IconButton(
            tooltip: 'Sleep timer',
            icon: const Icon(Icons.bedtime_outlined, color: Colors.white),
            onPressed: onSleepTimer,
          ),
          IconButton(
            tooltip: isRotationLocked ? 'Unlock rotation' : 'Lock rotation',
            icon: Icon(
              isRotationLocked
                  ? Icons.screen_lock_rotation
                  : Icons.screen_rotation,
              color: Colors.white,
            ),
            onPressed: onToggleRotation,
          ),
          IconButton(
            tooltip: 'Subtitles',
            icon: const Icon(Icons.subtitles_outlined, color: Colors.white),
            onPressed: onSubtitles,
          ),
          if (AppConstants.pictureInPictureEnabled)
            IconButton(
              tooltip: 'Picture-in-Picture',
              icon: const Icon(Icons.picture_in_picture_alt,
                  color: Colors.white),
              onPressed: onPip,
            ),
        ],
      ),
    );
  }
}
