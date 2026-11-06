// Synthetic notebook used only by the explicit --ui-review entrypoint.
import '../data/local_store.dart';
import '../state/notes_controller.dart';

import 'package:sembast/sembast_memory.dart';
import 'package:image/image.dart' as image;

/// Disposable restoration fixture. Does not open the user's database or cloud.
Future<NotesController> createStartupBenchmarkNotebook(int count) async {
  final db = await databaseFactoryMemory.openDatabase('startup-benchmark');
  final controller = NotesController(LocalStore.fromDatabase(db), null);
  await controller.load();
  final picture = image.Image(width: 640, height: 480);
  image.fill(picture, color: image.ColorRgb8(122, 153, 110));
  await controller.store.putImage('startup-image', image.encodePng(picture));
  for (var i = 0; i < count; i++) {
    final note = await controller.create();
    final text = i % 5 == 0
        ? List.filled(
            150,
            'A longer synthetic paragraph for startup testing.',
          ).join('\n')
        : 'Synthetic note $i\nReady to edit.';
    await controller.save(
      note.copyWith(
        title: 'Startup sample $i',
        plainText: text,
        images: i % 3 == 0 ? ['startup-image'] : [],
        delta: [
          {
            'insert': '$text\n',
            'attributes': {'bold': i.isEven},
          },
        ],
      ),
    );
  }
  await controller.store.setSetting(
    'openNoteWindows',
    controller.notes.map((note) => note.id).toList(),
  );
  return controller;
}

Future<NotesController> createReviewNotebook() async {
  final db = await databaseFactoryMemory.openDatabase('ui-review');
  final controller = NotesController(LocalStore.fromDatabase(db), null);
  await controller.load();
  final samples = <(String, String, int, List<String>)>[
    (
      'A place for small ideas',
      'A quiet space to think, collect, and write.\n\nKeep the useful details close. Leave room for the next idea.',
      0,
      ['personal'],
    ),
    (
      'Design review',
      'Review the library layout\nCheck keyboard navigation\nMake the writing surface feel effortless',
      5,
      ['work'],
    ),
    (
      'Weekend plans',
      'A long walk by the water.\nThe little bookshop on the corner.\nDinner with friends.',
      3,
      ['personal'],
    ),
    (
      'Reading list',
      'The Design of Everyday Things\nA Pattern Language\nThe Creative Act',
      2,
      ['reading'],
    ),
    (
      'Project notes',
      'Keep the interface clear.\nBuild on the things that already work.\nMeasure the details that matter.',
      10,
      ['work'],
    ),
    ('Something to remember', 'Good tools leave space for the work.', 4, []),
  ];
  for (var i = 0; i < samples.length; i++) {
    final (title, text, color, tags) = samples[i];
    final note = await controller.create();
    await controller.save(
      note.copyWith(
        title: title,
        plainText: text,
        delta: [
          {'insert': '$text\n'},
        ],
        colorIndex: color,
        tags: tags,
        favorite: i == 0,
      ),
    );
  }
  return controller;
}
