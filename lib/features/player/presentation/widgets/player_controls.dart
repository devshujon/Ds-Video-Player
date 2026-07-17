import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/formatters.dart';
// Imported with a prefix as requested (compile-fix #2). NOTE: the prefix
// also requires qualifying `PlayerProvider` itself — `player_provider.`
// below — or its references would become unresolved.
import '../providers/player_provider.dart' as player_provider;

/// Bottom controls: scrubber, transport, speed, repeat, shuffle.
class PlayerControls extends StatelessWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<player_provider.PlayerProvider>();
    final pos = p.position.inMilliseconds.toDouble();
    // .toDouble() — `num.clamp` returns `num` for mixed int/double operands;
    // Slider.value / .max require `double`.
    final dur =
        p.duration.inMilliseconds.toDouble().clamp(1, double.infinity).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(Formatters.duration(p.position),
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: pos.clamp(0, dur).toDouble(),
                  max: dur,
                  onChanged: (v) =>
                      context.read<player_provider.PlayerProvider>().seek(
                            Duration(milliseconds: v.toInt()),
                          ),
                ),
              ),
              Text(Formatters.duration(p.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _IconBtn(
                icon: p.shuffle ? Icons.shuffle_on_outlined : Icons.shuffle,
                onTap:
                    context.read<player_provider.PlayerProvider>().toggleShuffle,
              ),
              _IconBtn(
                icon: Icons.skip_previous,
                onTap: context.read<player_provider.PlayerProvider>().previous,
              ),
              _IconBtn(
                icon: p.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                size: 56,
                onTap: context.read<player_provider.PlayerProvider>().playPause,
              ),
              _IconBtn(
                icon: Icons.skip_next,
                onTap: context.read<player_provider.PlayerProvider>().next,
              ),
              _IconBtn(
                icon: p.repeat == player_provider.RepeatMode.one
                    ? Icons.repeat_one
                    : p.repeat == player_provider.RepeatMode.all
                        ? Icons.repeat_on_outlined
                        : Icons.repeat,
                onTap:
                    context.read<player_provider.PlayerProvider>().cycleRepeat,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.speed, color: Colors.white, size: 18),
              label: Text('${p.speed}x',
                  style: const TextStyle(color: Colors.white)),
              onPressed: () => _speedSheet(context, p),
            ),
          ),
        ],
      ),
    );
  }

  void _speedSheet(BuildContext context, player_provider.PlayerProvider p) {
    const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0, 4.0];
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Wrap(
        children: speeds
            .map((s) => ListTile(
                  title: Text('${s}x'),
                  trailing: p.speed == s ? const Icon(Icons.check) : null,
                  onTap: () {
                    context.read<player_provider.PlayerProvider>().setSpeed(s);
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap, this.size = 32});
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon, color: Colors.white, size: size),
        onPressed: onTap,
      );
}
