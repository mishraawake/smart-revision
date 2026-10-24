import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Gives grown-up screens the calmer theme whatever the last student was.
class Adult extends StatelessWidget {
  const Adult({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: buildAdultTheme(), child: child);
}

/// Pushes [screen] with the adult theme.
Future<T?> pushAdult<T>(BuildContext context, Widget screen) =>
    Navigator.of(context)
        .push<T>(MaterialPageRoute(builder: (_) => Adult(child: screen)));

const labelStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  color: AppColors.inkMuted,
);

const mutedStyle = TextStyle(
  fontSize: 14,
  height: 1.45,
  color: AppColors.inkMuted,
);

/// White card with a 1px line, radius 16.
class AdultCard extends StatelessWidget {
  const AdultCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.selected = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: selected
          ? const BorderSide(color: AppColors.primary, width: 2)
          : const BorderSide(color: AdultColors.line),
    );
    return Material(
      color: Colors.white,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: selected ? padding - const EdgeInsets.all(1) : padding,
          child: child,
        ),
      ),
    );
  }
}

/// Back arrow on the left, something small on the right.
class BackRow extends StatelessWidget {
  const BackRow({super.key, this.trailing, this.icon = Icons.chevron_left});
  final Widget? trailing;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Transform.translate(
        offset: const Offset(-12, 0),
        child: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: icon == Icons.close ? 'Close' : 'Back',
          iconSize: 28,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: Icon(icon),
        ),
      ),
      const Spacer(),
      ?trailing,
    ],
  );
}

class RolePill extends StatelessWidget {
  const RolePill(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.primaryTint,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.onPrimaryTint,
      ),
    ),
  );
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.subtitle});
  final String title;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        DefaultTextStyle.merge(
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppColors.inkMuted,
          ),
          child: subtitle!,
        ),
      ],
    ],
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      if (trailing != null)
        DefaultTextStyle.merge(style: labelStyle, child: trailing!),
    ],
  );
}

/// "+91 | 98765 43210".
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: labelStyle),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumberNational],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
        decoration: InputDecoration(
          hintText: '10-digit number',
          prefixIcon: Container(
            width: 64,
            margin: const EdgeInsets.only(right: 12),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: AdultColors.line)),
            ),
            child: const Text(
              '+91',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    ],
  );
}

/// Name field with its label above.
class LabelledField extends StatelessWidget {
  const LabelledField({
    super.key,
    required this.label,
    required this.controller,
    this.onChanged,
    this.autofillHints,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: labelStyle),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        onChanged: onChanged,
        autofillHints: autofillHints,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

/// A grid of class numbers; one can be picked.
class ClassPicker extends StatelessWidget {
  const ClassPicker({
    super.key,
    required this.classes,
    required this.selected,
    required this.onSelect,
    this.columns = 5,
    this.labelOf,
    this.semanticPrefix = 'Class',
  });

  final List<int> classes;
  final int? selected;
  final ValueChanged<int> onSelect;
  final int columns;

  /// Shows something other than the number, such as a section letter.
  final String Function(int)? labelOf;
  final String semanticPrefix;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 8.0;
      final w = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final c in classes)
            SizedBox(
              width: w,
              child: ChoiceButton(
                label: labelOf?.call(c) ?? '$c',
                selected: c == selected,
                semanticLabel: '$semanticPrefix ${labelOf?.call(c) ?? c}',
                onTap: () => onSelect(c),
              ),
            ),
        ],
      );
    },
  );
}

/// A 48dp toggle: filled indigo when picked, outlined otherwise.
class ChoiceButton extends StatelessWidget {
  const ChoiceButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.sub,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final String? sub;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: semanticLabel,
    excludeSemantics: semanticLabel != null,
    child: Material(
      color: selected ? AppColors.primary : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide.none
            : const BorderSide(color: AdultColors.field, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(minHeight: sub == null ? 48 : 60),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          alignment: Alignment.center,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: selected ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 18,
                        color: selected ? Colors.white : AppColors.ink,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                if (sub != null)
                  Text(
                    sub!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? const Color(0xFFE0E7FF)
                          : AppColors.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The student's coloured initial in six colours.
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.name,
    required this.selected,
    required this.onSelect,
  });

  final String name;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 14,
    runSpacing: 14,
    children: [
      for (var i = 0; i < avatarColors.length; i++)
        Semantics(
          button: true,
          selected: i == selected,
          label: 'Avatar colour ${i + 1}',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: i == selected ? AppColors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Avatar(name: name, index: i, size: 48),
            ),
          ),
        ),
    ],
  );
}

enum ChipTone { mastered, needsWork, pending }

/// Status always carries a word, not just a colour.
class StatusChip extends StatelessWidget {
  const StatusChip(this.text, this.tone, {super.key});
  final String text;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      ChipTone.mastered => (AdultColors.mastered, AdultColors.masteredInk),
      ChipTone.needsWork => (AdultColors.needsWork, AdultColors.needsWorkInk),
      ChipTone.pending => (AdultColors.chip, AdultColors.chipInk),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      foregroundColor: AppColors.ink,
      side: const BorderSide(color: AdultColors.field, width: 1.5),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
        fontFamily: Fonts.body,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    ),
  );
}

class LinkButton extends StatelessWidget {
  const LinkButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: AppColors.primary,
      textStyle: const TextStyle(
        fontFamily: Fonts.body,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    ),
    child: Text(label),
  );
}

/// Grey box with an icon: tips and small print.
class InfoNote extends StatelessWidget {
  const InfoNote(
    this.text, {
    super.key,
    this.icon = Icons.info_outline,
    this.white = false,
  });

  final String text;
  final IconData icon;
  final bool white;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: white ? Colors.white : AdultColors.chip,
      borderRadius: BorderRadius.circular(14),
      border: white ? Border.all(color: AdultColors.line) : null,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AdultColors.chipInk),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AdultColors.chipInk,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The design's segmented control.
class Segments extends StatelessWidget {
  const Segments({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AdultColors.chip,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              selected: i == index,
              button: true,
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: i == index
                        ? const [
                            BoxShadow(
                              color: Color(0x1F1F1A33),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: i == index
                          ? FontWeight.w800
                          : FontWeight.w700,
                      color: i == index ? AppColors.ink : AppColors.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// A form with its one action pinned to the bottom.
class FormPage extends StatelessWidget {
  const FormPage({
    super.key,
    required this.fields,
    required this.bottom,
    this.top = 16,
  });

  final List<Widget> fields;
  final List<Widget> bottom;
  final double top;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, top, 20, 16),
              children: fields,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: bottom,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Wordmark tile used on the role picker.
class AppMark extends StatelessWidget {
  const AppMark({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.style_outlined, color: Colors.white, size: 22),
      ),
      const SizedBox(width: 10),
      const Text(
        'RevUp',
        style: TextStyle(
          fontFamily: Fonts.display,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}
