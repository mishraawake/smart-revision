import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../theme/tokens.dart';
import 'adult_widgets.dart';
import 'phone_screen.dart';
import 'student_signup_screen.dart';

/// "Who's using the app?" First screen on a new phone.
class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context) => Adult(
    child: Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
          children: [
            const AppMark(),
            const SizedBox(height: 28),
            const ScreenTitle(
              "Who's using the app?",
              subtitle: Text(
                'NCERT flashcards and quizzes for Classes 1–10. Free to use.',
              ),
            ),
            const SizedBox(height: 28),
            _RoleCard(
              icon: Icons.school_outlined,
              title: "I'm a student",
              body: 'Classes 6–10 can sign up here. A parent approves.',
              onTap: () => pushAdult(context, const StudentSignupScreen()),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              icon: Icons.family_restroom_outlined,
              title: "I'm a parent",
              body: 'Set up profiles for your children and see their progress.',
              highlight: true,
              onTap: () =>
                  pushAdult(context, const PhoneScreen(role: Role.parent)),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              icon: Icons.co_present_outlined,
              title: "I'm a teacher",
              body: 'Create a class, share a join code, set assignments.',
              onTap: () =>
                  pushAdult(context, const PhoneScreen(role: Role.teacher)),
            ),
            const SizedBox(height: 28),
            const InfoNote(
              'In Classes 1–5? Ask a parent to choose "I\'m a parent" and '
              'add you.',
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already signed up?',
                  style: TextStyle(fontSize: 15, color: AppColors.inkMuted),
                ),
                LinkButton(
                  label: 'Log in',
                  onPressed: () => pushAdult(
                    context,
                    const PhoneScreen(role: Role.parent, login: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) => AdultCard(
    selected: highlight,
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.onPrimaryTint, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: mutedStyle),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: highlight ? AppColors.primary : AppColors.inkMuted,
          ),
        ],
      ),
    ),
  );
}
