import 'package:flutter/material.dart';

import '../data/note.dart';
import '../state/note_editor_store.dart';
import 'note_cards.dart' show reminderTime;

/// A ready-made reminder time offered in the dialog and the Snooze menu.
class ReminderPreset {
  const ReminderPreset(this.label, this.at);
  final String label;
  final DateTime at;
}

/// Quick choices relative to [now] (local time): shorter ones first.
List<ReminderPreset> reminderPresets(DateTime now) {
  DateTime at(DateTime day, int hour) =>
      DateTime(day.year, day.month, day.day, hour);
  final tomorrow = now.add(const Duration(days: 1));
  final daysToMonday = (DateTime.monday - now.weekday + 7) % 7;
  final monday = now.add(Duration(days: daysToMonday == 0 ? 7 : daysToMonday));
  return [
    ReminderPreset('In 10 minutes', now.add(const Duration(minutes: 10))),
    ReminderPreset('In 1 hour', now.add(const Duration(hours: 1))),
    if (at(now, 18).isAfter(now.add(const Duration(minutes: 30))))
      ReminderPreset('This evening (6 PM)', at(now, 18)),
    ReminderPreset('Tomorrow morning (9 AM)', at(tomorrow, 9)),
    ReminderPreset('Next Monday (9 AM)', at(monday, 9)),
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
    try {
      await store.setReminder(note.id, at);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            at == null
                ? 'Reminder cleared.'
                : 'Reminder set for ${reminderTime(at)}.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not set the reminder: $error')),
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
        const SnackBar(content: Text('Choose a time in the future.')),
      );
      return;
    }
    await _apply(context, at);
  }

  @override
  Widget build(BuildContext context) {
    final current = note.remindAt;
    return AlertDialog(
      title: const Text('Reminder'),
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
                        ? 'Shown ${reminderTime(current)}'
                        : 'Set for ${reminderTime(current)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              for (final preset in reminderPresets(DateTime.now()))
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
                title: const Text('Pick date and time…'),
                onTap: () => _pick(context),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Reminders are best effort. BetterNotes must be running, or '
                  'the scheduled-task option in Settings turned on; a reminder '
                  'missed while the PC was off is shown the next time the app '
                  'starts.',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (current != null)
          TextButton(
            onPressed: () => _apply(context, null),
            child: const Text('Clear reminder'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
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
          SnackBar(content: Text('Could not update the reminder: $error')),
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
                'Reminder',
                style: TextStyle(
                  color: scheme.onTertiaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              PopupMenuButton<DateTime>(
                key: const ValueKey('snooze'),
                tooltip: 'Snooze',
                onSelected: (at) => _set(context, at),
                itemBuilder: (_) => [
                  for (final preset in reminderPresets(DateTime.now()))
                    PopupMenuItem(value: preset.at, child: Text(preset.label)),
                ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('Snooze'),
                ),
              ),
              TextButton(
                key: const ValueKey('reminder-done'),
                onPressed: () => _set(context, null),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
