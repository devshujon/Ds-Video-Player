import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../media_library/domain/usecases/library_usecases.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/services/native_player_bridge.dart';
import '../../data/services/playback_state_store.dart';
import '../../data/services/video_playback_service.dart';
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

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  bool _showControls = true;
  bool _inPip = false;
  StreamSubscription<bool>? _pipSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    NativePlayerBridge.ensureHandler();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPlayback());
    _pipSub = NativePlayerBridge.pipModeStream.listen((pip) {
      if (!mounted) return;
      setState(() {
        _inPip = pip;
        if (pip) _showControls = false;
      });
    });
  }

  Future<void> _initPlayback() async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    if (settings.backgroundAudio) {
      await VideoPlaybackService.ensureStarted();
      await NativePlayerBridge.setAutoPipOnLeave(true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // media_kit + foreground service keep playback alive in background.
    if (state == AppLifecycleState.resumed && !_inPip) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pipSub?.cancel();
    unawaited(NativePlayerBridge.setAutoPipOnLeave(false));
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _enterPip() async {
    final ok = await NativePlayerBridge.enterPip();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Picture-in-Picture is not available')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return ChangeNotifierProvider(
      create: (_) => PlayerProvider(
        saveResume: sl<SaveResume>(),
        stateStore: sl<PlaybackStateStore>(),
        decoderMode: settings.decoderMode,
        resumeEnabled: settings.resumePlayback,
        backgroundEnabled: settings.backgroundAudio,
      )..start(widget.args),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<PlayerProvider>(
          builder: (context, p, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                _VideoSurface(player: p),
                if (p.isBuffering && !_inPip)
                  const Center(child: CircularProgressIndicator()),
                if (p.errorText != null && !_inPip)
                  Center(
                    child: Text(
                      p.errorText!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                if (!_inPip)
                  GestureOverlay(
                    onToggleControls: () =>
                        setState(() => _showControls = !_showControls),
                  ),
                if (!_inPip)
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
                if (!_inPip)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    left: 0,
                    right: 0,
                    bottom: _showControls && !p.isLocked ? 0 : -240,
                    child: const PlayerControls(),
                  ),
                if (!_inPip)
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
                if (p.sleepRemaining != null && !_inPip)
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
      AspectRatioMode.original =>
        player.videoController.rect.value?.width != null &&
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
      subtitleViewConfiguration: SubtitleViewConfiguration(
        style: TextStyle(
          color: Color(player.subtitleColorArgb),
          fontSize: 16 * player.subtitleFontScale,
          fontWeight: FontWeight.w600,
          shadows: player.subtitleOutline
              ? const [
                  Shadow(blurRadius: 2, color: Colors.black),
                  Shadow(blurRadius: 4, color: Colors.black),
                ]
              : null,
          backgroundColor: Colors.black.withValues(
            alpha: player.subtitleBackgroundOpacity,
          ),
        ),
      ),
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
