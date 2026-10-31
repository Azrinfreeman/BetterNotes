// Trailer-only entrypoint. Uses real app widgets and an in-memory notebook.
import 'package:flutter/material.dart';
import 'package:better_notes/main.dart';
import 'package:better_notes/ui/review_notebook.dart';
import 'package:better_notes/data/templates.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await createReviewNotebook();
  final note = controller.notes.firstWhere(
    (note) => note.title == 'A place for small ideas',
  );
  const template = NoteTemplate('trailer', 'Reading club', 'Reading club', [
    '# A little room for a big idea.',
    'Launch a weekend reading club.',
    'Bring good books. Make better conversations.',
    '',
    '# The plan',
    '[ ] Find a quiet corner in the bookshop',
    '[ ] Invite a few curious friends',
    '[ ] Choose one book to start',
    '',
    'Keep it small. Make it happen.',
  ]);
  await controller.save(
    note.copyWith(delta: template.delta, plainText: template.plainText),
  );
  runApp(BetterNotesApp(controller: controller));
}
