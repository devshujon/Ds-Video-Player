import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/media_formats.dart';
import '../providers/player_provider.dart';

class SubtitleSheet extends StatelessWidget {
  const SubtitleSheet({super.key});

  static Future<void> show(BuildContext context) {
    final player = context.read<PlayerProvider>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider<PlayerProvider>.value(
        value: player,
        child: const SubtitleSheet(),
      ),
    );
  }

  Future<void> _pickFile(BuildContext context) async {
    final player = context.read<PlayerProvider>();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: MediaFormats.subtitleExtensions.toList(),
    );
    final path = result?.files.single.path;
    if (path != null) {
      await player.loadSubtitle(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subtitles',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable subtitles'),
                value: p.subtitleEnabled,
                onChanged: (v) async {
                  if (v) {
                    await context.read<PlayerProvider>().enableSubtitle();
                  } else {
                    await context.read<PlayerProvider>().disableSubtitle();
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.subtitles_outlined),
                title: Text(
                  p.currentSubtitleUri?.split('/').last ?? 'No file loaded',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: TextButton(
                  onPressed: () => _pickFile(context),
                  child: const Text('External'),
                ),
              ),
              if (p.subtitleTracks.isNotEmpty) ...[
                const Text('Embedded tracks',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                for (final track in p.subtitleTracks)
                  if (track.id != 'auto' && track.id != 'no')
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(track.title ?? track.language ?? track.id),
                      trailing: p.currentSubtitleUri == track.id
                          ? const Icon(Icons.check, size: 18)
                          : null,
                      onTap: () => context
                          .read<PlayerProvider>()
                          .loadEmbeddedSubtitle(track),
                    ),
              ],
              const Divider(height: 24),
              Text('Delay: ${p.subtitleDelaySec.toStringAsFixed(1)}s'),
              Slider(
                min: -5,
                max: 5,
                divisions: 20,
                value: p.subtitleDelaySec.clamp(-5.0, 5.0),
                label: '${p.subtitleDelaySec.toStringAsFixed(1)}s',
                onChanged: (v) =>
                    context.read<PlayerProvider>().setSubtitleDelay(v),
              ),
              Text('Size: ${(p.subtitleFontScale * 100).round()}%'),
              Slider(
                min: 0.5,
                max: 2.5,
                value: p.subtitleFontScale.clamp(0.5, 2.5),
                onChanged: (v) =>
                    context.read<PlayerProvider>().setSubtitleFontScale(v),
              ),
              Text('Background opacity'),
              Slider(
                min: 0,
                max: 1,
                value: p.subtitleBackgroundOpacity.clamp(0.0, 1.0),
                onChanged: (v) => context
                    .read<PlayerProvider>()
                    .setSubtitleBackgroundOpacity(v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Outline'),
                value: p.subtitleOutline,
                onChanged: (v) =>
                    context.read<PlayerProvider>().setSubtitleOutline(v),
              ),
              Wrap(
                spacing: 8,
                children: [
                  _ColorChip(
                    label: 'White',
                    color: Colors.white,
                    selected: p.subtitleColorArgb == 0xFFFFFFFF,
                    onTap: () => context
                        .read<PlayerProvider>()
                        .setSubtitleColor(0xFFFFFFFF),
                  ),
                  _ColorChip(
                    label: 'Yellow',
                    color: Colors.yellow,
                    selected: p.subtitleColorArgb == 0xFFFFFF00,
                    onTap: () => context
                        .read<PlayerProvider>()
                        .setSubtitleColor(0xFFFFFF00),
                  ),
                  _ColorChip(
                    label: 'Cyan',
                    color: Colors.cyan,
                    selected: p.subtitleColorArgb == 0xFF00FFFF,
                    onTap: () => context
                        .read<PlayerProvider>()
                        .setSubtitleColor(0xFF00FFFF),
                  ),
                ],
              ),
              if (p.audioTracks.length > 1) ...[
                const Divider(height: 24),
                const Text('Audio track',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                for (final track in p.audioTracks)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(track.title ?? track.language ?? track.id),
                    trailing: p.currentAudioTrackId == track.id
                        ? const Icon(Icons.check, size: 18)
                        : null,
                    onTap: () =>
                        context.read<PlayerProvider>().setAudioTrack(track),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: CircleAvatar(backgroundColor: color, radius: 8),
    );
  }
}
