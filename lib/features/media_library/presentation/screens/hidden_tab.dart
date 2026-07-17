import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../../player/domain/entities/playback_args.dart';
import '../providers/media_library_provider.dart';
import '../widgets/library_tab_scaffold.dart';

class HiddenTab extends StatelessWidget {
  const HiddenTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaLibraryProvider>(
      builder: (context, lib, _) {
        return LibraryTabScaffold(
          items: lib.hiddenItems,
          emptyLabel: 'Hidden folders and videos appear here',
          onTap: (item, i) => Navigator.pushNamed(
            context,
            Routes.videoPlayer,
            arguments: PlaybackArgs(queue: lib.hiddenItems, startIndex: i),
          ),
        );
      },
    );
  }
}
