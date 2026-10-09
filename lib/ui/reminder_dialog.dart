import 'package:flutter/material.dart';

import '../data/note.dart';
import '../l10n/l10n.dart';
import '../state/note_editor_store.dart';
import 'note_cards.dart' show reminderTime;

/// A ready-made reminder time offered in the dialog and the Snooze menu.
class ReminderPreset {
  const ReminderPreset(this.label, this.at);
  final String label;
  final DateTime at;
}

/// Quick choices relative to [now] (local time): shorter ones first.
List<ReminderPreset> reminderPresets(DateTime now, [AppLocalizations? l10n]) {
  final l = l10n ?? currentL10n();
  DateTime at(DateTime day, int hour) =>
      DateTime(day.year, day.month, day.day, hour);
  final tomorrow = now.add(const Duration(days: 1));
  final daysToMonday = (DateTime.monday - now.weekday + 7) % 7;
  final monday = now.add(Duration(days: daysToMonday == 0 ? 7 : daysToMonday));
  return [
    ReminderPreset(
      l.reminderPresetTenMinutes,
      now.add(const Duration(minutes: 10)),
    ),
    ReminderPreset(l.reminderPresetOneHour, now.add(const Duration(hours: 1))),
    if (at(now, 18).isAfter(now.add(const Duration(minutes: 30))))
      ReminderPreset(l.reminderPresetEvening, at(now, 18)),
    ReminderPreset(l.reminderPresetTomorrow, at(tomorrow, 9)),
    ReminderPreset(l.reminderPresetMonday, at(monday, 9)),
  ];
}

/// Sets or clears a note's reminder.
Future<void> showReminderDialog(
  BuildContext context,
  NoteEditorStore store,
  Note note,
) => showDialog<void>(
  context: context,
  builder: (context) => _ReminderDialog(store: store, note: note),
);

class _ReminderDialog extends StatelessWidget {
  const _ReminderDialog({required this.store, required this.note});
  final NoteEditorStore store;
  final Note note;

  Future<void> _apply(BuildContext context, DateTime? at) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await store.setReminder(note.id, at);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            at == null
                ? l10n.reminderCleared
                : l10n.reminderSetSnack(reminderTime(at)),
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.reminderCouldNotSetTheReminder('$error'))),
      );
    }
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: note.remindAt?.toLocal().isAfter(now) == true
          ? note.remindAt!.toLocal()
          : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (now.hour + 1) % 24, minute: 0),
    );
    if (time == null || !context.mounted) return;
    final at = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!at.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.reminderChooseFuture)),
      );
      return;
    }
    await _apply(context, at);
  }

  @override
  Widget build(BuildContext context) {
    final current = note.remindAt;
    return AlertDialog(
      title: Text(context.l10n.reminderTitle),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (current != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    note.reminderFired
                        ? context.l10n.reminderShownAt(reminderTime(current))
                        : context.l10n.reminderSetFor(reminderTime(current)),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              for (final preset in reminderPresets(
                DateTime.now(),
                context.l10n,
              ))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.alarm_add_outlined),
                  title: Text(preset.label),
                  subtitle: Text(reminderTime(preset.at)),
                  onTap: () => _apply(context, preset.at),
                ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.edit_calendar_outlined),
                title: Text(context.l10n.reminderPickDateTime),
                onTap: () => _pick(context),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(context.l10n.reminderBestEffort),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (current != null)
          TextButton(
            onPressed: () => _apply(context, null),
            child: Text(context.l10n.reminderClear),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.reminderClose),
        ),
      ],
    );
  }
}

/// Snooze / Done controls shown in a note whose reminder has fired.
class ReminderBanner extends StatelessWidget {
  const ReminderBanner({super.key, required this.store, required this.note});
  final NoteEditorStore store;
  final Note note;

  Future<void> _set(BuildContext context, DateTime? at) async {
    try {
      await store.setReminder(note.id, at);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.reminderCouldNotUpdateTheReminder('$error'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Icon(Icons.alarm_on_outlined, color: scheme.onTertiaryContainer),
              Text(
                context.l10n.reminderTitle,
                style: TextStyle(
                  color: scheme.onTertiaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              PopupMenuButton<DateTime>(
                key: const ValueKey('snooze'),
                tooltip: context.l10n.reminderSnooze,
                onSelected: (at) => _set(context, at),
                itemBuilder: (_) => [
                  for (final preset in reminderPresets(
                    DateTime.now(),
                    context.l10n,
                  ))
                    PopupMenuItem(value: preset.at, child: Text(preset.label)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(context.l10n.reminderSnooze),
                ),
              ),
              TextButton(
                key: const ValueKey('reminder-done'),
                onPressed: () => _set(context, null),
                child: Text(context.l10n.reminderDone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
