/// Things for Ullu that unlock as a student's star total grows. Nothing is
/// spent: stars only ever go up, and badges count them.
class OwlItem {
  const OwlItem(this.id, this.name, this.stars);

  final String id;
  final String name;

  /// Total stars needed to unlock.
  final int stars;

  bool unlockedAt(int total) => total >= stars;
}

abstract final class Wardrobe {
  static const colours = [
    OwlItem('purple', 'Purple', 0),
    OwlItem('blue', 'Sky blue', 10),
    OwlItem('green', 'Leaf green', 40),
    OwlItem('pink', 'Pink', 80),
    OwlItem('orange', 'Sunset', 150),
    OwlItem('gold', 'Gold', 300),
  ];

  static const hats = [
    OwlItem('none', 'No hat', 0),
    OwlItem('cap', 'Graduation cap', 25),
    OwlItem('bow', 'Bow', 60),
    OwlItem('crown', 'Crown', 120),
    OwlItem('headphones', 'Headphones', 200),
  ];

  /// The next thing to unlock, to show what stars are for.
  static OwlItem? nextUnlock(int stars) {
    final locked =
        [...colours, ...hats].where((i) => !i.unlockedAt(stars)).toList()
          ..sort((a, b) => a.stars.compareTo(b.stars));
    return locked.firstOrNull;
  }
}
