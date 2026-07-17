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
                child: const Text('Choose file'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
