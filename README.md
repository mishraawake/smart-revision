# RevUp

Flashcard revision for CBSE students, Classes 1–10, built on NCERT chapters.
Works offline; progress stays on the phone.

- **Junior mode (Classes 1–5):** big buttons, read-aloud on every text block, an owl mascot.
- **Senior mode (Classes 6–10):** denser layout, scheduling hints, weekly streak view.
- **Spaced repetition:** "Knew it" brings a card back in 1, 4, 10, 21, then 45 days; "Didn't know" brings it back in 10 minutes.
- **Motivation:** daily goal ring, streaks, stars and badges.

Sample decks are included for Class 2 and Class 8 (`assets/decks/`).

## Run

```sh
flutter pub get
flutter run          # phone with USB debugging, or an emulator
flutter test
```

## Project layout

| Path | What's there |
|---|---|
| `lib/screens/` | Profile picker, Today, Subjects, Chapters, Review, Session complete, Badges |
| `lib/state/app_state.dart` | Profiles, queues, answering, streaks and stars |
| `lib/logic/` | Scheduler (spaced repetition) and badge rules |
| `lib/theme/` | Design tokens and the Junior/Senior tiers |
| `assets/decks/` | NCERT decks as JSON, one file per class |
| `assets/icon/` | Launcher icon sources (regenerate with `dart run flutter_launcher_icons`) |
