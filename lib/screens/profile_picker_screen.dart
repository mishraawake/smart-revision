import 'package:flutter/material.dart';

import '../models/account.dart';
import '../models/profile.dart';
import '../state/account_state.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// "Who's studying?" Junior shows big faces; Senior shows a list with when
/// each student last studied.
class ProfilePickerScreen extends StatelessWidget {
  const ProfilePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final junior = Tier.of(context).isJunior;
    final accounts = AccountScope.maybeOf(context);
    return Scaffold(
      body: SafeArea(
        child: junior
            ? _JuniorPicker(state: state)
            : _SeniorPicker(state: state),
      ),
      // Only parents get the grown-up view; a student's own phone doesn't.
      bottomNavigationBar: accounts?.account?.role == Role.parent
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  heightFactor: 1,
                  child: TextButton.icon(
                    onPressed: () => accounts!.setAdultMode(true),
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text(
                      'For parents',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _JuniorPicker extends StatelessWidget {
  const _JuniorPicker({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
    children: [
      const Center(child: Owl(size: 96)),
      const SizedBox(height: 12),
      Row(
        children: [
          const Expanded(
            child: Text(
              "Who's studying?",
              style: TextStyle(
                fontFamily: Fonts.display,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          const ReadAloudButton("Who's studying? Tap your face."),
        ],
      ),
      const Text(
        'Tap your face',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.inkMuted,
        ),
      ),
      const SizedBox(height: 20),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.85,
        children: [
          for (final p in state.profiles)
            _FaceTile(profile: p, onTap: () => state.select(p)),
          _AddTile(onTap: () => showAddStudentDialog(context)),
        ],
      ),
      const SizedBox(height: 20),
      const Text(
        'Hold a face to hear its name',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, color: AppColors.inkMuted),
      ),
    ],
  );
}

class _FaceTile extends StatelessWidget {
  const _FaceTile({required this.profile, required this.onTap});
  final Profile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SoftCard(
    onTap: onTap,
    child: GestureDetector(
      onLongPress: () => SpeakerScope.of(context).say(profile.name),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Avatar(name: profile.name, index: profile.avatar, size: 72),
          const SizedBox(height: 8),
          Text(
            profile.name,
            style: const TextStyle(
              fontFamily: Fonts.display,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Class ${profile.classLevel}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SoftCard(
    onTap: onTap,
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.chip,
          child: Icon(Icons.add_rounded, size: 40, color: AppColors.inkMuted),
        ),
        SizedBox(height: 8),
        Text(
          'Add child',
          style: TextStyle(
            fontFamily: Fonts.display,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _SeniorPicker extends StatelessWidget {
  const _SeniorPicker({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final recent = [...state.profiles.where((p) => p.lastStudiedAt != null)]
      ..sort((a, b) => b.lastStudiedAt!.compareTo(a.lastStudiedAt!));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        const Text(
          'RevUp',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Who's studying?",
          style: TextStyle(
            fontFamily: Fonts.display,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final p in state.profiles)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => state.select(p),
                child: SizedBox(
                  width: 84,
                  child: Column(
                    children: [
                      Avatar(name: p.name, index: p.avatar, size: 64),
                      const SizedBox(height: 6),
                      Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Class ${p.classLevel}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Last studied',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          for (final p in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                padding: 12,
                onTap: () => state.select(p),
                child: Row(
                  children: [
                    Avatar(name: p.name, index: p.avatar, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${p.name} · ${_subjectName(p.lastSubjectId)}, ${timeAgo(state.now(), p.lastStudiedAt!)}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    if (state.streakOf(p) > 0) ...[
                      const FlameIcon(size: 18),
                      Text(
                        '${state.streakOf(p)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => showAddStudentDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add a student'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AccountScope.maybeOf(context)?.service.isDemo == false
              ? "No passwords · saved to the parent's account"
              : 'No passwords · profiles stay on this phone',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
        ),
      ],
    );
  }

  static String _subjectName(String? id) => switch (id) {
    'maths' => 'Maths',
    'english' => 'English',
    'science' => 'Science',
    'social' => 'Social Sci',
    'evs' => 'EVS',
    _ => 'Revision',
  };
}

String timeAgo(DateTime now, DateTime then) {
  final d = now.difference(then);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24 && now.day == then.day) return '${d.inHours} h ago';
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(then.year, then.month, then.day)).inDays;
  return days <= 1 ? 'yesterday' : '$days days ago';
}

/// Asks a grown-up for a name and class.
Future<void> showAddStudentDialog(BuildContext context) async {
  final state = AppScope.read(context);
  final name = TextEditingController();
  var classLevel = 2;
  final added = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add a student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: classLevel,
              decoration: const InputDecoration(labelText: 'Class'),
              items: [
                for (var c = 1; c <= 10; c++)
                  DropdownMenuItem(value: c, child: Text('Class $c')),
              ],
              onChanged: (v) => setState(() => classLevel = v ?? classLevel),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
  if (added ?? false) await state.addProfile(name.text, classLevel);
}
