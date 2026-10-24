import 'package:flutter/material.dart';

import '../account/adult_widgets.dart';
import '../settings_screen.dart';
import 'class_screen.dart';

class TeacherShell extends StatefulWidget {
  const TeacherShell({super.key});

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => Adult(
    child: Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: const [ClassScreen(), SettingsScreen()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: 'Classes',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    ),
  );
}

/// "Due today", "Due tomorrow", "Due Wed", "Closed 20 Oct".
String dueLabel(DateTime now, DateTime due) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(due.year, due.month, due.day);
  final diff = day.difference(today).inDays;
  if (diff < 0) return 'Closed ${due.day} ${months[due.month - 1]}';
  if (diff == 0) return 'Due today';
  if (diff == 1) return 'Due tomorrow';
  if (diff < 7) return 'Due ${weekdays[due.weekday - 1]}';
  return 'Due ${due.day} ${months[due.month - 1]}';
}
