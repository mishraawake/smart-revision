import '../models/deck.dart';
import '../models/profile.dart';

class BadgeDef {
  const BadgeDef(this.id, this.title, this.description, this.earned);

  final String id;
  final String title;
  final String description;
  final bool Function(Profile p, ClassDeck? deck) earned;

  static int _learnt(Profile p) => p.cards.values.where((c) => c.learnt).length;

  static bool _anyChapterLearnt(Profile p, ClassDeck? deck) =>
      deck != null &&
      deck.subjects
          .expand((s) => s.chapters)
          .any((ch) => ch.cards.every((c) => p.cards[c.id]?.learnt ?? false));

  static final all = <BadgeDef>[
    BadgeDef(
      'first',
      'First Steps',
      'Finished your first review',
      (p, _) => p.studyDays.isNotEmpty,
    ),
    BadgeDef(
      'learnt10',
      'Ten Learnt',
      '10 cards learnt',
      (p, _) => _learnt(p) >= 10,
    ),
    BadgeDef('streak3', 'On a Roll', '3-day streak', (p, _) => p.streak >= 3),
    BadgeDef(
      'chapter',
      'Chapter Champ',
      'Every card in a chapter learnt',
      _anyChapterLearnt,
    ),
    BadgeDef(
      'learnt25',
      'Card Collector',
      '25 cards learnt',
      (p, _) => _learnt(p) >= 25,
    ),
    BadgeDef('streak7', 'Week Star', '7-day streak', (p, _) => p.streak >= 7),
  ];

  static BadgeDef byId(String id) => all.firstWhere((b) => b.id == id);
}
