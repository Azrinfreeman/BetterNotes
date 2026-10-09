import 'dart:io';

import 'package:better_notes/app_info.dart';
import 'package:better_notes/data/app_log_io.dart';
import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:better_notes/ui/about_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the app version constant matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1)!;
    expect(appVersionLabel, version);
  });

  test('the log rotates, keeps two older files, and tails', () async {
    final dir = await Directory.systemTemp.createTemp('bn-log-');
    addTearDown(() => dir.delete(recursive: true));
    AppLog.useDirectory(dir);
    AppLog.write('INFO', 'first');
    AppLog.write('ERROR', 'boom', StateError('bad'), StackTrace.current);
    final tail = await AppLog.tail(40);
    expect(tail.first, contains('INFO first'));
    expect(tail.join('\n'), contains('boom | Bad state: bad'));
    AppLog.maxBytes = 4000;
    addTearDown(() => AppLog.maxBytes = 512 * 1024);
    final filler = 'x' * 1000;
    for (var i = 0; i < 30; i++) {
      AppLog.write('INFO', filler);
    }
    final names = dir.listSync().map((e) => e.uri.pathSegments.last).toSet();
    expect(names.contains('betternotes.log'), isTrue);
    expect(names.contains('betternotes.log.1'), isTrue);
    expect(names.length, lessThanOrEqualTo(3));
    expect((await AppLog.tail(5)).length, inInclusiveRange(1, 5));
  });

  test('diagnostics list facts and log lines but no note text', () async {
    final db = await databaseFactoryMemory.openDatabase('about-diag');
    final controller = NotesController(LocalStore.fromDatabase(db), null);
    await controller.load();
    final note = await controller.create();
    await controller.save(
      note.copyWith(
        title: 'SECRET TITLE',
        plainText: 'SECRET BODY',
        tags: ['secret-tag'],
      ),
    );
    final text = await collectDiagnostics(controller);
    expect(text, contains('$appName $appVersionLabel'));
    expect(text, contains('Notes (active): 1'));
    expect(text, contains('Reminder task: false'));
    expect(text, isNot(contains('SECRET')));
    expect(text, isNot(contains('secret-tag')));
    final built = buildDiagnostics(
      platform: 'windows',
      dataPath: null,
      facts: {'A': 1},
      logLines: const ['line one'],
      now: DateTime.utc(2026, 1, 2),
    );
    expect(built, contains('Data file: unavailable'));
    expect(built, contains('A: 1'));
    expect(built, contains('line one'));
    controller.dispose();
    await db.close();
  });

  testWidgets('About shows the version and copies diagnostics', (tester) async {
    final (controller, db) =
        await tester.runAsync(() async {
          final db = await databaseFactoryMemory.openDatabase('about-ui');
          final controller = NotesController(LocalStore.fromDatabase(db), null);
          await controller.load();
          return (controller, db);
        }) ??
        (throw StateError('setup failed'));
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: AboutPage(controller: controller)),
    );
    expect(
      find.textContaining('Version $appVersion (build $appBuild)'),
      findsOneWidget,
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('copy-diagnostics')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(copied, contains('$appName $appVersionLabel'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      controller.dispose();
      await db.close();
    });
  });
}
