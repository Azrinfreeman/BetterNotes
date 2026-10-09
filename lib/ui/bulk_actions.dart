import 'package:flutter/material.dart';

import '../data/backup_files.dart' as backup_files;
import '../data/markdown_export.dart';
import '../data/note.dart';
import '../state/notes_controller.dart';

Future<int?> pickNoteColor(BuildContext context) => showDialog<int>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Set color'),
    content: SingleChildScrollView(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < noteColors.length; i++)
            Tooltip(
              message: noteColorNames[i],
              child: InkResponse(
                key: ValueKey('bulk-color-$i'),
                onTap: () => Navigator.pop(context, i),
                radius: 26,
                child: Semantics(
                  button: true,
                  label: noteColorNames[i],
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(noteColors[i]),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  ),
);

/// Asks for comma-separated tags to add; existing tags are offered as chips.
Future<List<String>?> askTagsToAdd(
  BuildContext context,
  List<String> suggestions,
) async {
  final field = TextEditingController();
  try {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add tags'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('bulk-tags'),
                controller: field,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'work, ideas',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final tag in suggestions.take(12))
                      ActionChip(
                        label: Text(tag),
                        onPressed: () {
                          final text = field.text.trim();
                          field.text = text.isEmpty || text.endsWith(',')
                              ? '$text $tag'.trim()
                              : '$text, $tag';
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (accepted != true) return null;
    final tags = normalizeTags(field.text.split(','));
    return tags.isEmpty ? null : tags;
  } finally {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    field.dispose();
  }
}

/// Saves [notes] as Markdown (a ZIP when there are several notes or images).
/// Returns a status message, or null when the save dialog was cancelled.
Future<String?> exportNotesMarkdown(
  NotesController controller,
  List<Note> notes,
) async {
  await controller.flushAllEditors();
  final fresh = [
    for (final note in notes)
      if (controller.noteById(note.id) case final Note current) current,
  ];
  if (fresh.isEmpty) return null;
  final file = await exportMarkdown(fresh, controller.image);
  final saved = await backup_files.saveBackupFile(
    file.bytes,
    file.name,
    mimeType: file.mimeType,
  );
  return saved ? 'Exported ${fresh.length} note(s) as Markdown.' : null;
}
