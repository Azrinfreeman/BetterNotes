import 'dart:io';
import 'dart:typed_data';

import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/data/sticky_import.dart';
import 'package:better_notes/data/sticky_reader_io.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

class _FakeSticky implements StickySource {
  _FakeSticky(this._notes, [this._media = const {}]);
  final List<StickyNote> _notes;
  final Map<String, Uint8List> _media;
  @override
  Future<List<StickyNote>> notes() async => _notes;
  @override
  Future<Uint8List?> media(String fileName) async => _media[fileName];
}

String line(int n, String body) =>
    '\\id=${n.toString().padLeft(8, '0')}-0000-0000-0000-000000000000 $body';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('text conversion', () {
    test('formatting codes become Quill attributes', () {
      final content = parseStickyText(
        [
          line(1, 'Title'),
          line(2, r'\b bold\b0  and \ul under\ul0  then \strike gone\strike0 '),
          line(3, r'\i slant\i0 done'),
        ].join('\n'),
      );
      expect(content.plainText, 'Title\nbold and under then gone\nslantdone\n');
      expect(
        content.delta.any((op) => (op['attributes'] as Map?)?['bold'] == true),
        isTrue,
      );
      final bold = content.delta.firstWhere(
        (op) => (op['attributes'] as Map?)?['bold'] == true,
      );
      expect(bold['insert'], 'bold');
      final underline = content.delta.firstWhere(
        (op) => (op['attributes'] as Map?)?['underline'] == true,
      );
      expect(underline['insert'], 'under');
      final strike = content.delta.firstWhere(
        (op) => (op['attributes'] as Map?)?['strike'] == true,
      );
      expect(strike['insert'], 'gone');
      expect(content.delta.last, {'insert': '\n'});
    });

    test('backslashes, unknown codes, blank and id-less lines survive', () {
      final content = parseStickyText(
        [
          line(1, r'C:\\Users\\me and \bogus'),
          line(2, ''),
          'plain line without id',
        ].join('\r\n'),
      );
      expect(
        content.plainText,
        'C:\\Users\\me and \\bogus\n\nplain line without id\n',
      );
      expect(parseStickyText('').plainText, '\n');
    });

    test('formatting never leaks into the next line', () {
      final content = parseStickyText(
        [line(1, r'\b open'), line(2, 'next')].join('\n'),
      );
      final next = content.delta.firstWhere(
        (op) => (op['insert'] as String).contains('next'),
      );
      expect(next['attributes'], isNull);
    });

    test('times, themes and colors map sensibly', () {
      final ticks = (1_600_000_000 + 62135596800) * 10000000;
      expect(
        stickyTimeFromTicks(ticks)!.millisecondsSinceEpoch,
        1_600_000_000 * 1000,
      );
      expect(stickyTimeFromTicks(null), isNull);
      expect(stickyTimeFromTicks(0), isNull);
      expect(stickyColorIndex('Yellow'), 0);
      expect(stickyColorIndex('Green'), 3);
      expect(stickyColorIndex('Purple'), 2);
      expect(stickyColorIndex('Charcoal'), 11);
      expect(stickyColorIndex('unknown'), 0);
      expect(stickyColorIndex(null), 0);
    });
  });

  group('import into notes', () {
    test('creates tagged notes with dates and pictures, once', () async {
      final db = await databaseFactoryMemory.openDatabase('sticky-import');
      final controller = NotesController(LocalStore.fromDatabase(db), null);
      await controller.load();
      final png = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0,
        0,
        0,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        1,
        8,
        6,
        0,
        0,
        0,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0,
        0,
        0,
        0x0D,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0xF8,
        0xFF,
        0xFF,
        0x3F,
        0,
        5,
        0xFE,
        2,
        0xFE,
        0xDC,
        0xCC,
        0x59,
        0xE7,
        0,
        0,
        0,
        0,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);
      final created = DateTime.utc(2021, 4, 27, 10);
      final updated = DateTime.utc(2021, 5, 1, 8);
      final source = _FakeSticky(
        [
          StickyNote(
            id: 'a',
            text: [line(1, 'Shopping'), line(2, r'\b milk\b0 ')].join('\n'),
            theme: 'Green',
            createdAt: created,
            updatedAt: updated,
          ),
          StickyNote(
            id: 'b',
            text: line(3, 'With picture'),
            theme: 'Charcoal',
            createdAt: created,
            updatedAt: updated,
            mediaFiles: const ['p.png', 'missing.png'],
          ),
          StickyNote(
            id: 'c',
            text: line(4, ''),
            theme: 'Yellow',
            createdAt: created,
            updatedAt: updated,
          ),
        ],
        {'p.png': png},
      );
      final progress = <int>[];
      final result = await controller.importStickyNotes(
        source,
        onProgress: (done, total) => progress.add(done),
      );
      expect(result.found, 3);
      expect(result.imported, 2);
      expect(result.empty, 1);
      expect(result.pictures, 1);
      expect(result.failedPictures, 1);
      expect(progress.last, 3);

      final notes = controller.notes;
      expect(notes, hasLength(2));
      final shopping = notes.firstWhere(
        (n) => n.plainText.startsWith('Shopping'),
      );
      expect(shopping.colorIndex, 3);
      expect(shopping.tags, ['sticky notes']);
      expect(shopping.createdAt, created);
      expect(shopping.updatedAt, updated);
      expect(shopping.displayTitle, 'Shopping');
      final withPicture = notes.firstWhere((n) => n.images.isNotEmpty);
      expect(withPicture.images, hasLength(1));
      expect(
        await controller.image(withPicture.id, withPicture.images.single),
        isNotNull,
      );
      expect(withPicture.colorIndex, 11);

      // Running it again imports nothing new, even after a restart.
      final again = await controller.importStickyNotes(source);
      expect(again.imported, 0);
      expect(again.alreadyImported, 3);
      expect(controller.notes, hasLength(2));
      controller.dispose();
      final reopened = NotesController(LocalStore.fromDatabase(db), null);
      await reopened.load();
      expect((await reopened.importStickyNotes(source)).imported, 0);
      expect(reopened.notes, hasLength(2));
      reopened.dispose();
      await db.close();
    });
  });

  group('Windows reader', () {
    test('reads a copy of the database and its media', () async {
      final reader = await StickyNotesReader.open(
        Directory('test/fixtures/sticky'),
      );
      try {
        final notes = await reader.notes();
        expect(notes.map((n) => n.id), [
          'note-a',
          'note-b',
          'note-c',
        ]); // deleted one excluded
        final a = notes.first;
        expect(a.theme, 'Green');
        expect(a.createdAt!.millisecondsSinceEpoch, 1_600_000_000 * 1000);
        expect(a.updatedAt!.millisecondsSinceEpoch, 1_600_000_500 * 1000);
        expect(
          parseStickyText(a.text).plainText,
          'Groceries\nmilk and eggs\n- bread\n',
        );
        final b = notes[1];
        expect(b.mediaFiles, [
          '11111111-1111-1111-1111-111111111111.png',
        ]); // orphaned one excluded
        expect(await reader.media(b.mediaFiles.single), isNotNull);
        expect(await reader.media('nope.png'), isNull);
        expect(
          await reader.media(r'..\..\plum.sqlite'),
          isNull,
        ); // no path escapes
      } finally {
        await reader.close();
      }
      expect(
        Directory.systemTemp.listSync().whereType<Directory>().where(
          (d) => d.path.contains('bn-sticky-'),
        ),
        isEmpty,
      );
    });

    test('a missing folder is a clear error', () async {
      await expectLater(
        StickyNotesReader.open(Directory('test/fixtures/does-not-exist')),
        throwsA(anything),
      );
    });
  }, skip: Platform.isWindows ? false : 'needs winsqlite3.dll');
}
