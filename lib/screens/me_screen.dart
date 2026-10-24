import 'package:flutter/material.dart';

import '../logic/levels.dart';
import '../logic/owl_wardrobe.dart';
import '../models/account.dart';
import '../models/profile.dart';
import '../state/account_state.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'account/adult_widgets.dart' show AvatarPicker, pushAdult;
import 'account/role_screen.dart';
import 'add_exam_sheet.dart';
import 'join_class_dialog.dart';
import 'my_chapters_screen.dart';
import 'onboarding_screen.dart';
import 'progress_screen.dart';

/// The student's own space: who they are, their Ollie, their goal, what's
/// been done at school, their tests.
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.current!;
    final junior = Tier.of(context).isJunior;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        _Header(profile: p),
        const SizedBox(height: 16),
        _OwlCard(profile: p),
        const SizedBox(height: 16),
        _Heading('My daily goal', junior: junior),
        _GoalPicker(profile: p),
        const SizedBox(height: 16),
        _Heading('School', junior: junior),
        SoftCard(
          padding: 4,
          child: Column(
            children: [
              _LinkTile(
                icon: Icons.checklist_rounded,
                title: 'Done at school',
                sub: p.covered.isEmpty
                    ? 'Tick the chapters your class has finished'
                    : '${p.covered.length} chapters ticked',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MyChaptersScreen(),
                  ),
                ),
              ),
              _LinkTile(
                icon: Icons.insights_rounded,
                title: 'My progress',
                sub: 'Chapters, quizzes and study days',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('My progress')),
                      body: const ProgressScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Heading('My tests', junior: junior),
        _Tests(profile: p),
        const SizedBox(height: 24),
        const _GrownUps(),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {required this.junior});
  final String text;
  final bool junior;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: Fonts.display,
        fontSize: junior ? 22 : 18,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 60,
    leading: Icon(icon, color: AppColors.primary),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text(sub),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

// ---- Who I am ----------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final junior = Tier.of(context).isJunior;
    return Row(
      children: [
        Avatar(name: p.name, index: p.avatar, size: junior ? 72 : 60),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                style: TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: junior ? 30 : 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Class ${p.classLevel} · ${Level.of(p.xp).name}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Edit me',
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            backgroundColor: AppColors.ground,
            builder: (_) => _EditSheet(profile: p),
          ),
          icon: const Icon(Icons.edit_rounded),
        ),
      ],
    );
  }
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.profile});
  final Profile profile;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _name = TextEditingController(text: widget.profile.name);
  late var _class = widget.profile.classLevel;
  late var _avatar = widget.profile.avatar;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nav = Navigator.of(context);
    final app = AppScope.read(context);
    if (_class != widget.profile.classLevel) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Move to Class $_class?'),
          content: const Text(
            'You get that class\'s chapters. Your ticks for "done at school" '
            'and your tests are cleared. Stars, streak and badges stay.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Move'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await app.editProfile(
      name: _name.text.trim().isEmpty ? widget.profile.name : _name.text,
      classLevel: _class,
      avatar: _avatar,
    );
    nav.pop();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          const Text(
            'About me',
            style: TextStyle(
              fontFamily: Fonts.display,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            maxLength: 20,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          AvatarPicker(
            name: _name.text.trim().isEmpty ? '?' : _name.text.trim(),
            selected: _avatar,
            onSelect: (i) => setState(() => _avatar = i),
          ),
          const SizedBox(height: 16),
          const Text('Class', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var c = 1; c <= 10; c++)
                ChoiceChip(
                  label: Text('$c'),
                  selected: c == _class,
                  onSelected: (_) => setState(() => _class = c),
                ),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Save', onPressed: _save),
        ],
      ),
    ),
  );
}

// ---- Ollie ------------------------------------------------------------------

class _OwlCard extends StatelessWidget {
  const _OwlCard({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = profile;
    final next = Wardrobe.nextUnlock(p.stars);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MyOwl(size: 96),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ollie',
                      style: TextStyle(
                        fontFamily: Fonts.display,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StatPill.stars(p.stars),
                    const SizedBox(height: 6),
                    Text(
                      next == null
                          ? 'Everything unlocked. Wow!'
                          : '${next.stars - p.stars} more stars unlock '
                                '${next.name}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Colour', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in Wardrobe.colours)
                _WardrobeItem(
                  item: c,
                  stars: p.stars,
                  selected: p.owlColor == c.id,
                  onTap: () => state.dressOwl(colour: c.id),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: owlColours[c.id],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Hat', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final h in Wardrobe.hats)
                _WardrobeItem(
                  item: h,
                  stars: p.stars,
                  selected: p.owlHat == h.id,
                  onTap: () => state.dressOwl(hat: h.id),
                  child: Owl(size: 40, colour: p.owlColor, hat: h.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WardrobeItem extends StatelessWidget {
  const _WardrobeItem({
    required this.item,
    required this.stars,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final OwlItem item;
  final int stars;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final open = item.unlockedAt(stars);
    return Semantics(
      button: true,
      selected: selected,
      label: open ? item.name : '${item.name}, locked, ${item.stars} stars',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: open
            ? onTap
            : () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${item.name} unlocks at ${item.stars} stars. '
                    'You have $stars.',
                  ),
                ),
              ),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.groundBorder,
              width: selected ? 3 : 1.5,
            ),
          ),
          child: open
              ? child
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      size: 18,
                      color: AppColors.inkMuted,
                    ),
                    Text(
                      '${item.stars}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ---- Goal and tests ----------------------------------------------------------

class _GoalPicker extends StatelessWidget {
  const _GoalPicker({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = profile;
    const names = ['Light', 'Normal', 'Keen'];
    final choices = p.goalChoices;
    return Row(
      children: [
        for (var i = 0; i < choices.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _GoalChoice(
              name: names[i],
              cards: choices[i],
              selected: p.dailyGoal == choices[i],
              onTap: () => state.setGoal(choices[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _GoalChoice extends StatelessWidget {
  const _GoalChoice({
    required this.name,
    required this.cards,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final int cards;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
              Text(
                '$cards cards · ~${(cards / 2).ceil()} min',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primaryTint : AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Tests extends StatelessWidget {
  const _Tests({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final tests = state.upcomingExams;
    return SoftCard(
      padding: 4,
      child: Column(
        children: [
          for (final e in tests)
            ListTile(
              minTileHeight: 60,
              leading: const Icon(
                Icons.event_note_rounded,
                color: AppColors.streak,
              ),
              title: Text(
                '${state.subjectById(e.subjectId)?.name ?? 'Test'} · '
                '${dateLabel(e.date)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${e.chapterIds.length} chapters · '
                '${(state.examReadiness(e) * 100).round()}% ready',
              ),
              trailing: IconButton(
                tooltip: 'Remove test',
                onPressed: () => state.removeExam(e),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.add_rounded, color: AppColors.primary),
            title: const Text(
              'Add a test',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            onTap: () => showAddExamSheet(context),
          ),
        ],
      ),
    );
  }
}

// ---- Others on this phone ----------------------------------------------------

class _GrownUps extends StatelessWidget {
  const _GrownUps();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final accounts = AccountScope.maybeOf(context);
    final role = accounts?.account?.role;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.profiles.length > 1)
          TextButton.icon(
            onPressed: state.signOut,
            icon: const Icon(Icons.switch_account_rounded),
            label: const Text('Switch student'),
          ),
        if (role != Role.student)
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const OnboardingScreen(addAnother: true),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_rounded),
            label: const Text('Add another student on this phone'),
          ),
        if (role == Role.student)
          TextButton.icon(
            onPressed: () => showJoinClassDialog(context, state.current!),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Join a class'),
          ),
        if (role == Role.parent)
          TextButton.icon(
            onPressed: () => accounts!.setAdultMode(true),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Parent area'),
          )
        else if (role == null && accounts != null)
          TextButton.icon(
            onPressed: () => pushAdult(context, const RoleScreen()),
            icon: const Icon(Icons.login_rounded),
            label: const Text('Parent or teacher? Sign in'),
          ),
      ],
    );
  }
}
