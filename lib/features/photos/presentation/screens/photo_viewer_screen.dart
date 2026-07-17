import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class PhotoViewerArgs {
  const PhotoViewerArgs({required this.assets, required this.index});
  final List<AssetEntity> assets;
  final int index;
}

/// Full-screen zoom/swipe viewer with a slideshow toggle.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key, required this.args});
  final PhotoViewerArgs args;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _controller =
      PageController(initialPage: widget.args.index);
  late int _index = widget.args.index;
  bool _slideshow = false;

  void _toggleSlideshow() {
    setState(() => _slideshow = !_slideshow);
    if (_slideshow) _advance();
  }

  Future<void> _advance() async {
    while (_slideshow && mounted) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!_slideshow || !mounted) break;
      final next = (_index + 1) % widget.args.assets.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${_index + 1} / ${widget.args.assets.length}',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(_slideshow ? Icons.pause : Icons.slideshow,
                color: Colors.white),
            onPressed: _toggleSlideshow,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {/* share via share_plus in Phase 5 */},
          ),
        ],
      ),
      body: PhotoViewGallery.builder(
        pageController: _controller,
        itemCount: widget.args.assets.length,
        onPageChanged: (i) => setState(() => _index = i),
        builder: (context, i) {
          return PhotoViewGalleryPageOptions.customChild(
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            child: FutureBuilder(
              future: widget.args.assets[i].file,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                return Image.file(snap.data!, fit: BoxFit.contain);
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _slideshow = false;
    _controller.dispose();
    super.dispose();
  }
}
