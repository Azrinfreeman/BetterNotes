import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/main.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saved searches persist, replace by name, and delete', () async {
    final db = await databaseFactoryMemory.openDatabase('saved-filters');
    final controller = NotesController(LocalStore.fromDatabase(db), null);
    await controller.load();
    await controller.setLibraryOptions(
      view: LibraryView.favorites,
      sort: NoteSort.title,
      tags: ['work'],
    );
    await controller.saveFilter('  Work stars ', ' plan ');
    await controller.saveFilter('work STARS', 'other');
    await controller.saveFilter('   ', 'ignored');
    expect(controller.savedFilters, hasLength(1));
    final saved = controller.savedFilters.single;
    expect(saved.name, 'work STARS');
    expect(saved.query, 'other');
    expect(saved.view, LibraryView.favorites);
    expect(saved.sort, NoteSort.title);
    expect(saved.tags, ['work']);
    controller.dispose();

    final reopened = NotesController(LocalStore.fromDatabase(db), null);
    await reopened.load();
    expect(reopened.savedFilters.single.tags, ['work']);
    await reopened.deleteFilter('work STARS');
    expect(reopened.savedFilters, isEmpty);
    reopened.dispose();
    await db.close();
  });

  testWidgets('save a search from the library and apply it later', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(470, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (controller, db) =
        await tester.runAsync(() async {
          final db = await databaseFactoryMemory.openDatabase('saved-ui');
          final controller = NotesController(LocalStore.fromDatabase(db), null);
          await controller.load();
          final a = await controller.create();
          final b = await controller.create();
          await controller.save(
            a.copyWith(title: 'Alpha report', plainText: 'alpha'),
          );
          await controller.save(b.copyWith(title: 'Beta', plainText: 'beta'));
          return (controller, db);
        }) ??
        (throw StateError('setup failed'));
    await tester.pumpWidget(BetterNotesApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Save search'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'alpha');
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsNothing);
    await tester.tap(find.text('Save search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('filter-name')), 'Alphas');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('saved-filter-Alphas')), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('saved-filter-Alphas')));
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsNothing);
    expect(find.text('Alpha report'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      controller.dispose();
      await db.close();
    });
  });
}
