import 'dart:io';

import 'package:better_notes/data/backup.dart';
import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/data/note.dart';
import 'package:better_notes/data/reminder_task.dart';
import 'package:better_notes/data/reminder_task_xml.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:better_notes/ui/note_page.dart';
import 'package:better_notes/ui/reminder_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<(NotesController, Database)> _open(String name) async {
  final db = await databaseFactoryMemory.openDatabase(name);
  final controller = NotesController(LocalStore.fromDatabase(db), null);
  await controller.load();
  return (controller, db);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reminders become due once, snooze re-arms, and clearing removes',
    () async {
      final (controller, db) = await _open('rem-logic');
      var changes = 0;
      controller.remindersChanged = () async => changes++;
      final a = await controller.create();
      final b = await controller.create();
      final past = DateTime.now().subtract(const Duration(minutes: 5));
      final future = DateTime.now().add(const Duration(hours: 2));
      await controller.setReminder(a.id, past);
      await controller.setReminder(b.id, future);
      expect(changes, 2);
      expect(controller.dueReminders().map((n) => n.id), [a.id]);
      expect(controller.nextReminder!.toUtc(), past.toUtc());
      // Reminders are local metadata: no cloud sync is queued by them.
      expect(
        controller.noteById(a.id)!.toRemoteJson().keys,
        isNot(contains('remind_at')),
      );

      await controller.markReminderFired(a.id);
      expect(controller.dueReminders(), isEmpty);
      expect(controller.noteById(a.id)!.reminderFired, isTrue);
      expect(controller.nextReminder!.toUtc(), future.toUtc());

      await controller.setReminder(
        a.id,
        DateTime.now().add(const Duration(minutes: 10)),
      );
      expect(controller.noteById(a.id)!.reminderFired, isFalse);
      expect(controller.dueReminders(), isEmpty);
      expect(
        controller
            .dueReminders(DateTime.now().add(const Duration(hours: 1)))
            .map((n) => n.id),
        [a.id],
      );

      await controller.setLibraryOptions(view: LibraryView.reminders);
      expect(controller.librarySearch('').map((n) => n.id), [a.id, b.id]);
      await controller.setReminder(b.id, null);
      expect(controller.noteById(b.id)!.remindAt, isNull);
      expect(controller.librarySearch('').map((n) => n.id), [a.id]);

      // Trashed or archived notes never announce reminders.
      await controller.setReminder(a.id, past);
      await controller.archive(a.id);
      expect(controller.dueReminders(), isEmpty);
      expect(controller.nextReminder, isNull);
      controller.dispose();
      await db.close();
    },
  );

  test('reminders survive restart and sync acknowledgement', () async {
    final (controller, db) = await _open('rem-persist');
    final note = await controller.create();
    final at = DateTime.now().add(const Duration(days: 1));
    await controller.setReminder(note.id, at);
    final store = LocalStore.fromDatabase(db);
    final snapshot = (await store.noteById(note.id))!;
    // A server copy has no reminder fields; acknowledging must keep ours.
    final server = Note.fromJson({...snapshot.toRemoteJson(), 'revision': 5});
    await store.acknowledgeRemote(snapshot, server);
    final after = (await store.noteById(note.id))!;
    expect(after.revision, 5);
    expect(after.remindAt!.toUtc(), at.toUtc());
    expect(after.reminderFired, isFalse);
    controller.dispose();

    final reopened = NotesController(store, null);
    await reopened.load();
    expect(reopened.noteById(note.id)!.remindAt!.toUtc(), at.toUtc());
    reopened.dispose();
    await db.close();
  });

  test('backups keep only future pending reminders on import', () async {
    final (controller, db) = await _open('rem-backup');
    final soon = await controller.create();
    final old = await controller.create();
    final shown = await controller.create();
    await controller.setReminder(
      soon.id,
      DateTime.now().add(const Duration(days: 2)),
    );
    await controller.setReminder(
      old.id,
      DateTime.now().subtract(const Duration(days: 1)),
    );
    await controller.setReminder(
      shown.id,
      DateTime.now().add(const Duration(days: 3)),
    );
    await controller.markReminderFired(shown.id);
    final backup = NoteBackup.validate(await controller.exportBackup());
    expect(backup.notes.where((n) => n.remindAt != null), hasLength(3));
    await backup.importInto(LocalStore.fromDatabase(db), guestOwner);
    await controller.reload();
    final copies = controller.notes
        .where((n) => ![soon.id, old.id, shown.id].contains(n.id))
        .toList();
    expect(copies, hasLength(3));
    expect(
      copies.where((n) => n.remindAt != null && n.reminderPending),
      hasLength(1),
    );
    expect(copies.where((n) => n.remindAt == null), hasLength(2));
    controller.dispose();
    await db.close();
  });

  test('reminder presets are in the future and ordered sensibly', () {
    for (final now in [
      DateTime(2026, 10, 9, 8, 0), // Friday morning
      DateTime(2026, 10, 9, 17, 50), // too close to 6 PM
      DateTime(2026, 10, 12, 23, 59), // Monday night
    ]) {
      final presets = reminderPresets(now);
      expect(presets.every((p) => p.at.isAfter(now)), isTrue, reason: '$now');
      final labels = presets.map((p) => p.label);
      expect(labels, contains('In 1 hour'));
      expect(labels, contains('Tomorrow morning (9 AM)'));
      final monday = presets.firstWhere(
        (p) => p.label.startsWith('Next Monday'),
      );
      expect(monday.at.weekday, DateTime.monday);
      expect(monday.at.hour, 9);
      expect(monday.at.isAfter(now), isTrue);
    }
    expect(
      reminderPresets(DateTime(2026, 10, 9, 17, 50)).map((p) => p.label),
      isNot(contains('This evening (6 PM)')),
    );
    expect(
      reminderPresets(DateTime(2026, 10, 9, 8)).map((p) => p.label),
      contains('This evening (6 PM)'),
    );
  });

  test('task XML uses an absolute UTC start, sign-in trigger, and escapes', () {
    final xml = buildReminderTaskXml(
      exe: r'C:\Apps\Better & Notes\better_notes.exe',
      userId: r'PC\o"wner',
      nextUtc: DateTime.utc(2026, 10, 12, 1, 30, 15, 999),
    );
    expect(
      xml,
      contains('<StartBoundary>2026-10-12T01:30:15Z</StartBoundary>'),
    );
    expect(xml, contains('<LogonTrigger>'));
    expect(xml, contains('<StartWhenAvailable>true</StartWhenAvailable>'));
    expect(xml, contains('<Arguments>--reminders-due</Arguments>'));
    expect(xml, contains('Better &amp; Notes'));
    expect(xml, contains('PC\\o&quot;wner'));
    expect(xml, contains('<RunLevel>LeastPrivilege</RunLevel>'));
    final overdueOnly = buildReminderTaskXml(exe: 'a.exe', userId: 'u');
    expect(overdueOnly, isNot(contains('TimeTrigger')));
    expect(overdueOnly, contains('LogonTrigger'));
  });

  testWidgets('a fired reminder shows Snooze/Done in the note', (tester) async {
    final (controller, db, note) =
        await tester.runAsync(() async {
          final (controller, db) = await _open('rem-banner');
          final note = await controller.create();
          await controller.setReminder(
            note.id,
            DateTime.now().subtract(const Duration(minutes: 1)),
          );
          await controller.markReminderFired(note.id);
          return (controller, db, note);
        }) ??
        (throw StateError('setup failed'));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: NotePage(controller: controller, noteId: note.id),
      ),
    );
    await tester.pump();
    expect(find.text('Reminder'), findsOneWidget);
    expect(find.text('Snooze'), findsOneWidget);

    await tester.tap(find.text('Snooze'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In 1 hour'));
    await tester.pumpAndSettle();
    final snoozed = controller.noteById(note.id)!;
    expect(snoozed.reminderFired, isFalse);
    expect(snoozed.remindAt!.isAfter(DateTime.now().toUtc()), isTrue);
    expect(find.text('Snooze'), findsNothing);

    await tester.runAsync(() => controller.markReminderFired(note.id));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reminder-done')));
    await tester.pumpAndSettle();
    expect(controller.noteById(note.id)!.remindAt, isNull);
    expect(find.text('Snooze'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      controller.dispose();
      await db.close();
    });
  });

  test(
    'the real Windows scheduled task can be created and removed',
    () async {
      await syncReminderTask(
        DateTime.now().toUtc().add(const Duration(days: 30)),
      );
      Future<String> query() async =>
          '${(await Process.run('powershell.exe', ['-NoProfile', '-Command', "(Get-ScheduledTask -TaskName '$reminderTaskName' -ErrorAction SilentlyContinue).TaskName"])).stdout}'
              .trim();
      expect(await query(), reminderTaskName);
      await removeReminderTask();
      expect(await query(), isEmpty);
    },
    skip:
        Platform.isWindows && Platform.environment['BN_TASK_INTEGRATION'] == '1'
        ? false
        : 'set BN_TASK_INTEGRATION=1 on Windows to touch Task Scheduler',
  );
}
