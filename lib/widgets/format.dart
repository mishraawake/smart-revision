import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'common.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Today", "Yesterday" or "Tue 20 Oct".
String shortDate(DateTime now, DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return dateLabel(d);
}

/// "Tue 20 Oct".
String dateLabel(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';

/// "6:42".
String clock(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// The current student's face; tapping it goes back to "Who's studying?".
class SwitchStudentButton extends StatelessWidget {
  const SwitchStudentButton({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.current!;
    return Semantics(
      button: true,
      label: 'Switch student, now ${p.name}',
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        // A phone with one student is theirs; nobody to switch to.
        onTap: state.profiles.length > 1 ? state.signOut : null,
        child: Avatar(name: p.name, index: p.avatar, size: size),
      ),
    );
  }
}
