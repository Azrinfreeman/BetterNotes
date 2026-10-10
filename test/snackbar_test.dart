import 'package:flutter/material.dart';
import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/main.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  testWidgets('"Moved to Trash" with Undo hides itself after a few seconds', (
    tester,
  ) async {
    final (db, controller, note) =
        await tester.runAsync(() async {
          final db = await databaseFactoryMemory.openDatabase('snackbar');
          final controller = NotesController(LocalStore.fromDatabase(db), null);
          await controller.load();
          final note = await controller.create();
          await controller.save(note.copyWith(plainText: 'Remove me'));
          return (db, controller, note);
        }) ??
        (throw StateError('setup failed'));
    await tester.pumpWidget(BetterNotesApp(controller: controller));
    await tester.runAsync(
      () => controller.delete(controller.noteById(note.id)!),
    );
    await tester.pumpAndSettle();
    expect(find.text('Moved to Trash'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('Moved to Trash'), findsNothing);
    expect(find.text('Undo'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      controller.dispose();
      await db.close();
    });
  });
}
