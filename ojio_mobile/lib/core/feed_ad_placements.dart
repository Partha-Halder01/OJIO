import 'dart:math';

class FeedAdPlacements {
  final List<int> _positions;

  FeedAdPlacements({Random? random})
    : _positions = _choosePositions(random ?? Random());

  static List<int> _choosePositions(Random random) {
    var position = 8 + random.nextInt(5);
    final positions = [position];
    for (var index = 1; index < 3; index++) {
      position += 10 + random.nextInt(5);
      positions.add(position);
    }
    return positions;
  }

  List<int> boundaries({required int itemCount, required int columns}) {
    return _positions
        .map((position) => ((position + columns - 1) ~/ columns) * columns)
        .where((position) => position <= itemCount - columns)
        .toSet()
        .toList();
  }
}
