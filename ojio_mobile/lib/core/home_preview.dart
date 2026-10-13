List<T> homePreviewItems<T>(List<T> items) {
  final count = items.length.clamp(0, 6);
  return items.take(count - count % 2).toList();
}
