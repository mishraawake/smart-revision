/// Leitner-style spaced repetition.
///
/// "Knew it" moves a card up one box and pushes it further out; "Didn't know"
/// sends it back to box 0 and brings it back in [againDelay].
class CardState {
  const CardState({required this.box, required this.due});

  factory CardState.fromJson(Map<String, dynamic> j) =>
      CardState(box: j['box'] as int, due: DateTime.parse(j['due'] as String));

  /// 0 = not known yet. A card in box 1 or higher counts as learnt.
  final int box;
  final DateTime due;

  bool get learnt => box >= 1;

  Map<String, dynamic> toJson() => {'box': box, 'due': due.toIso8601String()};
}

abstract final class Scheduler {
  static const againDelay = Duration(minutes: 10);

  /// Interval after reaching box n (index n - 1).
  static const intervals = [
    Duration(days: 1),
    Duration(days: 4),
    Duration(days: 10),
    Duration(days: 21),
    Duration(days: 45),
  ];

  static CardState grade(
    CardState? current, {
    required bool knew,
    required DateTime now,
  }) {
    if (!knew) return CardState(box: 0, due: now.add(againDelay));
    final box = ((current?.box ?? 0) + 1).clamp(1, intervals.length);
    return CardState(box: box, due: now.add(intervals[box - 1]));
  }

  /// What "Knew it" would schedule, for the senior button caption.
  static Duration nextInterval(CardState? current) {
    final box = ((current?.box ?? 0) + 1).clamp(1, intervals.length);
    return intervals[box - 1];
  }
}

String describeInterval(Duration d) {
  if (d.inDays >= 1) return d.inDays == 1 ? 'tomorrow' : 'in ${d.inDays} days';
  return 'in ${d.inMinutes} min';
}
