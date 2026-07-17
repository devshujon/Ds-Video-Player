import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/constants/media_formats.dart';
import '../../../media_library/domain/entities/media_item.dart';
import '../../../player/domain/entities/playback_args.dart';
import '../../data/recent_streams_store.dart';
import '../../data/stream_url.dart';
import '../providers/stream_url_provider.dart';

class StreamUrlScreen extends StatelessWidget {
  const StreamUrlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StreamUrlProvider(sl<RecentStreamsStore>()),
      child: const _StreamUrlView(),
    );
  }
}

class _StreamUrlView extends StatefulWidget {
  const _StreamUrlView();

  @override
  State<_StreamUrlView> createState() => _StreamUrlViewState();
}

class _StreamUrlViewState extends State<_StreamUrlView> {
  final _controller = TextEditingController();
  bool _valid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final ok = StreamUrl.isValid(_controller.text);
      if (ok != _valid) setState(() => _valid = ok);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _controller.text = text;
      _controller.selection = TextSelection.collapsed(offset: text.length);
    }
  }

  Future<void> _play(BuildContext context, String rawUrl) async {
    final url = rawUrl.trim();
    if (!StreamUrl.isValid(url)) return;
    await context.read<StreamUrlProvider>().remember(url);
    if (!context.mounted) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final item = MediaItem(
      uri: url,
      title: StreamUrl.titleFor(url),
      type: MediaType.video,
      folderPath: 'Network',
      sizeBytes: 0,
      durationMs: 0,
      dateAddedMs: now,
      dateModifiedMs: now,
    );
    Navigator.pushNamed(
      context,
      Routes.videoPlayer,
      arguments: PlaybackArgs(queue: [item]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open network URL'),
        actions: [
          Consumer<StreamUrlProvider>(
            builder: (context, p, _) => p.recent.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear history',
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: p.clear,
                  ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Stream URL',
                    hintText: 'https://example.com/stream.m3u8',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: 'Paste',
                      icon: const Icon(Icons.content_paste),
                      onPressed: _pasteFromClipboard,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Supports HTTP/HTTPS, HLS (.m3u8), DASH, RTSP and RTMP.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                  onPressed: _valid
                      ? () => _play(context, _controller.text)
                      : null,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<StreamUrlProvider>(
              builder: (context, p, _) {
                if (p.recent.isEmpty) {
                  return Center(
                    child: Text(
                      'Recent streams appear here',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: p.recent.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final url = p.recent[i];
                    return ListTile(
                      leading: const Icon(Icons.link),
                      title: Text(
                        StreamUrl.titleFor(url),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () => _play(context, url),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            context.read<StreamUrlProvider>().forget(url),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
