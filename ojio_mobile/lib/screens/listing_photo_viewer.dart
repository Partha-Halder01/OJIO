import 'package:flutter/material.dart';
import '../widgets/app_image_view.dart';

class ListingPhotoViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  ListingPhotoViewer({super.key, required this.images, this.initialIndex = 0})
    : assert(images.length > 0);
  @override
  State<ListingPhotoViewer> createState() => _ListingPhotoViewerState();
}

class _ListingPhotoViewerState extends State<ListingPhotoViewer> {
  late final PageController _pages;
  late int _index;
  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${_index + 1} / ${widget.images.length}'),
    ),
    body: PageView.builder(
      controller: _pages,
      itemCount: widget.images.length,
      onPageChanged: (index) => setState(() => _index = index),
      itemBuilder: (_, index) => InteractiveViewer(
        key: ValueKey(index),
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: AppImageView(
            url: widget.images[index],
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Previous photo',
              color: Colors.white,
              onPressed: _index == 0
                  ? null
                  : () => _pages.previousPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    ),
              icon: const Icon(Icons.chevron_left),
            ),
            const Text(
              'Swipe photos · pinch to zoom',
              style: TextStyle(color: Colors.white70),
            ),
            IconButton(
              tooltip: 'Next photo',
              color: Colors.white,
              onPressed: _index == widget.images.length - 1
                  ? null
                  : () => _pages.nextPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    ),
  );
}
