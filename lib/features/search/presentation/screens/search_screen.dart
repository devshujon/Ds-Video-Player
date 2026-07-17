import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/constants/media_formats.dart';
import '../../../media_library/domain/entities/media_item.dart';
import '../../../media_library/domain/usecases/library_usecases.dart';
import '../../../media_library/presentation/widgets/media_tile.dart';
import '../../../player/domain/entities/playback_args.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _search = sl<SearchMedia>();
  List<MediaItem> _results = [];
  Timer? _debounce;
  bool _loading = false;

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _loading = true);
      final res = await _search(q.trim());
      if (!mounted) return;
      setState(() {
        _results = res.valueOrNull ?? [];
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Search videos, audio, photos…',
            border: InputBorder.none,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? const Center(child: Text('Type to search your media'))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final item = _results[i];
                    return MediaTile(
                      item: item,
                      onTap: () => Navigator.pushNamed(
                        context,
                        item.type == MediaType.audio
                            ? Routes.audioPlayer
                            : Routes.videoPlayer,
                        arguments: PlaybackArgs(
                            queue: _results, startIndex: i),
                      ),
                    );
                  },
                ),
    );
  }
}
