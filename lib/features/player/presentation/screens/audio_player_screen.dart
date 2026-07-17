import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/playback_args.dart';
import '../providers/audio_engine_provider.dart';

/// "Now Playing" screen. The engine is app-scoped, so this screen can be
/// popped and re-pushed without interrupting playback (the foundation for
/// the mini-player).
class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({super.key, this.args});
  final PlaybackArgs? args;

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  @override
  void initState() {
    super.initState();
    final args = widget.args;
    if (args != null) {
      // Post-frame so the provider lookup happens after the widget mounts.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AudioEngineProvider>().startQueue(
              args.queue,
              startIndex: args.startIndex,
              resumeMs: args.resumePositionMs,
            );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.equalizer),
            onPressed: () => Navigator.pushNamed(context, Routes.equalizer),
          ),
        ],
      ),
      body: Consumer<AudioEngineProvider>(
        builder: (context, engine, _) {
          final item = engine.currentItem;
          if (item == null) {
            return const Center(
              child: Text('Nothing is playing'),
            );
          }
          final scheme = Theme.of(context).colorScheme;
          return Column(
            children: [
              const Spacer(),
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.secondary],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.music_note,
                    size: 96, color: Colors.white),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              if (item.folderName.isNotEmpty)
                Text(
                  item.folderName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 12),
              if (engine.errorText != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    engine.errorText!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.error, fontSize: 12),
                  ),
                ),
              const Spacer(),
              const _AudioControls(),
            ],
          );
        },
      ),
    );
  }
}

class _AudioControls extends StatelessWidget {
  const _AudioControls();

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<AudioEngineProvider>();
    final pos = engine.position.inMilliseconds.toDouble();
    final dur =
        engine.duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      color: scheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                Formatters.duration(engine.position),
                style: const TextStyle(fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  // .toDouble() — num.clamp returns num for mixed operands.
                  value: pos.clamp(0, dur).toDouble(),
                  max: dur,
                  onChanged: (v) => context
                      .read<AudioEngineProvider>()
                      .seek(Duration(milliseconds: v.toInt())),
                ),
              ),
              Text(
                Formatters.duration(engine.duration),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'Shuffle',
                icon: Icon(
                  engine.shuffle ? Icons.shuffle_on_outlined : Icons.shuffle,
                ),
                onPressed: context.read<AudioEngineProvider>().toggleShuffle,
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 32),
                onPressed: context.read<AudioEngineProvider>().previous,
              ),
              IconButton(
                iconSize: 56,
                icon: Icon(
                  engine.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                ),
                onPressed: context.read<AudioEngineProvider>().playPause,
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, size: 32),
                onPressed: context.read<AudioEngineProvider>().next,
              ),
              IconButton(
                tooltip: 'Repeat',
                icon: Icon(
                  switch (engine.loopMode) {
                    LoopMode.one => Icons.repeat_one,
                    LoopMode.all => Icons.repeat_on_outlined,
                    LoopMode.off => Icons.repeat,
                  },
                ),
                onPressed: context.read<AudioEngineProvider>().cycleLoop,
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.speed, size: 18),
              label: Text('${engine.speed}x'),
              onPressed: () => _speedSheet(context, engine),
            ),
          ),
        ],
      ),
    );
  }

  void _speedSheet(BuildContext context, AudioEngineProvider engine) {
    const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0];
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Wrap(
        children: speeds
            .map((s) => ListTile(
                  title: Text('${s}x'),
                  trailing: engine.speed == s ? const Icon(Icons.check) : null,
                  onTap: () {
                    engine.setSpeed(s);
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }
}
