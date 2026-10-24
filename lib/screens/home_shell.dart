import 'package:flutter/material.dart';

import 'badges_screen.dart';
import 'me_screen.dart';
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
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: IndexedStack(
        index: _tab,
        children: [
          TodayScreen(onOpenSubjects: () => setState(() => _tab = 1)),
          const SubjectsScreen(),
          const BadgesScreen(),
          const MeScreen(),
        ],
      ),
    ),
    // Progress lives on the Me tab now.
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.today_rounded), label: 'Today'),
        NavigationDestination(
          icon: Icon(Icons.menu_book_rounded),
          label: 'Subjects',
        ),
        NavigationDestination(
          icon: Icon(Icons.military_tech_rounded),
          label: 'Badges',
        ),
        NavigationDestination(icon: Icon(Icons.face_rounded), label: 'Me'),
      ],
    ),
  );
}
