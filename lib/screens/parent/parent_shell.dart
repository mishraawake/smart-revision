import 'package:flutter/material.dart';

import '../account/adult_widgets.dart';
import '../settings_screen.dart';
import 'parent_dashboard.dart';

class ParentShell extends StatefulWidget {
  const ParentShell({super.key});

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => Adult(
    child: Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            ParentDashboard(onSettings: () => setState(() => _tab = 1)),
            const SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Progress',
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
