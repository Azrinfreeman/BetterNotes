import 'dart:convert';

import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:better_notes/ui/google_drive_backup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';

Future<(Database, NotesController)> _open(
  WidgetTester tester,
  String name,
) async {
  return (await tester.runAsync(() async {
    final db = await databaseFactoryMemory.openDatabase(name);
    final controller = NotesController(LocalStore.fromDatabase(db), null);
    await controller.load();
    return (db, controller);
  }))!;
}

void main() {
  testWidgets(
    'unconfigured build explains Drive is unavailable at narrow width',
    (tester) async {
      final (db, controller) = await _open(tester, 'drive-page');
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: GoogleDriveBackupPage(controller: controller)),
      );
      expect(
        find.text('Google Drive is not configured for this build.'),
        findsOneWidget,
      );
      expect(find.text('Connect Google Drive'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.runAsync(db.close);
    },
  );

  // The client ID is empty in tests, so this uses [initialClient] to reach the
  // signed-in layout without a browser round trip.
  testWidgets('a signed-in account lists and cleans up at narrow width', (
    tester,
  ) async {
    final (db, controller) = await _open(tester, 'drive-connected');
    var deletes = 0;
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        deletes++;
        return http.Response('', 204);
      }
      return http.Response(
        jsonEncode({'files': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    // Tall enough that the whole narrow-width page is laid out at once.
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: GoogleDriveBackupPage(
          controller: controller,
          initialClient: client,
        ),
      ),
    );
    expect(
      find.text('Signed in. The Google account name is unavailable.'),
      findsOneWidget,
    );
    expect(find.text('No verified backups found.'), findsOneWidget);

    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('No verified backups found.'), findsOneWidget);

    await tester.tap(find.text('Clean up unfinished uploads'));
    await tester.pumpAndSettle();
    expect(find.text('No unfinished uploads found.'), findsOneWidget);
    expect(deletes, 0);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.runAsync(db.close);
  });
}
