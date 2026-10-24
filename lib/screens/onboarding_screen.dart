import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'account/adult_widgets.dart' show AvatarPicker, pushAdult;
import 'account/role_screen.dart';

/// First launch: the student says their class (and, if they like, their
/// name) and goes straight to studying. No account, no password. Parents
/// and teachers sign in from the link at the bottom.
///
/// [addAnother] reuses it from the Me tab to put a second student on the
/// phone; it skips the welcome.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.addAnother = false});

  final bool addAnother;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late var _step = widget.addAnother ? 1 : 0;
  int? _class;
  final _name = TextEditingController();
  var _avatar = 0;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _saving = true);
    final app = AppScope.read(context);
    final nav = Navigator.of(context);
    final name = _name.text.trim();
    final p = await app.addProfile(
      name.isEmpty ? 'Friend' : name,
      _class!,
      avatar: _avatar,
    );
    await app.select(p);
    if (widget.addAnother && mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.addAnother || _step == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) setState(() => _step--);
    },
    child: Scaffold(
      backgroundColor: AppColors.ground,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: switch (_step) {
            0 => _welcome(),
            1 => _classStep(),
            _ => _nameStep(),
          },
        ),
      ),
    ),
  );

  Widget _welcome() => Padding(
    key: const ValueKey(0),
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Center(child: Owl(size: 140, hat: 'cap')),
        const SizedBox(height: 24),
        const Text(
          'Hi! I\'m Ullu.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Fonts.display,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Let\'s revise your NCERT chapters, a few minutes a day. '
          'Flashcards, quizzes, stars and streaks.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            height: 1.45,
            color: AppColors.inkMuted,
          ),
        ),
        const Spacer(flex: 2),
        PrimaryButton(
          label: "Let's start",
          onPressed: () => setState(() => _step = 1),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => pushAdult(context, const RoleScreen()),
          child: const Text(
            'Parent or teacher? Sign in here',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  Widget _classStep() => ListView(
    key: const ValueKey(1),
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          tooltip: 'Back',
          onPressed: widget.addAnother
              ? () => Navigator.of(context).pop()
              : () => setState(() => _step = 0),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Which class are you in?',
        style: TextStyle(
          fontFamily: Fonts.display,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'You get the NCERT chapters for your class.',
        style: TextStyle(fontSize: 16, color: AppColors.inkMuted),
      ),
      const SizedBox(height: 20),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.4,
        children: [
          for (var c = 1; c <= 10; c++)
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppColors.groundBorder, width: 2),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() {
                  _class = c;
                  _step = 2;
                }),
                child: Center(
                  child: Text(
                    'Class $c',
                    style: const TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _nameStep() {
    final name = _name.text.trim();
    return ListView(
      key: const ValueKey(2),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Back',
            onPressed: () => setState(() => _step = 1),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'What should Ullu call you?',
          style: TextStyle(
            fontFamily: Fonts.display,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Class $_class · you can change this later on the Me tab.',
          style: const TextStyle(fontSize: 16, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            hintText: 'Your first name or a nickname',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const Text(
          'Pick a colour',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        AvatarPicker(
          name: name.isEmpty ? '?' : name,
          selected: _avatar,
          onSelect: (i) => setState(() => _avatar = i),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: _saving ? 'Getting ready…' : 'Start learning',
          onPressed: _saving ? null : _start,
        ),
        if (name.isEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'No name? That\'s fine. Ullu will call you Friend.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.inkMuted),
          ),
        ],
      ],
    );
  }
}
