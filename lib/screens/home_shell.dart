import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'badges_screen.dart';
import 'subjects_screen.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final junior = Tier.of(context).isJunior;
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            TodayScreen(onOpenSubjects: () => setState(() => _tab = 1)),
            const SubjectsScreen(),
            const BadgesScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          if (i == 3) {
            AppScope.read(context).signOut();
          } else {
            setState(() => _tab = i);
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.today_rounded),
            label: 'Today',
          ),
          const NavigationDestination(
            icon: Icon(Icons.menu_book_rounded),
            label: 'Subjects',
          ),
          const NavigationDestination(
            icon: Icon(Icons.military_tech_rounded),
            label: 'Badges',
          ),
          // Junior switches student from the face on the Today screen.
          if (!junior)
            const NavigationDestination(
              icon: Icon(Icons.swap_horiz_rounded),
              label: 'Switch',
            ),
        ],
      ),
    );
  }
}
